import 'dart:convert';

import '../models/product.dart';
import '../models/price_quote.dart';
import '../models/shopping_context.dart';
import '../repositories/conviene_repository.dart';
import '../repositories/product_equivalence_repository.dart';
import 'discount_engine.dart';
import 'price_comparison_service.dart';

class ProductComparisonService {
  ProductComparisonService(this.repository, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final ConvieneRepository repository;
  final DateTime Function() _clock;
  final _cache = <String, (DateTime, EquivalentProductsResult)>{};
  final _pending = <String, Future<EquivalentProductsResult>>{};
  int _cacheEpoch = 0;
  static const storeIds = {'coto', 'carrefour', 'lagallega'};

  void invalidateCache() {
    ++_cacheEpoch;
    _cache.clear();
    _pending.clear();
  }

  String key(Product product, ShoppingContext context) => jsonEncode([
    product.id,
    product.ean,
    product.name,
    product.brand,
    product.presentation,
    context.postalCode,
    context.fulfillmentApiValue,
    context.cotoStore,
    context.carrefourSalesChannel,
    context.latitude,
    context.longitude,
  ]);

  Future<EquivalentProductsResult> compare(
    Product product,
    ShoppingContext context, {
    bool refresh = false,
  }) {
    final identity = key(product, context);
    if (refresh) _cache.remove(identity);
    final cached = _cache[identity];
    if (cached != null &&
        _clock().difference(cached.$1) < const Duration(minutes: 5)) {
      return Future.value(cached.$2);
    }
    final pending = _pending[identity];
    if (pending != null) return pending;
    final epoch = _cacheEpoch;
    late final Future<EquivalentProductsResult> request;
    request = _load(product, context)
        .then((value) {
          // Retain useful partial results, but never restore an invalidated quote.
          if (epoch == _cacheEpoch) {
            if (_cache.length >= 64) _cache.remove(_cache.keys.first);
            _cache[identity] = (_clock(), value);
          }
          return value;
        })
        .whenComplete(() {
          if (identical(_pending[identity], request)) _pending.remove(identity);
        });
    _pending[identity] = request;
    return request;
  }

  Future<EquivalentProductsResult> _load(
    Product product,
    ShoppingContext context,
  ) async {
    try {
      final source = repository;
      final EquivalentProductsResult raw;
      if (source is ProductEquivalenceRepository) {
        raw = await (source as ProductEquivalenceRepository)
            .findEquivalentProducts(
              product: product,
              storeIds: storeIds,
              context: context,
            );
      } else {
        final rows = await source.searchProducts(
          query: product.name,
          storeIds: storeIds,
          context: context,
        );
        raw = EquivalentProductsResult(
          results: rows,
          storeStatus: {
            for (final id in storeIds)
              id: rows.any((row) => row.supermarket.id == id)
                  ? 'found'
                  : 'not_found',
          },
        );
      }
      final matcher = PriceComparisonService(
        repository,
        const DiscountEngine(),
      );
      final offers = <String, SearchResult>{};
      for (final row in raw.results) {
        if (!storeIds.contains(row.supermarket.id) ||
            !row.price.stock ||
            !row.price.priceOriginal.isFinite ||
            row.price.priceOriginal <= 0 ||
            !matcher.isVerifiedEquivalent(product, row))
          continue;
        final previous = offers[row.supermarket.id];
        if (previous == null ||
            row.price.priceOriginal < previous.price.priceOriginal) {
          offers[row.supermarket.id] = row;
        }
      }
      return EquivalentProductsResult(
        results: offers.values.toList(),
        storeStatus: {
          for (final id in storeIds)
            id: offers.containsKey(id)
                ? 'found'
                : raw.storeStatus[id] == 'found'
                ? 'not_found'
                : raw.storeStatus[id] ?? 'error',
        },
      );
    } catch (_) {
      return const EquivalentProductsResult(
        results: [],
        storeStatus: {
          'coto': 'error',
          'carrefour': 'error',
          'lagallega': 'error',
        },
      );
    }
  }
}
