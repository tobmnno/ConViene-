import '../models/cart_item.dart';
import '../models/discount.dart';
import '../models/payment_method.dart';
import '../models/price_quote.dart';
import '../models/product.dart';
import '../models/store_comparison.dart';
import '../models/supermarket.dart';
import '../repositories/conviene_repository.dart';
import 'discount_engine.dart';

class PriceComparisonService {
  const PriceComparisonService(this._repository, this._discountEngine);

  final ConvieneRepository _repository;
  final DiscountEngine _discountEngine;

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
    'queso',
    'sabor',
    'sin',
    'the',
    'yerba',
  };

  Future<List<StoreComparison>> compareCart({
    required List<CartItem> cartItems,
    required DateTime fecha,
    required List<PaymentMethod> mediosPagoUsuario,
    required List<Promotion> promociones,
    required Set<String> storeIds,
  }) async {
    final result = await compareCartOptions(
      cartItems: cartItems,
      fecha: fecha,
      mediosPagoUsuario: mediosPagoUsuario,
      promociones: promociones,
      storeIds: storeIds,
    );
    return result.singleStoreComparisons;
  }

  Future<CartComparisonResult> compareCartOptions({
    required List<CartItem> cartItems,
    required DateTime fecha,
    required List<PaymentMethod> mediosPagoUsuario,
    required List<Promotion> promociones,
    required Set<String> storeIds,
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
    final products = await _repository.getProducts();
    final comparableItems = <_ComparableCartItem>[];
    for (final cartItem in cartItems) {
      final selectedProduct = _productForCartItem(products, cartItem);
      if (selectedProduct == null) {
        continue;
      }
      final offersByStore = <String, SearchResult>{};
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

      if (offersByStore.length < selectedStores.length) {
        final relatedResults = await _repository.searchProducts(
          query: selectedProduct.name,
          storeIds: storeIds,
        );
        for (final result in relatedResults) {
          final storeId = result.supermarket.id;
          if (!storesById.containsKey(storeId) || !result.price.stock) {
            continue;
          }
          if (!_isComparableProduct(selectedProduct, result.product)) {
            continue;
          }
          offersByStore.putIfAbsent(storeId, () => result);
        }
      }
      selectedOffer ??= cartItem.selectedStoreId == null
          ? null
          : offersByStore[cartItem.selectedStoreId!];

      comparableItems.add(
        _ComparableCartItem(
          cartItem: cartItem,
          selectedProduct: selectedProduct,
          offersByStore: offersByStore,
          selectedOffer: selectedOffer,
        ),
      );
    }

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
      final lines = <PricedCartItem>[];
      final missing = <Product>[];
      for (final item in comparableItems) {
        final result = item.offersByStore[store.id];
        if (result == null || !result.price.stock) {
          missing.add(item.selectedProduct);
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
          ),
        );
      }

      final cappedLines = _applyAggregateCaps(lines);
      if (cappedLines.isEmpty) {
        continue;
      }
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
        ),
      );
    }
    return _multiStorePlan(lines, missing);
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
    return _multiStorePlan(lines, missing);
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
  }) {
    final lineOriginal = result.price.priceOriginal * cartItem.quantity;
    final discount = _discountEngine.calcularPrecioFinal(
      product: result.product,
      supermercado: result.supermarket.id,
      precioOriginal: lineOriginal,
      fecha: fecha,
      mediosPagoUsuario: mediosPagoUsuario,
      promociones: promociones,
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

  MultiStoreComparison _multiStorePlan(
    List<PricedCartItem> lines,
    List<Product> missing,
  ) {
    final cappedLines = _applyAggregateCaps(lines);
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
    final difference = (selectedSize.value - candidateSize.value).abs();
    final tolerance = (selectedSize.value * 0.02).clamp(1, 50).toDouble();
    return difference <= tolerance;
  }

  bool _isComparableProduct(Product selectedProduct, Product candidateProduct) {
    if (selectedProduct.ean.isNotEmpty &&
        candidateProduct.ean.isNotEmpty &&
        selectedProduct.ean == candidateProduct.ean) {
      return true;
    }
    if (!_isComparableSize(selectedProduct, candidateProduct)) {
      return false;
    }

    final selectedIdentity = _identityTokens(selectedProduct);
    if (selectedIdentity.isEmpty) {
      return true;
    }
    final candidateTokens = _normalizedTokens(candidateProduct.name).toSet();
    return selectedIdentity.every(candidateTokens.contains);
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
    final unit = match.group(2)!.toLowerCase();
    if (unit == 'kg' || unit == 'kilo' || unit == 'kilos') {
      return _Measurement(value * 1000, 'g');
    }
    if (unit == 'g' || unit == 'gr' || unit == 'gramo' || unit == 'gramos') {
      return _Measurement(value, 'g');
    }
    if (unit == 'l' ||
        unit == 'lt' ||
        unit == 'lts' ||
        unit == 'litro' ||
        unit == 'litros') {
      return _Measurement(value * 1000, 'ml');
    }
    if (unit == 'ml' || unit == 'cc' || unit == 'cm3') {
      return _Measurement(value, 'ml');
    }
    return null;
  }

  List<PricedCartItem> _applyAggregateCaps(List<PricedCartItem> lines) {
    final rawDiscountByPromo = <String, double>{};
    final capByPromo = <String, double>{};
    for (final line in lines) {
      final promotion = line.discount.promocionUsada;
      if (promotion == null) {
        continue;
      }
      rawDiscountByPromo[promotion.id] =
          (rawDiscountByPromo[promotion.id] ?? 0) + line.discount.rawDiscount;
      capByPromo[promotion.id] = promotion.topeReintegro;
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
    if (totalRaw <= cap) {
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
    required this.selectedOffer,
  });

  final CartItem cartItem;
  final Product selectedProduct;
  final Map<String, SearchResult> offersByStore;
  final SearchResult? selectedOffer;
}

class _Measurement {
  const _Measurement(this.value, this.unit);

  final double value;
  final String unit;
}
