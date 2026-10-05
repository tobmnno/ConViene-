import 'package:flutter/foundation.dart';

import '../models/cart_item.dart';
import '../models/discount.dart';
import '../models/nearby_store_suggestion.dart';
import '../models/payment_method.dart';
import '../models/price_quote.dart';
import '../models/product.dart';
import '../models/store_comparison.dart';
import '../models/supermarket.dart';
import '../models/shopping_context.dart';
import '../repositories/conviene_repository.dart';
import '../repositories/promotion_status_repository.dart';
import '../services/cart_service.dart';
import '../services/discount_engine.dart';
import '../services/discount_service.dart';
import '../services/payment_method_service.dart';
import '../services/price_comparison_service.dart';
import '../services/product_search_service.dart';
import '../services/supermarket_service.dart';
import '../services/user_data_store.dart';

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
    _priceComparisonService = PriceComparisonService(
      _repository,
      _discountEngine,
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

  List<Supermarket> supermarkets = [];
  Set<String> selectedStoreIds = {};
  List<Product> products = [];
  List<Promotion> promotions = [];
  List<PaymentMethod> paymentMethods = [];
  List<CartItem> cartItems = const [];
  List<SearchResult> searchResults = [];
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
        final cartProductIds = savedData.cartItems
            .map((item) => item.productId)
            .toSet();
        final productsById = {
          for (final product in products) product.id: product,
          for (final product in savedData.productSnapshots)
            if (cartProductIds.contains(product.id)) product.id: product,
        };
        products = productsById.values.toList();
        final productIds = products.map((product) => product.id).toSet();
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
    searchQuery = query.trim().isEmpty ? 'leche entera' : query.trim();
    searchResults = [];
    isSearching = true;
    lastError = null;
    notifyListeners();
    try {
      final results = await _productSearchService.search(
        query: searchQuery,
        storeIds: selectedStoreIds,
        sort: searchSort,
        context: shoppingContext,
      );
      final loadedProducts = await _repository.getProducts();
      if (generation != _searchGeneration) {
        return;
      }
      searchResults = results;
      final cartProductIds = cartItems.map((item) => item.productId).toSet();
      products = {
        for (final product in loadedProducts) product.id: product,
        for (final product in products)
          if (cartProductIds.contains(product.id)) product.id: product,
      }.values.toList();
    } catch (_) {
      if (generation == _searchGeneration) {
        searchResults = [];
        lastError =
            'No pudimos actualizar los resultados. Revisa tu conexion e intenta otra vez.';
      }
    } finally {
      if (generation == _searchGeneration) {
        isSearching = false;
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
    );
    notifyListeners();
  }

  Future<void> updateShoppingContext(ShoppingContext context) async {
    shoppingContext = context;
    notifyListeners();
    await searchProducts(searchQuery);
    await refreshComparisons();
  }

  Future<NearbyStoreSuggestion?> updateDeviceLocation({
    required double latitude,
    required double longitude,
    required double accuracyMeters,
  }) async {
    final suggestion = await _repository.findNearbyCotoStore(
      latitude: latitude,
      longitude: longitude,
    );
    shoppingContext = shoppingContext.copyWith(
      latitude: latitude,
      longitude: longitude,
      locationAccuracyMeters: accuracyMeters,
      cotoStore: suggestion?.storeId,
    );
    notifyListeners();
    await searchProducts(searchQuery);
    await refreshComparisons();
    return suggestion;
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
    selectedDate = DateTime(date.year, date.month, date.day);
    final today = DateTime.now();
    _followToday =
        selectedDate.year == today.year &&
        selectedDate.month == today.month &&
        selectedDate.day == today.day;
    promotions = [];
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
    cartItems = [];
    cartComparisons = [];
    selectedStoresPlan = null;
    bestPerProductPlan = null;
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
          (product) => cartItems.any((item) => item.productId == product.id),
        ),
      ),
      activePaymentMethodIds: paymentMethods
          .where((method) => method.active && initialIds.contains(method.id))
          .map((method) => method.id)
          .toSet(),
      customPaymentMethods: List.unmodifiable(
        paymentMethods.where((method) => method.id.startsWith('custom_')),
      ),
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

  DiscountQuote discountForResult(SearchResult result) {
    return _discountEngine.calcularPrecioFinal(
      product: result.product,
      supermercado: result.supermarket.id,
      precioOriginal: result.price.priceOriginal,
      fecha: selectedDate,
      mediosPagoUsuario: activePaymentMethods,
      promociones: promotions,
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

  Future<void> refreshComparisons() async {
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
