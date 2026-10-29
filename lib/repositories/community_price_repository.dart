import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/discount.dart';
import '../models/price_quote.dart';
import '../models/product.dart';
import '../models/shopping_context.dart';
import '../models/supermarket.dart';
import 'conviene_repository.dart';
import 'product_equivalence_repository.dart';
import 'progressive_search_repository.dart';
import 'promotion_status_repository.dart';
import 'search_status_repository.dart';

class CommunityPriceRepository
    implements
        ConvieneRepository,
        ProductEquivalenceRepository,
        ProgressiveSearchRepository,
        PromotionStatusRepository,
        SearchStatusRepository {
  CommunityPriceRepository(this._source, this._client, {this.userId});

  final ConvieneRepository _source;
  final SupabaseClient _client;
  final String? userId;
  final Map<String, SearchResult> _cached = {};
  String? _communityWarning;
  String? _officialWarning;

  String? get currentUserId => userId ?? _client.auth.currentUser?.id;

  @override
  String? get lastSearchWarning {
    final source = _source is SearchStatusRepository
        ? (_source as SearchStatusRepository).lastSearchWarning
        : null;
    return [
          source,
          _communityWarning,
          _officialWarning,
        ].whereType<String>().join(' ').trim().isEmpty
        ? null
        : [
            source,
            _communityWarning,
            _officialWarning,
          ].whereType<String>().join(' ').trim();
  }

  @override
  String? get lastSearchNotice => _source is SearchStatusRepository
      ? (_source as SearchStatusRepository).lastSearchNotice
      : null;

  @override
  String? get lastPromotionWarning => _source is PromotionStatusRepository
      ? (_source as PromotionStatusRepository).lastPromotionWarning
      : null;

  @override
  Future<List<Supermarket>> getSupermarkets() => _source.getSupermarkets();

  @override
  Future<List<Product>> getProducts() => _source.getProducts();

  @override
  Future<List<Promotion>> getPromotions(DateTime date) =>
      _source.getPromotions(date);

  @override
  Future<List<ProductPrice>> getPricesForProduct(String productId) async {
    final cached = _cached[productId];
    if (cached != null) return [cached.price];
    if (!productId.startsWith('community_')) {
      return _source.getPricesForProduct(productId);
    }
    final id = productId.substring('community_'.length);
    try {
      final row = await _client
          .from('community_prices')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (row == null) return [];
      final stores = await getSupermarkets();
      final store = stores.where((item) => item.id == row['supermarket_id']);
      if (store.isEmpty) return [];
      final result = _fromRow(row, store.first);
      _cached[result.product.id] = result;
      return [result.price];
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<SearchResult>> searchProducts({
    required String query,
    required Set<String> storeIds,
    ShoppingContext context = const ShoppingContext(),
  }) async {
    _communityWarning = null;
    _officialWarning = null;
    final officialFuture = _source.searchProducts(
      query: query,
      storeIds: storeIds,
      context: context,
    );
    final communityFuture = _searchCommunity(query, storeIds);
    List<SearchResult> official;
    Object? officialError;
    try {
      official = await officialFuture;
    } catch (error) {
      official = const [];
      officialError = error;
    }
    final community = await communityFuture;
    if (officialError != null) {
      if (community.isEmpty) throw officialError;
      _officialWarning =
          'No pudimos consultar los catálogos oficiales. '
          'Se muestran solo precios aportados por usuarios.';
    }
    return [...official, ...community];
  }

  @override
  Future<List<SearchResult>> searchProductsProgressively({
    required String query,
    required Set<String> storeIds,
    required SearchProgress onProgress,
    ShoppingContext context = const ShoppingContext(),
  }) async {
    _communityWarning = null;
    _officialWarning = null;
    var official = <SearchResult>[];
    var community = <SearchResult>[];
    var pending = Set<String>.of(storeIds);
    final communityFuture = _searchCommunity(query, storeIds).then((rows) {
      community = rows;
      onProgress([...official, ...community], Set<String>.of(pending));
    });
    final Future<List<SearchResult>> officialFuture;
    if (_source case final ProgressiveSearchRepository source) {
      officialFuture = source.searchProductsProgressively(
        query: query,
        storeIds: storeIds,
        context: context,
        onProgress: (rows, remaining) {
          official = rows;
          pending = remaining;
          onProgress([...official, ...community], Set<String>.of(pending));
        },
      );
    } else {
      officialFuture = _source.searchProducts(
        query: query,
        storeIds: storeIds,
        context: context,
      );
    }
    Object? officialError;
    try {
      official = await officialFuture;
    } catch (error) {
      officialError = error;
    }
    pending = {};
    onProgress([...official, ...community], const {});
    await communityFuture;
    if (officialError != null) {
      if (community.isEmpty) throw officialError;
      _officialWarning =
          'No pudimos consultar los catálogos oficiales. '
          'Se muestran solo precios aportados por usuarios.';
    }
    onProgress([...official, ...community], const {});
    return [...official, ...community];
  }

  Future<List<SearchResult>> _searchCommunity(
    String query,
    Set<String> storeIds,
  ) async {
    try {
      final rows = await _client.rpc<List<dynamic>>(
        'search_community_prices',
        params: {'query_text': query.trim(), 'store_ids': storeIds.toList()},
      );
      final stores = {
        for (final store in await getSupermarkets()) store.id: store,
      };
      final results = <SearchResult>[];
      for (final raw in rows) {
        final row = Map<String, dynamic>.from(raw as Map);
        final store = stores[row['supermarket_id']];
        if (store == null) continue;
        final result = _fromRow(row, store);
        _cached[result.product.id] = result;
        results.add(result);
      }
      return results;
    } catch (_) {
      _communityWarning =
          'No pudimos cargar los precios aportados por usuarios.';
      return [];
    }
  }

  SearchResult _fromRow(Map<String, dynamic> row, Supermarket store) {
    final id = row['id'] as String;
    final updatedAt = DateTime.parse(row['updated_at'] as String);
    final product = Product(
      id: 'community_$id',
      ean: (row['ean'] ?? '') as String,
      name: row['name'] as String,
      brand: (row['brand'] ?? '') as String,
      presentation: row['presentation'] as String,
      unit: row['unit'] as String,
      category: (row['category'] ?? '') as String,
      imageTag: 'producto',
      imageUrl: (row['image_url'] ?? '') as String,
    );
    final price = ProductPrice(
      storeId: store.id,
      productId: product.id,
      priceOriginal: (row['price'] as num).toDouble(),
      priceUnitario: (row['unit_price'] as num).toDouble(),
      stock: row['in_stock'] as bool,
      url: (row['source_url'] as String?)?.isNotEmpty == true
          ? row['source_url'] as String
          : store.websiteUrl,
      fechaActualizacion: updatedAt,
      pricingScope: 'community',
    );
    return SearchResult(
      product: product,
      price: price,
      supermarket: store,
      communityPriceId: id,
      contributorId: row['created_by'] as String?,
      contributorName: row['username'] as String?,
      contributedAt: updatedAt,
    );
  }

  Future<void> saveContribution({
    String? id,
    required String supermarketId,
    required String name,
    required String brand,
    required String presentation,
    required String unit,
    required String category,
    required String ean,
    required String imageUrl,
    required String sourceUrl,
    required double price,
    required double unitPrice,
    required bool inStock,
  }) async {
    final fields = <String, dynamic>{
      'name': name.trim(),
      'brand': brand.trim(),
      'presentation': presentation.trim(),
      'unit': unit.trim(),
      'category': category.trim(),
      'ean': ean.trim(),
      'image_url': imageUrl.trim(),
      'source_url': sourceUrl.trim(),
      'price': price,
      'unit_price': unitPrice,
      'in_stock': inStock,
    };
    if (id == null) {
      await _client
          .from('community_prices')
          .insert({...fields, 'supermarket_id': supermarketId})
          .select('id')
          .single();
    } else {
      final updated = await _client
          .from('community_prices')
          .update(fields)
          .eq('id', id)
          .select('id')
          .maybeSingle();
      if (updated == null) {
        throw StateError('No tenes permiso para editar este aporte.');
      }
      _cached.remove('community_$id');
    }
  }

  @override
  Future<EquivalentProductsResult> findEquivalentProducts({
    required Product product,
    required Set<String> storeIds,
    required ShoppingContext context,
  }) async {
    final source = _source;
    final officialFuture = () async {
      try {
        return source is ProductEquivalenceRepository
            ? await (source as ProductEquivalenceRepository)
                  .findEquivalentProducts(
                    product: product,
                    storeIds: storeIds,
                    context: context,
                  )
            : const EquivalentProductsResult(results: [], storeStatus: {});
      } catch (_) {
        return EquivalentProductsResult(
          results: const [],
          storeStatus: {for (final id in storeIds) id: 'error'},
        );
      }
    }();
    final communityFutures = <Future<List<SearchResult>>>[
      _searchCommunity(product.name, storeIds),
      if (product.ean.isNotEmpty) _searchCommunity(product.ean, storeIds),
    ];
    final official = await officialFuture;
    final communityRows = await Future.wait(communityFutures);
    final community = communityRows.first;
    if (product.ean.isNotEmpty) {
      final byEan = communityRows[1];
      final seen = {for (final result in community) result.communityPriceId};
      community.addAll(
        byEan.where((result) => seen.add(result.communityPriceId)),
      );
    }
    final exact = community.where((result) {
      if (product.ean.isNotEmpty && result.product.ean == product.ean)
        return true;
      final brandMatches =
          product.brand.isEmpty ||
          result.product.brand.isEmpty ||
          _normalized(result.product.brand) == _normalized(product.brand);
      return brandMatches &&
          _normalized(result.product.name) == _normalized(product.name) &&
          _normalized(result.product.presentation) ==
              _normalized(product.presentation);
    }).toList();
    return EquivalentProductsResult(
      results: [...official.results, ...exact],
      storeStatus: {
        ...official.storeStatus,
        for (final result in exact) result.supermarket.id: 'found',
      },
      alternatives: official.alternatives,
    );
  }

  String _normalized(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}
