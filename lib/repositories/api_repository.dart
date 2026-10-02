import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/discount.dart';
import '../models/nearby_store_suggestion.dart';
import '../models/payment_method.dart';
import '../models/price_quote.dart';
import '../models/product.dart';
import '../models/supermarket.dart';
import '../models/shopping_context.dart';
import 'conviene_repository.dart';
import 'product_equivalence_repository.dart';

class ApiRepository
    implements ConvieneRepository, ProductEquivalenceRepository {
  ApiRepository({
    required this.baseUrl,
    required this.fallback,
    http.Client? client,
    this.timeout = const Duration(seconds: 45),
  }) : _client = client ?? http.Client();

  final Uri baseUrl;
  final ConvieneRepository fallback;
  final Duration timeout;
  final http.Client _client;
  final Map<String, Product> _cachedProducts = {};
  final Map<String, List<ProductPrice>> _cachedPrices = {};
  List<Supermarket>? _cachedSupermarkets;
  String? _pricesContextKey;

  @override
  Future<List<Supermarket>> getSupermarkets() async {
    return _cachedSupermarkets ??= await fallback.getSupermarkets();
  }

  @override
  Future<List<Product>> getProducts() async {
    final mockProducts = await fallback.getProducts();
    final merged = <String, Product>{
      for (final product in mockProducts) product.id: product,
      ..._cachedProducts,
    };
    return merged.values.toList();
  }

  @override
  Future<List<ProductPrice>> getPricesForProduct(String productId) async {
    final cached = _cachedPrices[productId];
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    return fallback.getPricesForProduct(productId);
  }

  @override
  Future<NearbyStoreSuggestion?> findNearbyCotoStore({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await _client
          .get(
            baseUrl.replace(
              path: '${_basePath()}/stores/nearby',
              queryParameters: {
                'latitude': latitude.toString(),
                'longitude': longitude.toString(),
              },
            ),
          )
          .timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final suggestions = decoded['suggestions'];
      if (suggestions is! List ||
          suggestions.isEmpty ||
          suggestions.first is! Map) {
        return null;
      }
      final first = Map<String, dynamic>.from(suggestions.first as Map);
      final id = _asString(first['id']);
      final name = _asString(first['name']);
      final distance = _asDouble(first['distance_km']);
      if (id.isEmpty || name.isEmpty || distance == null) {
        return null;
      }
      return NearbyStoreSuggestion(
        storeId: id,
        name: name,
        distanceKm: distance,
      );
    } on Object {
      return fallback.findNearbyCotoStore(
        latitude: latitude,
        longitude: longitude,
      );
    }
  }

  @override
  Future<List<Promotion>> getPromotions(DateTime date) async {
    try {
      final uri = _discountsUri(date);
      final response = await _client.get(uri).timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('Scraper API returned ${response.statusCode}');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Discounts API response must be an object');
      }
      final rawResults = decoded['results'];
      if (rawResults is! List<dynamic>) {
        throw const FormatException(
          'Discounts API response must include results',
        );
      }
      final promotions = _parsePromotions(rawResults, date);
      return promotions;
    } on Object {
      return fallback.getPromotions(date);
    }
  }

  @override
  Future<List<SearchResult>> searchProducts({
    required String query,
    required Set<String> storeIds,
    ShoppingContext context = const ShoppingContext(),
  }) async {
    final contextKey = _contextKey(context);
    if (_pricesContextKey != contextKey) {
      // A store branch or fulfillment mode can change product prices and stock.
      _cachedPrices.clear();
      _pricesContextKey = contextKey;
    }
    try {
      final uri = _searchUri(query, storeIds, context);
      final response = await _client.get(uri).timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('Scraper API returned ${response.statusCode}');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Scraper API response must be an object');
      }
      final rawResults = decoded['results'];
      if (rawResults is! List<dynamic>) {
        throw const FormatException(
          'Scraper API response must include results',
        );
      }
      return _parseResults(rawResults);
    } on Object {
      throw StateError(
        'No se pudo consultar los precios reales. Intenta nuevamente.',
      );
    }
  }

  @override
  Future<EquivalentProductsResult> findEquivalentProducts({
    required Product product,
    required Set<String> storeIds,
    required ShoppingContext context,
  }) async {
    try {
      final uri = baseUrl.replace(
        path: '${_basePath()}/products/equivalents',
        query: '',
      );
      final response = await _client
          .post(
            uri,
            headers: {'content-type': 'application/json'},
            body: jsonEncode({
              'product': {
                'name': product.name,
                if (RegExp(r'^\d{8,14}$').hasMatch(product.ean))
                  'ean': product.ean,
                'brand': product.brand,
              },
              'stores': storeIds.map(_storeIdForApi).toList(),
              'context': {
                'fulfillment': context.fulfillmentApiValue,
                'coto_store': context.cotoStore,
                'carrefour_sales_channel': context.carrefourSalesChannel,
                if (context.hasPostalCode) 'postal_code': context.postalCode,
              },
            }),
          )
          .timeout(timeout);
      if (response.statusCode != 200) throw StateError('Equivalence API error');
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final results = await _parseResults(decoded['results'] as List<dynamic>);
      final rawStatus = decoded['store_status'] as Map<String, dynamic>;
      return EquivalentProductsResult(
        results: results,
        storeStatus: {
          for (final store in storeIds)
            store: _asString(rawStatus[_storeIdForApi(store)]).isEmpty
                ? 'error'
                : _asString(rawStatus[_storeIdForApi(store)]),
        },
      );
    } on Object {
      // Never turn a network failure into mock prices or a claim of absence.
      return EquivalentProductsResult(
        results: const [],
        storeStatus: {for (final store in storeIds) store: 'error'},
      );
    }
  }

  Uri _searchUri(String query, Set<String> storeIds, ShoppingContext context) {
    final basePath = _basePath();
    return baseUrl.replace(
      path: '$basePath/search',
      queryParameters: <String, dynamic>{
        'q': query,
        'limit': '30',
        'stores': storeIds.map(_storeIdForApi).toList(),
        'fulfillment': context.fulfillmentApiValue,
        'coto_store': context.cotoStore,
        'carrefour_sales_channel': context.carrefourSalesChannel,
        if (context.latitude != null) 'latitude': context.latitude.toString(),
        if (context.longitude != null)
          'longitude': context.longitude.toString(),
        if (context.hasPostalCode) 'postal_code': context.postalCode,
      },
    );
  }

  String _contextKey(ShoppingContext context) {
    return [
      context.postalCode.trim(),
      context.fulfillmentApiValue,
      context.cotoStore,
      context.carrefourSalesChannel,
    ].join('|');
  }

  Uri _discountsUri(DateTime date) {
    final basePath = _basePath();
    return baseUrl.replace(
      path: '$basePath/discounts',
      queryParameters: <String, dynamic>{
        'date': _dateParam(date),
        'stores': const ['carrefour', 'coto', 'la_gallega'],
      },
    );
  }

  String _proxiedImageUrl(String rawUrl) {
    final parsed = Uri.tryParse(rawUrl.trim());
    if (parsed == null || parsed.scheme.isEmpty) {
      return '';
    }
    if (parsed.host == baseUrl.host && parsed.port == baseUrl.port) {
      return parsed.toString();
    }
    final basePath = _basePath();
    return baseUrl
        .replace(
          path: '$basePath/image',
          queryParameters: {'url': parsed.toString()},
        )
        .toString();
  }

  String _basePath() {
    final basePath = baseUrl.path.endsWith('/')
        ? baseUrl.path.substring(0, baseUrl.path.length - 1)
        : baseUrl.path;
    return basePath;
  }

  Future<List<SearchResult>> _parseResults(List<dynamic> rawResults) async {
    final supermarkets = await getSupermarkets();
    final storesById = {for (final store in supermarkets) store.id: store};
    final parsed = <SearchResult>[];

    for (final rawResult in rawResults) {
      if (rawResult is! Map<dynamic, dynamic>) {
        continue;
      }
      final result = Map<String, dynamic>.from(rawResult);
      final productData = _productDataFrom(result);
      final price = _asDouble(productData['price'] ?? result['price']);
      final name = _asString(productData['name'] ?? result['name']);
      final storeId = _storeIdForApp(
        _asString(productData['store'] ?? result['store']),
      );
      final supermarket = storesById[storeId];
      if (price == null || price <= 0 || name.isEmpty || supermarket == null) {
        continue;
      }

      final presentation = _presentationFrom(productData, name);
      final productId = _productIdFrom(productData, name);
      final imageUrl = _proxiedImageUrl(
        _asString(productData['image'] ?? result['image']),
      );
      final product = Product(
        id: productId,
        ean: _asString(productData['ean']),
        name: name,
        brand: _asString(productData['brand']).isNotEmpty
            ? _asString(productData['brand'])
            : _brandFromName(name),
        presentation: presentation,
        unit: _unitFromPresentation(presentation),
        category: _categoryFromName(name),
        imageTag: _imageTagFromName(name),
        imageUrl: imageUrl,
      );
      final priceQuote = ProductPrice(
        storeId: storeId,
        productId: productId,
        priceOriginal: price,
        priceUnitario: _unitPrice(price, presentation),
        stock:
            productData['available'] != false && productData['stock'] != false,
        url: _asString(productData['url']).isEmpty
            ? supermarket.websiteUrl
            : _asString(productData['url']),
        fechaActualizacion: _dateFrom(productData['scraped_at']),
        branchId: _nullableString(productData['branch_id']),
        pricingScope: _nullableString(productData['pricing_scope']),
        deliveryAvailable: productData['delivery_available'] is bool
            ? productData['delivery_available'] as bool
            : null,
      );

      _cachedProducts[productId] = product;
      final cachedPrices = _cachedPrices.putIfAbsent(productId, () => []);
      cachedPrices.removeWhere((item) => item.storeId == storeId);
      cachedPrices.add(priceQuote);

      parsed.add(
        SearchResult(
          product: product,
          price: priceQuote,
          supermarket: supermarket,
          relevanceScore: _asDouble(result['score']) ?? 0,
          isExactMatch: _asString(result['match_type']) != 'similar',
        ),
      );
    }

    return parsed;
  }

  Map<String, dynamic> _productDataFrom(Map<String, dynamic> result) {
    final product = result['product'];
    if (product is Map<dynamic, dynamic>) {
      return Map<String, dynamic>.from(product);
    }
    return result;
  }

  String? _nullableString(dynamic value) {
    final parsed = _asString(value);
    return parsed.isEmpty ? null : parsed;
  }

  List<Promotion> _parsePromotions(
    List<dynamic> rawResults,
    DateTime selectedDate,
  ) {
    final promotions = <Promotion>[];
    for (final rawResult in rawResults) {
      if (rawResult is! Map<dynamic, dynamic>) {
        continue;
      }
      final result = Map<String, dynamic>.from(rawResult);
      final storeId = _storeIdForApp(_asString(result['store']));
      final title = _asString(result['title']);
      final start = DateTime.tryParse(_asString(result['start_date']));
      final end = DateTime.tryParse(_asString(result['end_date']));
      if (storeId.isEmpty || title.isEmpty || start == null || end == null) {
        continue;
      }

      final paymentTypes = _paymentTypesFromApi(
        _asStringList(result['compatible_payment_types']),
      );
      final type = _paymentTypeFromApi(_asString(result['payment_type']));
      final weekdays = _asIntSet(result['weekdays']);
      final promotion = Promotion(
        id: _asString(result['id']).isEmpty
            ? 'api_promo_${_slug('$storeId $title')}'
            : _asString(result['id']),
        storeId: storeId,
        tipoMedioPago: type,
        entidad: _asString(result['entity']).isEmpty
            ? 'Medios de pago'
            : _asString(result['entity']),
        porcentajeDescuento: _asDouble(result['percentage']) ?? 0,
        topeReintegro: _asDouble(result['refund_cap']) ?? 0,
        diasSemana: weekdays.isEmpty
            ? {
                DateTime.monday,
                DateTime.tuesday,
                DateTime.wednesday,
                DateTime.thursday,
                DateTime.friday,
                DateTime.saturday,
                DateTime.sunday,
              }
            : weekdays,
        fechaInicio: start,
        fechaFin: end,
        condiciones: _asString(result['conditions']),
        categorias: _asStringList(result['categories']).isEmpty
            ? const ['todos']
            : _asStringList(result['categories']),
        titulo: title,
        beneficio: _asString(result['benefit']),
        canal: _asString(result['channel']),
        textoVigencia: _asString(result['valid_text']),
        fuenteUrl: _asString(result['source_url']),
        entidadesCompatibles: _asStringList(
          result['compatible_entities'],
        ).toSet(),
        entidadesRequeridas: _asStringSets(result['required_entity_groups']),
        tiposMedioPagoCompatibles: paymentTypes,
        cualquierEntidad: result['any_entity'] == true,
        compraMinima: _asDouble(result['minimum_purchase']) ?? 0,
      );
      if (promotion.appliesOn(selectedDate)) {
        promotions.add(promotion);
      }
    }
    return promotions;
  }

  String _productIdFrom(Map<String, dynamic> result, String name) {
    final ean = _asString(result['ean']);
    if (ean.isNotEmpty)
      return 'api_${_storeIdForApp(_asString(result['store']))}_$ean';
    final id = _asString(result['id']);
    if (id.isNotEmpty) {
      return 'api_$id';
    }
    return 'api_${_slug(name)}';
  }

  String _presentationFrom(Map<String, dynamic> result, String name) {
    final size = _asString(result['size']);
    if (size.isNotEmpty) {
      return size;
    }
    final fromName = _measurementFromName(name);
    if (fromName.isNotEmpty) {
      return fromName;
    }
    final unit = _asString(result['unit']);
    if (unit.isNotEmpty) {
      return unit;
    }
    return 'Unidad';
  }

  String _measurementFromName(String name) {
    final match = RegExp(
      r'(\d+(?:[,.]\d+)?\s*(?:kg|kilos?|gr|gramos?|g|ml|cc|cm3|l|lt|lts?|litros?|un|u))',
      caseSensitive: false,
    ).firstMatch(name);
    return match?.group(1) ?? '';
  }

  String _unitFromPresentation(String presentation) {
    final normalized = presentation.toLowerCase();
    if (normalized.contains('kg') ||
        normalized.contains('kilo') ||
        RegExp(
          r'\d+(?:[,.]\d+)?\s*(?:g|gr|gramo|gramos)\b',
        ).hasMatch(normalized)) {
      return 'kg';
    }
    if (normalized.contains('ml') ||
        normalized.contains('cc') ||
        normalized.contains('cm3') ||
        normalized.contains('lt') ||
        normalized.contains('litro') ||
        RegExp(r'\d+(?:[,.]\d+)?\s*l\b').hasMatch(normalized)) {
      return 'L';
    }
    return 'u';
  }

  double _unitPrice(double price, String presentation) {
    final match = RegExp(
      r'(\d+(?:[,.]\d+)?)\s*(kg|kilos?|gr|gramos?|g|ml|cc|cm3|l|lt|lts?|litros?)',
      caseSensitive: false,
    ).firstMatch(presentation);
    if (match == null) {
      return price;
    }
    final amount = double.tryParse(match.group(1)!.replaceAll(',', '.'));
    final unit = match.group(2)!.toLowerCase();
    if (amount == null || amount <= 0) {
      return price;
    }
    final normalizedAmount = switch (unit) {
      'g' || 'gr' || 'gramo' || 'gramos' => amount / 1000,
      'ml' || 'cc' || 'cm3' => amount / 1000,
      'kg' || 'kilo' || 'kilos' => amount,
      _ => amount,
    };
    return normalizedAmount <= 0 ? price : price / normalizedAmount;
  }

  String _brandFromName(String name) {
    final cleaned = name.trim();
    if (cleaned.isEmpty) {
      return '';
    }
    final words = cleaned.split(RegExp(r'\s+'));
    if (words.length >= 2 && words.first.length <= 4) {
      return words[1];
    }
    return words.first;
  }

  String _categoryFromName(String name) {
    final normalized = _normalize(name);
    if (normalized.contains('leche') ||
        normalized.contains('yogur') ||
        normalized.contains('queso')) {
      return 'lacteos';
    }
    if (normalized.contains('pan')) {
      return 'panificados';
    }
    return 'almacen';
  }

  String _imageTagFromName(String name) {
    final normalized = _normalize(name);
    if (normalized.contains('leche')) {
      return 'milk';
    }
    if (normalized.contains('cafe')) {
      return 'coffee';
    }
    if (normalized.contains('yerba')) {
      return 'yerba';
    }
    if (normalized.contains('pan')) {
      return 'bread';
    }
    if (normalized.contains('aceite')) {
      return 'oil';
    }
    return 'generic';
  }

  DateTime _dateFrom(Object? value) {
    final parsed = DateTime.tryParse(_asString(value));
    return parsed ?? DateTime.now();
  }

  double? _asDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      final cleaned = value.replaceAll(RegExp(r'[^\d,.-]'), '').trim();
      if (cleaned.isEmpty) {
        return null;
      }
      if (cleaned.contains(',')) {
        return double.tryParse(
          cleaned.replaceAll('.', '').replaceAll(',', '.'),
        );
      }
      if ('.'.allMatches(cleaned).length > 1) {
        return double.tryParse(cleaned.replaceAll('.', ''));
      }
      if (cleaned.contains('.')) {
        final parts = cleaned.split('.');
        if (parts.length == 2 && parts.last.length > 2) {
          return double.tryParse(cleaned.replaceAll('.', ''));
        }
      }
      return double.tryParse(cleaned);
    }
    return null;
  }

  String _asString(Object? value) {
    return value?.toString().trim() ?? '';
  }

  List<String> _asStringList(Object? value) {
    if (value is List<dynamic>) {
      return [
        for (final item in value)
          if (_asString(item).isNotEmpty) _asString(item),
      ];
    }
    final single = _asString(value);
    return single.isEmpty ? const [] : [single];
  }

  List<Set<String>> _asStringSets(Object? value) {
    if (value is! List<dynamic>) {
      return const [];
    }
    return [
      for (final group in value)
        if (_asStringList(group).isNotEmpty) _asStringList(group).toSet(),
    ];
  }

  Set<int> _asIntSet(Object? value) {
    if (value is! List<dynamic>) {
      return {};
    }
    return {
      for (final item in value)
        if (item is int && item >= DateTime.monday && item <= DateTime.sunday)
          item
        else if (int.tryParse(_asString(item)) case final parsed?
            when parsed >= DateTime.monday && parsed <= DateTime.sunday)
          parsed,
    };
  }

  PaymentMethodType _paymentTypeFromApi(String value) {
    return switch (_normalize(value)) {
      'bank' || 'banco' => PaymentMethodType.bank,
      'wallet' || 'billetera' => PaymentMethodType.wallet,
      _ => PaymentMethodType.card,
    };
  }

  Set<PaymentMethodType> _paymentTypesFromApi(List<String> values) {
    return {for (final value in values) _paymentTypeFromApi(value)};
  }

  String _dateParam(DateTime date) {
    return '${date.year}-${_twoDigits(date.month)}-${_twoDigits(date.day)}';
  }

  String _twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }

  String _storeIdForApi(String storeId) {
    return switch (storeId) {
      'lagallega' => 'la_gallega',
      _ => storeId,
    };
  }

  String _storeIdForApp(String storeId) {
    return switch (storeId) {
      'la_gallega' || 'la-gallega' || 'la gallega' => 'lagallega',
      _ => storeId,
    };
  }

  String _slug(String value) {
    return _normalize(
      value,
    ).replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n');
  }
}
