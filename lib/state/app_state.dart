import 'package:flutter/foundation.dart';

import '../models/cart_item.dart';
import '../models/discount.dart';
import '../models/payment_method.dart';
import '../models/price_quote.dart';
import '../models/product.dart';
import '../models/store_comparison.dart';
import '../models/supermarket.dart';
import '../models/shopping_context.dart';
import '../repositories/conviene_repository.dart';
import '../repositories/community_price_repository.dart';
import '../repositories/promotion_status_repository.dart';
import '../repositories/search_status_repository.dart';
import '../services/cart_service.dart';
import '../services/discount_engine.dart';
import '../services/discount_service.dart';
import '../services/payment_method_service.dart';
import '../services/price_comparison_service.dart';
import '../services/product_search_service.dart';
import '../services/product_comparison_service.dart';
import '../services/supermarket_service.dart';
import '../services/user_data_store.dart';
import '../utils/barcode.dart';

class AppState extends ChangeNotifier {
  AppState({
    required ConvieneRepository repository,
    DateTime? initialDate,
    UserDataStore? userDataStore,
  }) : _repository = repository,
       _userDataStore = userDataStore ?? LocalUserDataStore(),
       selectedDate = initialDate ?? DateTime.now(),
       _followToday = initialDate == null,
       _productSearchService = ProductSearchService(repository),
       _supermarketService = SupermarketService(repository),
       _discountEngine = const DiscountEngine(),
       _paymentMethodService = const PaymentMethodService(),
       _cartService = const CartService() {
    _discountService = DiscountService(_repository, _discountEngine);
    productComparison = ProductComparisonService(_repository);
    _priceComparisonService = PriceComparisonService(
      _repository,
      _discountEngine,
      usedRefundCaps: usedRefundCaps,
    );
    paymentMethods = _paymentMethodService.initialMethods();
  }

  final ConvieneRepository _repository;
  final UserDataStore _userDataStore;
  final ProductSearchService _productSearchService;
  final SupermarketService _supermarketService;
  final DiscountEngine _discountEngine;
  final PaymentMethodService _paymentMethodService;
  final CartService _cartService;
  late final DiscountService _discountService;
  late final PriceComparisonService _priceComparisonService;
  late final ProductComparisonService productComparison;

  List<Supermarket> supermarkets = [];
  Set<String> selectedStoreIds = {};
  List<Product> products = [];
  List<Promotion> promotions = [];
  final Map<String, double> usedRefundCaps = {};
  List<PaymentMethod> paymentMethods = [];
  List<CartItem> cartItems = const [];
  final Set<String> dismissedQuantitySuggestions = {};
  Set<String> favoriteProductIds = {};
  List<SearchResult> searchResults = [];
  Set<String> searchPendingStoreIds = {};
  List<StoreComparison> cartComparisons = [];
  MultiStoreComparison? selectedStoresPlan;
  MultiStoreComparison? bestPerProductPlan;

  DateTime selectedDate;
  bool _followToday;
  String searchQuery = 'leche entera';
  SearchSort searchSort = SearchSort.bestPrice;
  ShoppingContext shoppingContext = const ShoppingContext();
  bool paymentSetupComplete = true;
  bool isBootstrapping = true;
  bool isSearching = false;
  bool isComparing = false;
  bool isLoadingPromotions = false;
  String? lastError;
  String? searchWarning;
  String? searchNotice;
  String? promotionsError;
  String? promotionsWarning;

  int _comparisonGeneration = 0;
  int _promotionsGeneration = 0;
  int _searchGeneration = 0;
  Future<void> _persistenceQueue = Future<void>.value();

  List<PaymentMethod> get activePaymentMethods {
    if (!paymentSetupComplete) {
      return [];
    }
    return paymentMethods.where((method) => method.active).toList();
  }

  int get cartQuantity {
    return cartItems.fold<int>(0, (total, item) => total + item.quantity);
  }

  List<Product> get favoriteProducts => [
    for (final product in products)
      if (favoriteProductIds.contains(product.id)) product,
  ];

  bool isFavorite(String productId) => favoriteProductIds.contains(productId);

  bool get canContribute => _repository is CommunityPriceRepository;

  String? get currentUserId {
    final repository = _repository;
    return repository is CommunityPriceRepository
        ? repository.currentUserId
        : null;
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
    final repository = _repository;
    if (repository is! CommunityPriceRepository) {
      throw StateError('Los aportes requieren una sesion iniciada.');
    }
    await repository.saveContribution(
      id: id,
      supermarketId: supermarketId,
      name: name,
      brand: brand,
      presentation: presentation,
      unit: unit,
      category: category,
      ean: ean,
      imageUrl: imageUrl,
      sourceUrl: sourceUrl,
      price: price,
      unitPrice: unitPrice,
      inStock: inStock,
    );
    _priceComparisonService.invalidateQuotes();
    productComparison.invalidateCache();
    await searchProducts(searchQuery);
  }

  void toggleFavorite(Product product) {
    favoriteProductIds = {...favoriteProductIds};
    if (!favoriteProductIds.add(product.id))
      favoriteProductIds.remove(product.id);
    if (favoriteProductIds.contains(product.id) &&
        !products.any((item) => item.id == product.id)) {
      products = [...products, product];
    }
    _persistUserData();
    notifyListeners();
  }

  StoreComparison? get bestComparison {
    if (cartComparisons.isEmpty) {
      return null;
    }
    return cartComparisons.first;
  }

  StoreComparison? get bestCompleteComparison {
    for (final comparison in cartComparisons) {
      if (comparison.hasAllProducts) {
        return comparison;
      }
    }
    return null;
  }

  List<Supermarket> get enabledSupermarkets {
    return supermarkets.where((store) => store.enabled).toList();
  }

  Future<void> initialize() async {
    isBootstrapping = true;
    lastError = null;
    searchWarning = null;
    searchNotice = null;
    notifyListeners();
    try {
      supermarkets = await _supermarketService.loadSupermarkets();
      products = await _repository.getProducts();
      SavedUserData? savedData;
      try {
        savedData = await _userDataStore.load();
      } catch (_) {
        savedData = null;
      }
      selectedStoreIds = {
        for (final store in supermarkets.where((store) => store.enabled))
          store.id,
      };
      if (savedData != null) {
        usedRefundCaps
          ..clear()
          ..addAll(savedData.usedRefundCaps);
        final cartProductIds = savedData.cartItems
            .map((item) => item.productId)
            .toSet();
        favoriteProductIds = savedData.favoriteProductIds;
        final retainedIds = {...cartProductIds, ...favoriteProductIds};
        final productsById = {
          for (final product in products) product.id: product,
          for (final product in savedData.productSnapshots)
            if (retainedIds.contains(product.id)) product.id: product,
        };
        products = productsById.values.toList();
        final productIds = products.map((product) => product.id).toSet();
        favoriteProductIds = favoriteProductIds.intersection(productIds);
        final storeIds = supermarkets.map((store) => store.id).toSet();
        cartItems = [
          for (final item in savedData.cartItems)
            if (productIds.contains(item.productId))
              CartItem(
                productId: item.productId,
                quantity: item.quantity.clamp(1, 99).toInt(),
                selectedStoreId: storeIds.contains(item.selectedStoreId)
                    ? item.selectedStoreId
                    : null,
              ),
        ];
        paymentMethods = _paymentMethodService.restore(
          activeIds: savedData.activePaymentMethodIds,
          customMethods: savedData.customPaymentMethods,
        );
      }
      isBootstrapping = false;
      isLoadingPromotions = true;
      notifyListeners();

      final promotionsFuture = _discountService.loadPromotions(selectedDate);
      final searchFuture = searchProducts(searchQuery);
      try {
        promotions = await promotionsFuture;
        promotionsError = null;
        promotionsWarning = _repository is PromotionStatusRepository
            ? (_repository as PromotionStatusRepository).lastPromotionWarning
            : null;
      } catch (_) {
        promotions = [];
        promotionsWarning = null;
        promotionsError =
            'No pudimos consultar los descuentos actualizados. Revisa tu conexion e intenta otra vez.';
      }
      isLoadingPromotions = false;
      notifyListeners();
      await searchFuture;
      await refreshComparisons();
    } catch (_) {
      lastError = 'No pudimos cargar la informacion inicial. Reintenta.';
    } finally {
      isBootstrapping = false;
      isLoadingPromotions = false;
      notifyListeners();
    }
  }

  Future<void> searchProducts(String query) async {
    final generation = ++_searchGeneration;
    final previousQuery = searchQuery;
    searchQuery = query.trim().isEmpty ? 'leche entera' : query.trim();
    if (searchQuery != previousQuery) searchResults = [];
    searchResults = searchResults
        .where((row) => selectedStoreIds.contains(row.supermarket.id))
        .toList();
    lastError = null;
    searchWarning = null;
    searchNotice = null;
    searchPendingStoreIds = Set<String>.of(selectedStoreIds);
    if (RegExp(r'^\d{8,14}$').hasMatch(searchQuery) &&
        normalizedBarcode(searchQuery) == null) {
      isSearching = false;
      searchPendingStoreIds = {};
      lastError = 'El codigo de barras no es valido. Revisa los digitos.';
      notifyListeners();
      return;
    }
    isSearching = true;
    notifyListeners();
    try {
      final results = await _productSearchService.search(
        query: searchQuery,
        storeIds: selectedStoreIds,
        sort: searchSort,
        context: shoppingContext,
        onProgress: (partial, pending) {
          if (generation != _searchGeneration) return;
          searchResults = _productSearchService.sortResults(
            partial,
            searchSort,
            query: searchQuery,
            effectivePrice: (result) => discountForResult(result).precioFinal,
          );
          final known = {for (final product in products) product.id: product};
          for (final result in partial) {
            known[result.product.id] = result.product;
          }
          products = known.values.toList();
          searchPendingStoreIds = pending;
          notifyListeners();
        },
      );
      final warning = _repository is SearchStatusRepository
          ? (_repository as SearchStatusRepository).lastSearchWarning
          : null;
      final notice = _repository is SearchStatusRepository
          ? (_repository as SearchStatusRepository).lastSearchNotice
          : null;
      final loadedProducts = await _repository.getProducts();
      if (generation != _searchGeneration) {
        return;
      }
      searchResults = _productSearchService.sortResults(
        results,
        searchSort,
        query: searchQuery,
        effectivePrice: (result) => discountForResult(result).precioFinal,
      );
      searchWarning = warning;
      searchNotice = notice;
      final cartProductIds = cartItems.map((item) => item.productId).toSet();
      final retainedIds = {...cartProductIds, ...favoriteProductIds};
      products = {
        for (final product in loadedProducts) product.id: product,
        for (final result in results) result.product.id: result.product,
        for (final product in products)
          if (retainedIds.contains(product.id)) product.id: product,
      }.values.toList();
    } catch (error, stackTrace) {
      if (generation == _searchGeneration) {
        assert(() {
          debugPrint('Product search failed: $error\n$stackTrace');
          return true;
        }());
        if (searchResults.isNotEmpty) {
          searchWarning =
              'No se pudo completar la busqueda. Los precios visibles son parciales.';
        } else {
          searchResults = [];
        }
        lastError =
            'No pudimos actualizar los resultados. Revisa tu conexion e intenta otra vez.';
      }
    } finally {
      if (generation == _searchGeneration) {
        isSearching = false;
        searchPendingStoreIds = {};
        notifyListeners();
      }
    }
  }

  void setSearchSort(SearchSort sort) {
    searchSort = sort;
    searchResults = _productSearchService.sortResults(
      searchResults,
      sort,
      query: searchQuery,
      effectivePrice: (result) => discountForResult(result).precioFinal,
    );
    notifyListeners();
  }

  Future<void> toggleStore(String storeId) async {
    if (selectedStoreIds.contains(storeId)) {
      if (selectedStoreIds.length == 1) {
        return;
      }
      selectedStoreIds = {...selectedStoreIds}..remove(storeId);
    } else {
      selectedStoreIds = {...selectedStoreIds, storeId};
    }
    notifyListeners();
    await searchProducts(searchQuery);
    await refreshComparisons();
  }

  Future<void> setSelectedStores(Set<String> storeIds) async {
    final enabledIds = enabledSupermarkets.map((store) => store.id).toSet();
    final validIds = storeIds.intersection(enabledIds);
    if (validIds.isEmpty || setEquals(validIds, selectedStoreIds)) return;
    selectedStoreIds = validIds;
    notifyListeners();
    await searchProducts(searchQuery);
    await refreshComparisons();
  }

  Future<void> setSelectedDate(DateTime date) async {
    final generation = ++_promotionsGeneration;
    final previousDate = selectedDate;
    selectedDate = DateTime(date.year, date.month, date.day);
    final today = DateTime.now();
    _followToday =
        selectedDate.year == today.year &&
        selectedDate.month == today.month &&
        selectedDate.day == today.day;
    if (selectedDate != previousDate) promotions = [];
    promotionsError = null;
    promotionsWarning = null;
    isLoadingPromotions = true;
    notifyListeners();

    try {
      final loadedPromotions = await _discountService.loadPromotions(
        selectedDate,
      );
      if (generation != _promotionsGeneration) {
        return;
      }
      promotions = loadedPromotions;
      promotionsWarning = _repository is PromotionStatusRepository
          ? (_repository as PromotionStatusRepository).lastPromotionWarning
          : null;
    } catch (_) {
      if (generation == _promotionsGeneration) {
        promotions = [];
        promotionsWarning = null;
        promotionsError =
            'No pudimos consultar los descuentos actualizados. Revisa tu conexion e intenta otra vez.';
      }
    } finally {
      if (generation == _promotionsGeneration) {
        isLoadingPromotions = false;
        notifyListeners();
      }
    }
    if (generation == _promotionsGeneration) {
      await refreshComparisons();
    }
  }

  Future<void> refreshPromotionsForTodayIfNeeded() async {
    if (!_followToday) return;
    final now = DateTime.now();
    if (selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day) {
      return;
    }
    await setSelectedDate(now);
  }

  Future<void> addOfferToCart(SearchResult result, {int quantity = 1}) async {
    if (quantity < 1 || quantity > 99 || !result.price.stock) return;
    products = [
      ...products.where((p) => p.id != result.product.id),
      result.product,
    ];
    var previous = 0;
    for (final item in cartItems) {
      if (item.productId == result.product.id &&
          item.selectedStoreId == result.supermarket.id) {
        previous = item.quantity;
      }
    }
    cartItems = _cartService.addProduct(
      cartItems,
      result.product.id,
      selectedStoreId: result.supermarket.id,
    );
    cartItems = _cartService.updateQuantity(
      cartItems,
      result.product.id,
      previous + quantity,
      result.supermarket.id,
    );
    _persistUserData();
    notifyListeners();
    await refreshComparisons();
  }

  Future<void> addProductToCart(
    String productId, {
    String? selectedStoreId,
  }) async {
    cartItems = _cartService.addProduct(
      cartItems,
      productId,
      selectedStoreId: selectedStoreId,
    );
    _persistUserData();
    notifyListeners();
    await refreshComparisons();
  }

  Future<void> updateCartQuantity(
    String productId,
    int quantity, {
    String? selectedStoreId,
  }) async {
    cartItems = _cartService.updateQuantity(
      cartItems,
      productId,
      quantity,
      selectedStoreId,
    );
    _persistUserData();
    notifyListeners();
    await refreshComparisons();
  }

  Future<void> removeCartItem(
    String productId, {
    String? selectedStoreId,
  }) async {
    cartItems = _cartService.removeProduct(
      cartItems,
      productId,
      selectedStoreId,
    );
    _persistUserData();
    notifyListeners();
    await refreshComparisons();
  }

  Future<void> clearCart() async {
    ++_comparisonGeneration;
    cartItems = [];
    cartComparisons = [];
    selectedStoresPlan = null;
    bestPerProductPlan = null;
    isComparing = false;
    _persistUserData();
    notifyListeners();
  }

  Future<void> togglePaymentMethod(String methodId) async {
    paymentMethods = _paymentMethodService.toggle(paymentMethods, methodId);
    _persistUserData();
    notifyListeners();
    await refreshComparisons();
  }

  Future<bool> addPaymentMethod(
    PaymentMethodType type,
    String displayName,
  ) async {
    final result = _paymentMethodService.addCustom(
      methods: paymentMethods,
      type: type,
      displayName: displayName,
    );
    paymentMethods = result.methods;
    _persistUserData();
    notifyListeners();
    await refreshComparisons();
    return result.added;
  }

  void _persistUserData() {
    final initialIds = _paymentMethodService
        .initialMethods()
        .map((method) => method.id)
        .toSet();
    final snapshot = SavedUserData(
      cartItems: List.unmodifiable(cartItems),
      productSnapshots: List.unmodifiable(
        products.where(
          (product) =>
              cartItems.any((item) => item.productId == product.id) ||
              favoriteProductIds.contains(product.id),
        ),
      ),
      favoriteProductIds: Set.unmodifiable(favoriteProductIds),
      activePaymentMethodIds: paymentMethods
          .where((method) => method.active && initialIds.contains(method.id))
          .map((method) => method.id)
          .toSet(),
      customPaymentMethods: List.unmodifiable(
        paymentMethods.where((method) => method.id.startsWith('custom_')),
      ),
      usedRefundCaps: Map.unmodifiable(usedRefundCaps),
    );
    _persistenceQueue = _persistenceQueue.then(
      (_) async {
        try {
          await _userDataStore.save(snapshot);
        } catch (_) {
          // Storage can be unavailable in restricted browser contexts.
        }
      },
      onError: (Object _) async {
        try {
          await _userDataStore.save(snapshot);
        } catch (_) {
          // Keep later saves usable if an earlier write failed.
        }
      },
    );
  }

  Future<void> savePaymentMethods() async {
    paymentSetupComplete = true;
    notifyListeners();
    await refreshComparisons();
  }

  double? usedRefundCapFor(Promotion promotion) {
    final key = promotion.capUsageKey(selectedDate);
    return key == null ? null : usedRefundCaps[key];
  }

  Future<void> setUsedRefundCap(Promotion promotion, double amount) async {
    final key = promotion.capUsageKey(selectedDate);
    if (key == null ||
        !amount.isFinite ||
        amount < 0 ||
        amount > promotion.topeReintegro) {
      throw ArgumentError('Importe de tope utilizado invalido');
    }
    usedRefundCaps[key] = amount;
    _persistUserData();
    notifyListeners();
    await refreshComparisons();
  }

  DiscountQuote previewCartLine(PricedCartItem target, int quantity) {
    final targetId = target.cartProductId ?? target.product.id;
    final lines = selectedStoresPlan?.items ?? [target];
    final preview = _priceComparisonService.repriceKnownLines(
      [
        for (final line in lines)
          PricedCartItem(
            product: line.product,
            supermarket: line.supermarket,
            quantity:
                (line.cartProductId ?? line.product.id) == targetId &&
                    line.supermarket.id == target.supermarket.id
                ? quantity
                : line.quantity,
            price: line.price,
            discount: line.discount,
            cartProductId: line.cartProductId,
          ),
      ],
      date: selectedDate,
      paymentMethods: activePaymentMethods,
      promotions: promotions,
    );
    return preview.items
        .firstWhere(
          (line) =>
              (line.cartProductId ?? line.product.id) == targetId &&
              line.supermarket.id == target.supermarket.id,
        )
        .discount;
  }

  DiscountQuote discountForResult(SearchResult result, {int quantity = 1}) {
    return _discountEngine.calcularPrecioFinal(
      product: result.product,
      supermercado: result.supermarket.id,
      precioOriginal: result.price.priceOriginal * quantity,
      quantity: quantity,
      purchaseTotal: result.price.priceOriginal * quantity,
      branchId: result.price.branchId,
      hasStoreOffer: result.price.hasStoreOffer,
      fecha: selectedDate,
      mediosPagoUsuario: activePaymentMethods,
      promociones: [...promotions, ...result.price.quantityOffers],
      usedRefundCaps: usedRefundCaps,
    );
  }

  Product? productById(String productId) {
    for (final product in products) {
      if (product.id == productId) {
        return product;
      }
    }
    return null;
  }

  Future<void> refreshComparisons({bool forceRefreshPrices = false}) async {
    final generation = ++_comparisonGeneration;
    isComparing = true;
    notifyListeners();
    try {
      final comparisonResult = await _priceComparisonService.compareCartOptions(
        cartItems: cartItems,
        productCatalog: products,
        fecha: selectedDate,
        mediosPagoUsuario: activePaymentMethods,
        promociones: promotions,
        storeIds: selectedStoreIds,
        context: shoppingContext,
        forceRefreshPrices: forceRefreshPrices,
      );
      if (generation != _comparisonGeneration) {
        return;
      }
      cartComparisons = comparisonResult.singleStoreComparisons;
      selectedStoresPlan = comparisonResult.selectedStoresPlan;
      bestPerProductPlan = comparisonResult.bestPerProductPlan;
    } catch (_) {
      if (generation == _comparisonGeneration) {
        lastError = 'No pudimos recalcular el changuito. Intenta nuevamente.';
      }
    } finally {
      if (generation == _comparisonGeneration) {
        isComparing = false;
        notifyListeners();
      }
    }
  }

  Future<void> retrySearch() => searchProducts(searchQuery);
}
