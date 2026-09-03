import 'package:flutter/foundation.dart';

import '../models/cart_item.dart';
import '../models/discount.dart';
import '../models/payment_method.dart';
import '../models/price_quote.dart';
import '../models/product.dart';
import '../models/store_comparison.dart';
import '../models/supermarket.dart';
import '../repositories/conviene_repository.dart';
import '../services/cart_service.dart';
import '../services/discount_engine.dart';
import '../services/discount_service.dart';
import '../services/payment_method_service.dart';
import '../services/price_comparison_service.dart';
import '../services/product_search_service.dart';
import '../services/supermarket_service.dart';

class AppState extends ChangeNotifier {
  AppState({required ConvieneRepository repository, DateTime? initialDate})
    : _repository = repository,
      selectedDate = initialDate ?? DateTime.now(),
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
  String searchQuery = 'leche entera';
  SearchSort searchSort = SearchSort.bestPrice;
  bool paymentSetupComplete = true;
  bool isBootstrapping = true;
  bool isSearching = false;
  bool isComparing = false;

  int _comparisonGeneration = 0;

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
    notifyListeners();
    supermarkets = await _supermarketService.loadSupermarkets();
    products = await _repository.getProducts();
    selectedStoreIds = {
      for (final store in supermarkets.where((store) => store.enabled))
        store.id,
    };
    promotions = await _discountService.loadPromotions(selectedDate);
    await searchProducts(searchQuery);
    await refreshComparisons();
    isBootstrapping = false;
    notifyListeners();
  }

  Future<void> searchProducts(String query) async {
    searchQuery = query.trim().isEmpty ? 'leche entera' : query.trim();
    isSearching = true;
    notifyListeners();
    searchResults = await _productSearchService.search(
      query: searchQuery,
      storeIds: selectedStoreIds,
      sort: searchSort,
    );
    products = await _repository.getProducts();
    isSearching = false;
    notifyListeners();
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

  Future<void> setSelectedDate(DateTime date) async {
    selectedDate = DateTime(date.year, date.month, date.day);
    promotions = await _discountService.loadPromotions(selectedDate);
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
    notifyListeners();
    await refreshComparisons();
  }

  Future<void> clearCart() async {
    cartItems = [];
    cartComparisons = [];
    selectedStoresPlan = null;
    bestPerProductPlan = null;
    notifyListeners();
  }

  Future<void> togglePaymentMethod(String methodId) async {
    paymentMethods = _paymentMethodService.toggle(paymentMethods, methodId);
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
    notifyListeners();
    await refreshComparisons();
    return result.added;
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
    final comparisonResult = await _priceComparisonService.compareCartOptions(
      cartItems: cartItems,
      fecha: selectedDate,
      mediosPagoUsuario: activePaymentMethods,
      promociones: promotions,
      storeIds: selectedStoreIds,
    );
    if (generation != _comparisonGeneration) {
      return;
    }
    cartComparisons = comparisonResult.singleStoreComparisons;
    selectedStoresPlan = comparisonResult.selectedStoresPlan;
    bestPerProductPlan = comparisonResult.bestPerProductPlan;
    isComparing = false;
    notifyListeners();
  }
}
