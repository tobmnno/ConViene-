import 'dart:convert';

import '../models/cart_item.dart';
import '../models/discount.dart';
import '../models/payment_method.dart';
import '../models/price_quote.dart';
import '../models/product.dart';
import '../models/store_comparison.dart';
import '../models/supermarket.dart';
import '../models/shopping_context.dart';
import '../repositories/conviene_repository.dart';
import '../repositories/product_equivalence_repository.dart';
import 'discount_engine.dart';

class PriceComparisonService {
  PriceComparisonService(
    this._repository,
    this._discountEngine, {
    this.usedRefundCaps = const {},
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final ConvieneRepository _repository;
  final DiscountEngine _discountEngine;
  final Map<String, double> usedRefundCaps;
  final DateTime Function() _clock;
  final _equivalentQuotes = <String, (DateTime, EquivalentProductsResult)>{};
  final _pendingQuotes = <String, Future<EquivalentProductsResult>>{};
  int _quoteEpoch = 0;

  void invalidateQuotes() {
    ++_quoteEpoch;
    _equivalentQuotes.clear();
    _pendingQuotes.clear();
  }

  Future<EquivalentProductsResult> _equivalentsForCart(
    Product product,
    Set<String> storeIds,
    ShoppingContext context, {
    required bool forceRefresh,
  }) async {
    final key = jsonEncode([
      product.id,
      product.ean,
      product.name,
      product.brand,
      product.presentation,
      (storeIds.toList()..sort()),
      context.postalCode,
      context.fulfillmentApiValue,
      context.cotoStore,
      context.carrefourSalesChannel,
      context.latitude,
      context.longitude,
    ]);
    if (forceRefresh) _equivalentQuotes.remove(key);
    final cached = _equivalentQuotes[key];
    if (cached != null &&
        _clock().difference(cached.$1) < const Duration(minutes: 1)) {
      return cached.$2;
    }
    final pending = _pendingQuotes[key];
    if (pending != null) return pending;
    final epoch = _quoteEpoch;
    final repository = _repository as ProductEquivalenceRepository;
    final request = repository.findEquivalentProducts(
      product: product,
      storeIds: storeIds,
      context: context,
    );
    _pendingQuotes[key] = request;
    try {
      final response = await request;
      if (epoch == _quoteEpoch &&
          storeIds.every(
            (id) =>
                response.storeStatus[id] != null &&
                response.storeStatus[id] != 'error',
          )) {
        if (_equivalentQuotes.length >= 64) {
          _equivalentQuotes.remove(_equivalentQuotes.keys.first);
        }
        _equivalentQuotes[key] = (_clock(), response);
      }
      return response;
    } finally {
      if (identical(_pendingQuotes[key], request)) _pendingQuotes.remove(key);
    }
  }

  static const _unitTokens = {
    'kg',
    'kilo',
    'gr',
    'gramo',
    'ml',
    'cc',
    'cm3',
    'litro',
    'lts',
    'lt',
  };

  static const _ignoredIdentityTokens = {
    'aceite',
    'agua',
    'arroz',
    'azucar',
    'bebida',
    'cafe',
    'chocolate',
    'clasico',
    'crema',
    'cracker',
    'de',
    'del',
    'dulce',
    'el',
    'galleta',
    'galletita',
    'gramo',
    'la',
    'las',
    'leche',
    'los',
    'pan',
    'preservativo',
    'preservativos',
    'queso',
    'sabor',
    'sin',
    'the',
    'tradicional',
    'original',
    'rellena',
    'relleno',
    'pack',
    'combo',
    'unidad',
    'unidades',
    'uni',
    'bli',
    'sup',
    'super',
    'fino',
    'superfino',
    'ultrafino',
    'texturado',
    'yerba',
  };

  static const _variantGroups = [
    {'entera', 'descremada', 'semidescremada', 'liviana'},
    {'clasica', 'original'},
    {'regular', 'light', 'diet', 'zero'},
    {'conazucar', 'sinazucar'},
    {'conlactosa', 'sinlactosa'},
    {'vainilla', 'chocolate', 'frutilla', 'banana', 'coco', 'limon', 'naranja'},
    {'suave', 'intensa', 'fuerte'},
  ];

  static const _productTypeTokens = {
    'aceite',
    'agua',
    'arroz',
    'azucar',
    'cafe',
    'cerveza',
    'crema',
    'dulce',
    'fideo',
    'galleta',
    'galletita',
    'harina',
    'jabon',
    'leche',
    'manteca',
    'mayonesa',
    'pan',
    'papel',
    'queso',
    'shampoo',
    'tomate',
    'yerba',
    'yogur',
  };

  Future<List<StoreComparison>> compareCart({
    required List<CartItem> cartItems,
    required DateTime fecha,
    required List<PaymentMethod> mediosPagoUsuario,
    required List<Promotion> promociones,
    required Set<String> storeIds,
    ShoppingContext context = const ShoppingContext(),
  }) async {
    final result = await compareCartOptions(
      cartItems: cartItems,
      fecha: fecha,
      mediosPagoUsuario: mediosPagoUsuario,
      promociones: promociones,
      storeIds: storeIds,
      context: context,
    );
    return result.singleStoreComparisons;
  }

  Future<CartComparisonResult> compareCartOptions({
    required List<CartItem> cartItems,
    List<Product>? productCatalog,
    required DateTime fecha,
    required List<PaymentMethod> mediosPagoUsuario,
    required List<Promotion> promociones,
    required Set<String> storeIds,
    ShoppingContext context = const ShoppingContext(),
    bool forceRefreshPrices = false,
  }) async {
    if (cartItems.isEmpty) {
      return const CartComparisonResult(
        singleStoreComparisons: [],
        selectedStoresPlan: null,
        bestPerProductPlan: null,
      );
    }

    final stores = await _repository.getSupermarkets();
    final selectedStores = stores
        .where((store) => storeIds.contains(store.id))
        .toList();
    final storesById = {for (final store in selectedStores) store.id: store};
    final allStoresById = {for (final store in stores) store.id: store};
    final products = productCatalog ?? await _repository.getProducts();
    final comparableItems = await Future.wait(
      cartItems.map((cartItem) async {
        final selectedProduct = _productForCartItem(products, cartItem);
        if (selectedProduct == null) {
          return null;
        }
        final offersByStore = <String, SearchResult>{};
        final alternativesByStore = <String, SearchResult>{};
        final storeStatus = <String, String>{};
        final cachedPrices = await _repository.getPricesForProduct(
          cartItem.productId,
        );
        SearchResult? selectedOffer = _selectedOfferFor(
          cartItem: cartItem,
          selectedProduct: selectedProduct,
          cachedPrices: cachedPrices,
          storesById: allStoresById,
        );

        for (final price in cachedPrices) {
          final store = storesById[price.storeId];
          if (store == null || !price.stock) {
            continue;
          }
          offersByStore[store.id] = SearchResult(
            product: selectedProduct,
            price: price,
            supermarket: store,
          );
        }

        if (_repository is ProductEquivalenceRepository ||
            offersByStore.length < selectedStores.length) {
          final equivalenceRepository = _repository;
          if (equivalenceRepository is ProductEquivalenceRepository) {
            final missingStoreIds = {
              for (final store in selectedStores) store.id,
            };
            if (missingStoreIds.isEmpty) {
              return _ComparableCartItem(
                cartItem: cartItem,
                selectedProduct: selectedProduct,
                offersByStore: offersByStore,
                alternativesByStore: alternativesByStore,
                selectedOffer: selectedOffer,
                storeStatus: storeStatus,
              );
            }
            final response = await _equivalentsForCart(
              selectedProduct,
              missingStoreIds,
              context,
              forceRefresh: forceRefreshPrices,
            );
            storeStatus.addAll(response.storeStatus);
            for (final storeId in missingStoreIds) {
              final status = response.storeStatus[storeId];
              if (status != null && status != 'found') {
                offersByStore.remove(storeId);
                if (storeId == cartItem.selectedStoreId) {
                  selectedOffer = null;
                }
              }
            }
            for (final suggestion in response.alternatives) {
              if (missingStoreIds.contains(suggestion.supermarket.id) &&
                  !suggestion.isExactMatch) {
                alternativesByStore.putIfAbsent(
                  suggestion.supermarket.id,
                  () => suggestion,
                );
              }
            }
            for (final result in response.results) {
              if (missingStoreIds.contains(result.supermarket.id) &&
                  result.price.stock &&
                  _isVerifiedEquivalent(selectedProduct, result)) {
                offersByStore[result.supermarket.id] = result;
                if (result.supermarket.id == cartItem.selectedStoreId) {
                  selectedOffer = result;
                }
              }
            }
            for (final storeId in missingStoreIds) {
              if (storeStatus[storeId] == 'found' &&
                  !offersByStore.containsKey(storeId)) {
                storeStatus[storeId] = 'not_found';
              }
            }
          } else {
            for (final query in _searchQueriesForProduct(selectedProduct)) {
              final missingStoreIds = {
                for (final store in selectedStores)
                  if (!offersByStore.containsKey(store.id)) store.id,
              };
              if (missingStoreIds.isEmpty) {
                break;
              }
              final relatedResults = await _repository.searchProducts(
                query: query,
                storeIds: missingStoreIds,
                context: context,
              );
              for (final result in relatedResults) {
                final storeId = result.supermarket.id;
                if (!missingStoreIds.contains(storeId) || !result.price.stock) {
                  continue;
                }
                if (!matchesLocalProduct(selectedProduct, result.product)) {
                  continue;
                }
                offersByStore.putIfAbsent(storeId, () => result);
              }
            }
          }
        }
        selectedOffer ??= cartItem.selectedStoreId == null
            ? null
            : offersByStore[cartItem.selectedStoreId!];

        return _ComparableCartItem(
          cartItem: cartItem,
          selectedProduct: selectedProduct,
          offersByStore: offersByStore,
          alternativesByStore: alternativesByStore,
          selectedOffer: selectedOffer,
          storeStatus: storeStatus,
        );
      }),
    ).then((items) => items.whereType<_ComparableCartItem>().toList());

    final singleStoreComparisons = _buildSingleStoreComparisons(
      comparableItems: comparableItems,
      selectedStores: selectedStores,
      fecha: fecha,
      mediosPagoUsuario: mediosPagoUsuario,
      promociones: promociones,
    );
    final selectedStoresPlan = _buildSelectedStoresPlan(
      comparableItems: comparableItems,
      fecha: fecha,
      mediosPagoUsuario: mediosPagoUsuario,
      promociones: promociones,
    );
    final bestPerProductPlan = _buildBestPerProductPlan(
      comparableItems: comparableItems,
      fecha: fecha,
      mediosPagoUsuario: mediosPagoUsuario,
      promociones: promociones,
    );

    return CartComparisonResult(
      singleStoreComparisons: singleStoreComparisons,
      selectedStoresPlan: selectedStoresPlan,
      bestPerProductPlan: bestPerProductPlan,
    );
  }

  List<StoreComparison> _buildSingleStoreComparisons({
    required List<_ComparableCartItem> comparableItems,
    required List<Supermarket> selectedStores,
    required DateTime fecha,
    required List<PaymentMethod> mediosPagoUsuario,
    required List<Promotion> promociones,
  }) {
    final comparisons = <StoreComparison>[];
    for (final store in selectedStores) {
      final purchaseTotal = comparableItems.fold<double>(0, (total, item) {
        final offer = item.offersByStore[store.id];
        return total +
            (offer != null && offer.price.stock
                ? offer.price.priceOriginal * item.cartItem.quantity
                : 0);
      });
      final lines = <PricedCartItem>[];
      final missing = <Product>[];
      final missingStatus = <String, String>{};
      final alternativesByProduct = <String, SearchResult>{};
      for (final item in comparableItems) {
        final result = item.offersByStore[store.id];
        if (result == null || !result.price.stock) {
          missing.add(item.selectedProduct);
          missingStatus[item.selectedProduct.id] =
              item.storeStatus[store.id] ?? 'not_found';
          final alternative = item.alternativesByStore[store.id];
          if (alternative != null) {
            alternativesByProduct[item.selectedProduct.id] = alternative;
          }
          continue;
        }
        final cartItem = item.cartItem;
        lines.add(
          _pricedLineFromResult(
            cartItem: cartItem,
            result: result,
            fecha: fecha,
            mediosPagoUsuario: mediosPagoUsuario,
            promociones: promociones,
            purchaseTotal: purchaseTotal,
          ),
        );
      }

      final cappedLines = _applyAggregateCaps(lines, fecha);
      final totalOriginal = cappedLines.fold<double>(
        0,
        (total, line) => total + line.discount.precioOriginal,
      );
      final totalDiscount = cappedLines.fold<double>(
        0,
        (total, line) => total + line.discount.importeDescuento,
      );
      comparisons.add(
        StoreComparison(
          supermarket: store,
          items: cappedLines,
          missingProducts: missing,
          totalOriginal: totalOriginal,
          totalDiscount: totalDiscount,
          totalFinal: totalOriginal - totalDiscount,
          missingStatus: missingStatus,
          alternativesByProduct: alternativesByProduct,
        ),
      );
    }

    comparisons.sort((a, b) {
      if (a.hasAllProducts != b.hasAllProducts) {
        return a.hasAllProducts ? -1 : 1;
      }
      final missingCountComparison = a.missingProducts.length.compareTo(
        b.missingProducts.length,
      );
      if (missingCountComparison != 0) {
        return missingCountComparison;
      }
      return a.totalFinal.compareTo(b.totalFinal);
    });
    return comparisons;
  }

  MultiStoreComparison? _buildSelectedStoresPlan({
    required List<_ComparableCartItem> comparableItems,
    required DateTime fecha,
    required List<PaymentMethod> mediosPagoUsuario,
    required List<Promotion> promociones,
  }) {
    if (comparableItems.isEmpty) {
      return null;
    }
    final totalsByStore = <String, double>{};
    for (final item in comparableItems) {
      final offer = item.selectedOffer;
      if (offer != null && offer.price.stock) {
        final storeId = offer.supermarket.id;
        totalsByStore[storeId] =
            (totalsByStore[storeId] ?? 0) +
            offer.price.priceOriginal * item.cartItem.quantity;
      }
    }
    final lines = <PricedCartItem>[];
    final missing = <Product>[];
    for (final item in comparableItems) {
      final result = item.selectedOffer;
      if (result == null || !result.price.stock) {
        missing.add(item.selectedProduct);
        continue;
      }
      lines.add(
        _pricedLineFromResult(
          cartItem: item.cartItem,
          result: result,
          fecha: fecha,
          mediosPagoUsuario: mediosPagoUsuario,
          promociones: promociones,
          purchaseTotal: totalsByStore[result.supermarket.id],
        ),
      );
    }
    return _multiStorePlan(
      lines,
      missing,
      fecha: fecha,
      mediosPagoUsuario: mediosPagoUsuario,
      promociones: promociones,
    );
  }

  MultiStoreComparison? _buildBestPerProductPlan({
    required List<_ComparableCartItem> comparableItems,
    required DateTime fecha,
    required List<PaymentMethod> mediosPagoUsuario,
    required List<Promotion> promociones,
  }) {
    if (comparableItems.isEmpty) {
      return null;
    }
    final lines = <PricedCartItem>[];
    final missing = <Product>[];
    for (final item in comparableItems) {
      PricedCartItem? bestLine;
      for (final result in item.offersByStore.values) {
        final line = _pricedLineFromResult(
          cartItem: item.cartItem,
          result: result,
          fecha: fecha,
          mediosPagoUsuario: mediosPagoUsuario,
          promociones: promociones,
        );
        if (bestLine == null ||
            line.discount.precioFinal < bestLine.discount.precioFinal) {
          bestLine = line;
        }
      }
      if (bestLine == null) {
        missing.add(item.selectedProduct);
      } else {
        lines.add(bestLine);
      }
    }
    return _multiStorePlan(
      lines,
      missing,
      fecha: fecha,
      mediosPagoUsuario: mediosPagoUsuario,
      promociones: promociones,
    );
  }

  SearchResult? _selectedOfferFor({
    required CartItem cartItem,
    required Product selectedProduct,
    required List<ProductPrice> cachedPrices,
    required Map<String, Supermarket> storesById,
  }) {
    ProductPrice? selectedPrice;
    for (final price in cachedPrices) {
      if (price.storeId == cartItem.selectedStoreId) {
        selectedPrice = price;
        break;
      }
    }
    if (selectedPrice == null && cartItem.selectedStoreId == null) {
      for (final price in cachedPrices) {
        selectedPrice = price;
        break;
      }
    }
    if (selectedPrice == null || !selectedPrice.stock) {
      return null;
    }
    final store = storesById[selectedPrice.storeId];
    if (store == null) {
      return null;
    }
    return SearchResult(
      product: selectedProduct,
      price: selectedPrice,
      supermarket: store,
    );
  }

  PricedCartItem _pricedLineFromResult({
    required CartItem cartItem,
    required SearchResult result,
    required DateTime fecha,
    required List<PaymentMethod> mediosPagoUsuario,
    required List<Promotion> promociones,
    double? purchaseTotal,
  }) {
    final lineOriginal = result.price.priceOriginal * cartItem.quantity;
    final discount = _discountEngine.calcularPrecioFinal(
      product: result.product,
      supermercado: result.supermarket.id,
      precioOriginal: lineOriginal,
      fecha: fecha,
      mediosPagoUsuario: mediosPagoUsuario,
      promociones: [...promociones, ...result.price.quantityOffers],
      quantity: cartItem.quantity,
      purchaseTotal: purchaseTotal,
      hasStoreOffer: result.price.hasStoreOffer,
      branchId: result.price.branchId,
      usedRefundCaps: usedRefundCaps,
    );
    return PricedCartItem(
      product: result.product,
      supermarket: result.supermarket,
      quantity: cartItem.quantity,
      price: result.price,
      discount: discount,
      cartProductId: cartItem.productId,
    );
  }

  MultiStoreComparison repriceKnownLines(
    List<PricedCartItem> lines, {
    required DateTime date,
    required List<PaymentMethod> paymentMethods,
    required List<Promotion> promotions,
  }) => _multiStorePlan(
    lines,
    const [],
    fecha: date,
    mediosPagoUsuario: paymentMethods,
    promociones: promotions,
  );

  MultiStoreComparison _multiStorePlan(
    List<PricedCartItem> lines,
    List<Product> missing, {
    required DateTime fecha,
    required List<PaymentMethod> mediosPagoUsuario,
    required List<Promotion> promociones,
  }) {
    final totalsByStore = <String, double>{};
    for (final line in lines) {
      final id = line.supermarket.id;
      totalsByStore[id] =
          (totalsByStore[id] ?? 0) + line.price.priceOriginal * line.quantity;
    }
    final repriced = [
      for (final line in lines)
        PricedCartItem(
          product: line.product,
          supermarket: line.supermarket,
          quantity: line.quantity,
          price: line.price,
          cartProductId: line.cartProductId,
          discount: _discountEngine.calcularPrecioFinal(
            product: line.product,
            supermercado: line.supermarket.id,
            precioOriginal: line.price.priceOriginal * line.quantity,
            quantity: line.quantity,
            fecha: fecha,
            mediosPagoUsuario: mediosPagoUsuario,
            promociones: [...promociones, ...line.price.quantityOffers],
            purchaseTotal: totalsByStore[line.supermarket.id],
            hasStoreOffer: line.price.hasStoreOffer,
            branchId: line.price.branchId,
            usedRefundCaps: usedRefundCaps,
          ),
        ),
    ];
    final cappedLines = _applyAggregateCaps(repriced, fecha);
    final totalOriginal = cappedLines.fold<double>(
      0,
      (total, line) => total + line.discount.precioOriginal,
    );
    final totalDiscount = cappedLines.fold<double>(
      0,
      (total, line) => total + line.discount.importeDescuento,
    );
    return MultiStoreComparison(
      items: cappedLines,
      missingProducts: missing,
      totalOriginal: totalOriginal,
      totalDiscount: totalDiscount,
      totalFinal: totalOriginal - totalDiscount,
    );
  }

  Product? _productForCartItem(List<Product> products, CartItem cartItem) {
    for (final product in products) {
      if (product.id == cartItem.productId) {
        return product;
      }
    }
    return null;
  }

  bool _isComparableSize(Product selectedProduct, Product candidateProduct) {
    final selectedSize = _measurementFor(selectedProduct);
    final candidateSize = _measurementFor(candidateProduct);
    if (selectedSize == null || candidateSize == null) {
      return selectedSize == null && candidateSize == null;
    }
    if (selectedSize.unit != candidateSize.unit) {
      return false;
    }
    if ((selectedSize.packCount == null) != (candidateSize.packCount == null)) {
      return false;
    }
    if (selectedSize.packCount != null &&
        candidateSize.packCount != null &&
        selectedSize.packCount != candidateSize.packCount) {
      return false;
    }
    final difference = (selectedSize.value - candidateSize.value).abs();
    final tolerance = (selectedSize.value * 0.02).clamp(1, 50).toDouble();
    return difference <= tolerance;
  }

  bool isVerifiedEquivalent(Product selectedProduct, SearchResult result) =>
      _isVerifiedEquivalent(selectedProduct, result);

  bool _isVerifiedEquivalent(Product selectedProduct, SearchResult result) {
    if (!result.isExactMatch) {
      return false;
    }
    final candidate = result.product;
    if (selectedProduct.ean.isNotEmpty &&
        candidate.ean.isNotEmpty &&
        selectedProduct.ean != candidate.ean) {
      return false;
    }
    final selectedSize = _measurementFor(selectedProduct);
    final candidateSize = _measurementFor(candidate);
    if (selectedSize != null &&
        candidateSize != null &&
        !_isComparableSize(selectedProduct, candidate)) {
      return false;
    }
    if (selectedProduct.ean.isNotEmpty &&
        candidate.ean.isNotEmpty &&
        selectedProduct.ean == candidate.ean) {
      return !_hasPercentageMismatch(selectedProduct.name, candidate.name) ||
          !RegExp(r'\d+(?:[,.]\d+)?\s*%').hasMatch(candidate.name);
    }
    return !_hasVariantConflict(selectedProduct.name, candidate.name);
  }

  bool matchesLocalProduct(Product selectedProduct, Product candidateProduct) {
    final sameEan =
        selectedProduct.ean.isNotEmpty &&
        candidateProduct.ean.isNotEmpty &&
        selectedProduct.ean == candidateProduct.ean;
    if (selectedProduct.ean.isNotEmpty &&
        candidateProduct.ean.isNotEmpty &&
        !sameEan) {
      return false;
    }
    final selectedSize = _measurementFor(selectedProduct);
    final candidateSize = _measurementFor(candidateProduct);
    if (selectedSize != null &&
        candidateSize != null &&
        !_isComparableSize(selectedProduct, candidateProduct)) {
      return false;
    }
    if (!sameEan && !_isComparableSize(selectedProduct, candidateProduct)) {
      return false;
    }
    if (_hasProductTypeConflict(selectedProduct.name, candidateProduct.name)) {
      return false;
    }
    if (_hasVariantConflict(selectedProduct.name, candidateProduct.name) &&
        !(sameEan &&
            _isCompatibleMilkAlias(
              selectedProduct.name,
              candidateProduct.name,
            ))) {
      return false;
    }
    if (sameEan
        ? _hasExplicitPercentageConflict(
            selectedProduct.name,
            candidateProduct.name,
          )
        : _hasPercentageMismatch(selectedProduct.name, candidateProduct.name)) {
      return false;
    }
    if (sameEan) {
      return true;
    }
    if (selectedProduct.brand.isNotEmpty &&
        candidateProduct.brand.isNotEmpty &&
        _normalizedTokens(selectedProduct.brand).join(' ') !=
            _normalizedTokens(candidateProduct.brand).join(' ')) {
      return false;
    }

    final selectedIdentity = _identityTokens(selectedProduct);
    if (selectedIdentity.isEmpty) {
      return false;
    }
    final candidateIdentity = _identityTokens(candidateProduct);
    final common = selectedIdentity.intersection(candidateIdentity).length;
    final coverage = common / selectedIdentity.length;
    return common > 0 && coverage >= 0.6;
  }

  bool _hasProductTypeConflict(String selectedName, String candidateName) {
    final selected = _variantTokens(selectedName);
    final candidate = _variantTokens(candidateName);
    for (final marker in {
      'repostero',
      'infantil',
      'primeros',
      'chocolatada',
      'almendra',
    }) {
      if (selected.contains(marker) != candidate.contains(marker)) {
        return true;
      }
    }
    final selectedCondom = selected.contains('preservativo');
    final candidateCondom = candidate.contains('preservativo');
    if (selectedCondom != candidateCondom) return true;
    if (selectedCondom) {
      final selectedCount = _unitCount(selectedName);
      final candidateCount = _unitCount(candidateName);
      if (selectedCount == null ||
          candidateCount == null ||
          selectedCount != candidateCount) {
        return true;
      }
      final selectedModel = _condomModel(selectedName);
      final candidateModel = _condomModel(candidateName);
      if (selectedModel == null ||
          candidateModel == null ||
          selectedModel != candidateModel) {
        return true;
      }
    }
    return false;
  }

  int? _unitCount(String name) {
    final match = RegExp(
      r'\b(\d{1,2})\s*(?:u|un|uni|unidades?)\b',
      caseSensitive: false,
    ).firstMatch(name);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  String? _condomModel(String name) {
    final normalized = _normalizeForModel(name);
    if (RegExp(r'\bultra\s*fino\b|\bultrafino\b').hasMatch(normalized))
      return 'ultrafino';
    if (RegExp(
      r'\b(?:sup|super)\s*[/ -]?\s*fino\b|\bsuperfino\b',
    ).hasMatch(normalized))
      return 'superfino';
    if (normalized.contains('texturado')) return 'texturado';
    if (normalized.contains('retardante')) return 'retardante';
    return null;
  }

  String _normalizeForModel(String value) => value
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u');

  bool _isCompatibleMilkAlias(String selectedName, String candidateName) {
    final first = _normalizeForModel(selectedName);
    final second = _normalizeForModel(candidateName);
    final hasOnePercent =
        RegExp(r'\b1\s*%').hasMatch(first) ||
        RegExp(r'\b1\s*%').hasMatch(second);
    return hasOnePercent &&
        ((first.contains('liviana') && second.contains('descremada')) ||
            (second.contains('liviana') && first.contains('descremada')));
  }

  bool _hasExplicitPercentageConflict(
    String selectedName,
    String candidateName,
  ) {
    final expression = RegExp(r'(\d+(?:[,.]\d+)?)\s*%');
    final selected = expression
        .allMatches(selectedName)
        .map((match) => match.group(1))
        .toSet();
    final candidate = expression
        .allMatches(candidateName)
        .map((match) => match.group(1))
        .toSet();
    return selected.isNotEmpty &&
        candidate.isNotEmpty &&
        selected.intersection(candidate).isEmpty;
  }

  Set<String> _identityTokens(Product product) {
    final tokens = _normalizedTokens(product.name);
    return {
      for (final token in tokens)
        if (!_ignoredIdentityTokens.contains(token) &&
            !_unitTokens.contains(token) &&
            !RegExp(r'\d').hasMatch(token))
          token,
    };
  }

  bool _hasVariantConflict(String selectedName, String candidateName) {
    final selected = _variantTokens(selectedName);
    final candidate = _variantTokens(candidateName);
    for (final group in _variantGroups) {
      final selectedGroup = selected.intersection(group);
      final candidateGroup = candidate.intersection(group);
      if (selectedGroup.isNotEmpty &&
          candidateGroup.isNotEmpty &&
          selectedGroup.intersection(candidateGroup).isEmpty) {
        return true;
      }
    }
    return false;
  }

  bool _hasPercentageMismatch(String selectedName, String candidateName) {
    final expression = RegExp(r'(\d+(?:[,.]\d+)?)\s*%');
    final selected = expression
        .allMatches(selectedName)
        .map((match) => double.tryParse(match.group(1)!.replaceAll(',', '.')))
        .whereType<double>()
        .toSet();
    if (selected.isEmpty) {
      return false;
    }
    final candidate = expression
        .allMatches(candidateName)
        .map((match) => double.tryParse(match.group(1)!.replaceAll(',', '.')))
        .whereType<double>()
        .toSet();
    return candidate.isEmpty ||
        !selected.any(
          (requested) =>
              candidate.any((offered) => (requested - offered).abs() < 0.05),
        );
  }

  Set<String> _variantTokens(String value) {
    final words = _normalizedTokens(value);
    return {
      ...words,
      for (var index = 0; index + 1 < words.length; index++)
        '${words[index]}${words[index + 1]}',
    };
  }

  List<String> _searchQueriesForProduct(Product product) {
    final cleanedName = _cleanSearchText(product.name);
    final primary = _searchQueryForProduct(product, cleanedName);
    final withoutMeasurement = cleanedName
        .replaceAll(
          RegExp(
            r'\b\d+(?:[,.]\d+)?\s*(?:kg|kilos?|gr|gramos?|g|lt|lts?|litros?|l|ml|cc|cm3)\b',
            caseSensitive: false,
          ),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final withoutPackaging = withoutMeasurement
        .replaceAll(
          RegExp(
            r'\b(?:larga\s+vida|sachet|botella|bidon|pote|lata|caja|bolsa|carton|pet)\b',
            caseSensitive: false,
          ),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final tokens = _normalizedTokens(cleanedName);
    final productType = tokens.firstWhere(
      _productTypeTokens.contains,
      orElse: () => tokens.isEmpty ? '' : tokens.first,
    );
    final identities = _identityTokens(product).toList()..sort();
    final variants = <String>{
      for (final group in _variantGroups)
        ..._variantTokens(product.name).intersection(group),
    }.toList()..sort();
    final core = [
      productType,
      ...identities.take(2),
      ...variants,
    ].where((token) => token.isNotEmpty).join(' ');

    final candidates = [primary, withoutMeasurement, withoutPackaging, core];
    final seen = <String>{};
    return [
      for (final candidate in candidates)
        if (candidate.isNotEmpty && seen.add(candidate.toLowerCase()))
          candidate,
    ];
  }

  String _searchQueryForProduct(Product product, String cleanedName) {
    if (_hasMeasurement(cleanedName)) {
      return cleanedName;
    }
    final measurement = _measurementTextForSearch(product);
    if (measurement.isEmpty) {
      return cleanedName;
    }
    return '$cleanedName $measurement'.trim();
  }

  String _cleanSearchText(String value) {
    return value
        .replaceAll(RegExp(r'\b\d+(?:[,.]\d+)?\s*%'), ' ')
        .replaceAll(RegExp(r'\b\d{8,14}\b'), ' ')
        .replaceAll(
          RegExp(
            r'\b(?:oferta|ofertas|promo|promocion|promoción|nuevo|nueva|pack|combo)\b',
            caseSensitive: false,
          ),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _hasMeasurement(String value) {
    return RegExp(
      r'\d+(?:[,.]\d+)?\s*(kg|kilos?|gr|gramos?|g|lt|lts?|litros?|l|ml|cc|cm3)\b',
      caseSensitive: false,
    ).hasMatch(value);
  }

  String _measurementTextForSearch(Product product) {
    final source = '${product.presentation} ${product.name}';
    final match = RegExp(
      r'(\d+(?:[,.]\d+)?)\s*(kg|kilos?|gr|gramos?|g|lt|lts?|litros?|l|ml|cc|cm3)\b',
      caseSensitive: false,
    ).firstMatch(source);
    if (match == null) {
      return '';
    }
    final rawValue = double.tryParse(match.group(1)!.replaceAll(',', '.'));
    if (rawValue == null || rawValue <= 0) {
      return '';
    }
    final rawUnit = match.group(2)!.toLowerCase();
    if (rawUnit == 'kg' || rawUnit == 'kilo' || rawUnit == 'kilos') {
      return _formatMeasurement(rawValue, 'kg');
    }
    if (rawUnit == 'g' ||
        rawUnit == 'gr' ||
        rawUnit == 'gramo' ||
        rawUnit == 'gramos') {
      return _formatMeasurement(rawValue, 'g');
    }
    if (rawUnit == 'l' ||
        rawUnit == 'lt' ||
        rawUnit == 'lts' ||
        rawUnit == 'litro' ||
        rawUnit == 'litros') {
      return _formatMeasurement(rawValue, 'L');
    }
    return _formatMeasurement(rawValue, 'cc');
  }

  String _formatMeasurement(double value, String unit) {
    final numeric = value == value.roundToDouble()
        ? value.round().toString()
        : value
              .toStringAsFixed(2)
              .replaceAll(RegExp(r'0+$'), '')
              .replaceAll(RegExp(r'\.$'), '');
    return '$numeric$unit';
  }

  List<String> _normalizedTokens(String value) {
    final normalized = value
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
    if (normalized.isEmpty) {
      return const [];
    }
    return [
      for (final token in normalized.split(RegExp(r'\s+')))
        if (token.length >= 3) _singularToken(token),
    ];
  }

  String _singularToken(String token) {
    if (token.length > 5 && token.endsWith('es')) {
      return token.substring(0, token.length - 2);
    }
    if (token.length > 5 && token.endsWith('s')) {
      return token.substring(0, token.length - 1);
    }
    return token;
  }

  _Measurement? _measurementFor(Product product) {
    final source = '${product.presentation} ${product.name}';
    final packMatch = RegExp(
      r'(\d{1,2})\s*(?:x|por)\s*(\d+(?:[,.]\d+)?)\s*(kg|kilos?|gr|gramos?|g|lt|lts?|litros?|l|ml|cc|cm3)\b',
      caseSensitive: false,
    ).firstMatch(source);
    if (packMatch != null) {
      final count = int.tryParse(packMatch.group(1)!);
      final itemValue = double.tryParse(
        packMatch.group(2)!.replaceAll(',', '.'),
      );
      if (count != null && count > 1 && itemValue != null) {
        return _canonicalMeasurement(
          itemValue,
          packMatch.group(3)!,
          packCount: count,
        );
      }
    }
    final reversePackMatch = RegExp(
      r'(\d+(?:[,.]\d+)?)\s*(kg|kilos?|gr|gramos?|g|lt|lts?|litros?|l|ml|cc|cm3)\s*(?:x|por)\s*(\d{1,2})(?:\s*(?:u|un|unidades?))?\b',
      caseSensitive: false,
    ).firstMatch(source);
    if (reversePackMatch != null) {
      final itemValue = double.tryParse(
        reversePackMatch.group(1)!.replaceAll(',', '.'),
      );
      final count = int.tryParse(reversePackMatch.group(3)!);
      if (count != null && count > 1 && itemValue != null) {
        return _canonicalMeasurement(
          itemValue,
          reversePackMatch.group(2)!,
          packCount: count,
        );
      }
    }
    final match = RegExp(
      r'(\d+(?:[,.]\d+)?)\s*(kg|kilos?|gr|gramos?|g|lt|lts?|litros?|l|ml|cc|cm3)\b',
      caseSensitive: false,
    ).firstMatch(source);
    if (match == null) {
      return null;
    }
    final value = double.tryParse(match.group(1)!.replaceAll(',', '.'));
    if (value == null || value <= 0) {
      return null;
    }
    return _canonicalMeasurement(value, match.group(2)!);
  }

  _Measurement? _canonicalMeasurement(
    double itemValue,
    String rawUnit, {
    int? packCount,
  }) {
    final unit = rawUnit.toLowerCase();
    final multiplier = packCount ?? 1;
    if (unit == 'kg' || unit == 'kilo' || unit == 'kilos') {
      return _Measurement(itemValue * 1000 * multiplier, 'g', packCount);
    }
    if (unit == 'g' || unit == 'gr' || unit == 'gramo' || unit == 'gramos') {
      return _Measurement(itemValue * multiplier, 'g', packCount);
    }
    if (unit == 'l' ||
        unit == 'lt' ||
        unit == 'lts' ||
        unit == 'litro' ||
        unit == 'litros') {
      return _Measurement(itemValue * 1000 * multiplier, 'ml', packCount);
    }
    if (unit == 'ml' || unit == 'cc' || unit == 'cm3') {
      return _Measurement(itemValue * multiplier, 'ml', packCount);
    }
    return null;
  }

  List<PricedCartItem> _applyAggregateCaps(
    List<PricedCartItem> lines,
    DateTime fecha,
  ) {
    final rawDiscountByPromo = <String, double>{};
    final capByPromo = <String, double>{};
    for (final line in lines) {
      final promotion = line.discount.promocionUsada;
      if (promotion == null) {
        continue;
      }
      rawDiscountByPromo[promotion.id] =
          (rawDiscountByPromo[promotion.id] ?? 0) + line.discount.rawDiscount;
      final key = promotion.capUsageKey(fecha);
      capByPromo[promotion.id] =
          (promotion.topeReintegro -
                  (key == null ? 0 : (usedRefundCaps[key] ?? 0)))
              .clamp(0.0, double.infinity);
    }

    return [
      for (final line in lines)
        _lineWithAggregateCap(line, rawDiscountByPromo, capByPromo),
    ];
  }

  PricedCartItem _lineWithAggregateCap(
    PricedCartItem line,
    Map<String, double> rawDiscountByPromo,
    Map<String, double> capByPromo,
  ) {
    final promotion = line.discount.promocionUsada;
    if (promotion == null) {
      return line;
    }
    final totalRaw = rawDiscountByPromo[promotion.id] ?? 0;
    final cap = capByPromo[promotion.id] ?? promotion.topeReintegro;
    if (promotion.topeReintegro <= 0 || totalRaw <= cap) {
      return line;
    }
    final ratio = cap / totalRaw;
    final adjustedDiscount = line.discount.rawDiscount * ratio;
    return PricedCartItem(
      product: line.product,
      supermarket: line.supermarket,
      quantity: line.quantity,
      price: line.price,
      discount: line.discount.copyWith(
        importeDescuento: adjustedDiscount,
        precioFinal: line.discount.precioOriginal - adjustedDiscount,
      ),
      cartProductId: line.cartProductId,
    );
  }
}

class _ComparableCartItem {
  const _ComparableCartItem({
    required this.cartItem,
    required this.selectedProduct,
    required this.offersByStore,
    required this.alternativesByStore,
    required this.selectedOffer,
    required this.storeStatus,
  });

  final CartItem cartItem;
  final Product selectedProduct;
  final Map<String, SearchResult> offersByStore;
  final Map<String, SearchResult> alternativesByStore;
  final SearchResult? selectedOffer;
  final Map<String, String> storeStatus;
}

class _Measurement {
  const _Measurement(this.value, this.unit, [this.packCount]);

  final double value;
  final String unit;
  final int? packCount;
}
