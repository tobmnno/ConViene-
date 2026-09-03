import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/discount.dart';
import '../models/price_quote.dart';
import '../models/product.dart';
import '../models/supermarket.dart';
import 'conviene_repository.dart';

class ApiRepository implements ConvieneRepository {
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
  Future<List<Promotion>> getPromotions(DateTime date) {
    return fallback.getPromotions(date);
  }

  @override
  Future<List<SearchResult>> searchProducts({
    required String query,
    required Set<String> storeIds,
  }) async {
    try {
      final uri = _searchUri(query, storeIds);
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
      return fallback.searchProducts(query: query, storeIds: storeIds);
    }
  }

  Uri _searchUri(String query, Set<String> storeIds) {
    final basePath = baseUrl.path.endsWith('/')
        ? baseUrl.path.substring(0, baseUrl.path.length - 1)
        : baseUrl.path;
    return baseUrl.replace(
      path: '$basePath/search',
      queryParameters: <String, dynamic>{
        'q': query,
        'limit': '30',
        'stores': storeIds.map(_storeIdForApi).toList(),
      },
    );
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
      if (price == null || name.isEmpty || supermarket == null) {
        continue;
      }

      final presentation = _presentationFrom(productData, name);
      final productId = _productIdFrom(productData, name);
      final product = Product(
        id: productId,
        ean: '',
        name: name,
        brand: _brandFromName(name),
        presentation: presentation,
        unit: _unitFromPresentation(presentation),
        category: _categoryFromName(name),
        imageTag: _imageTagFromName(name),
        imageUrl: _asString(productData['image'] ?? result['image']),
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

  String _productIdFrom(Map<String, dynamic> result, String name) {
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
        RegExp(r'\b(?:g|gr|gramo|gramos)\b').hasMatch(normalized)) {
      return 'kg';
    }
    if (normalized.contains('ml') ||
        normalized.contains('cc') ||
        normalized.contains('cm3') ||
        normalized.contains('lt') ||
        normalized.contains('litro') ||
        RegExp(r'\bl\b').hasMatch(normalized)) {
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
