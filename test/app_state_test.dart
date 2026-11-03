import 'dart:async';

import 'package:conviene/models/cart_item.dart';
import 'package:conviene/models/discount.dart';
import 'package:conviene/models/price_quote.dart';
import 'package:conviene/models/shopping_context.dart';
import 'package:conviene/models/supermarket.dart';
import 'package:conviene/models/payment_method.dart';
import 'package:conviene/models/product.dart';
import 'package:conviene/repositories/mock_repository.dart';
import 'package:conviene/services/user_data_store.dart';
import 'package:conviene/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sign-in can dispose an unfinished guest bootstrap safely', () async {
    final repo = _DelayedGuestRepository();
    final state = AppState(repository: repo);
    final loading = state.initialize();
    state.dispose();
    repo.finish.complete(await MockRepository().getSupermarkets());
    await loading;
  });
  test('guest import keeps existing quantities and chosen stores', () async {
    final guest = AppState(
      repository: MockRepository(),
      userDataStore: _MemoryUserDataStore(),
    );
    final account = AppState(
      repository: MockRepository(),
      userDataStore: _MemoryUserDataStore(),
    );
    await guest.initialize();
    await account.initialize();
    final shared = guest.products.first;
    final extra = guest.products.last;
    await guest.addProductToCart(shared.id, selectedStoreId: 'coto');
    await guest.addProductToCart(extra.id, selectedStoreId: 'lagallega');
    guest.toggleFavorite(extra);
    await account.addProductToCart(shared.id, selectedStoreId: 'carrefour');
    await account.updateCartQuantity(
      shared.id,
      3,
      selectedStoreId: 'carrefour',
    );
    final methodsBefore = account.paymentMethods
        .map((method) => method.id)
        .toList();

    await account.importGuestCartAndFavorites(guest.guestImportSnapshot());

    expect(account.cartItems, hasLength(2));
    expect(
      account.cartItems
          .singleWhere((item) => item.productId == shared.id)
          .quantity,
      3,
    );
    expect(
      account.cartItems
          .singleWhere((item) => item.productId == shared.id)
          .selectedStoreId,
      'carrefour',
    );
    expect(
      account.cartItems
          .singleWhere((item) => item.productId == extra.id)
          .selectedStoreId,
      'lagallega',
    );
    expect(account.favoriteProductIds, contains(extra.id));
    expect(
      account.paymentMethods.map((method) => method.id).toList(),
      methodsBefore,
    );
    guest.dispose();
    account.dispose();
  });
  test(
    'clears old results on search failure and exposes discount failures',
    () async {
      final repository = _FlakyRepository();
      final state = AppState(repository: repository);
      await state.initialize();
      expect(state.searchResults, isNotEmpty);

      repository.failSearch = true;
      await state.searchProducts('galletitas chocolinas 100g');
      expect(state.searchResults, isEmpty);
      expect(state.lastError, isNotNull);

      repository.failPromotions = true;
      await state.setSelectedDate(DateTime.now());
      expect(state.promotions, isEmpty);
      expect(state.promotionsError, isNotNull);

      state.dispose();
    },
  );

  test('rejects a mistyped barcode without calling the repository', () async {
    final repository = _FlakyRepository();
    final state = AppState(repository: repository);
    await state.initialize();
    final calls = repository.searchCalls;

    await state.searchProducts('779089500829');

    expect(repository.searchCalls, calls);
    expect(state.searchResults, isEmpty);
    expect(state.lastError, contains('no es valido'));
    expect(state.isSearching, isFalse);
    state.dispose();
  });

  test(
    'restores cart, store choice, and selected payment methods on reload',
    () async {
      final store = _MemoryUserDataStore();
      final firstState = AppState(
        repository: MockRepository(),
        userDataStore: store,
      );
      await firstState.initialize();

      await firstState.addProductToCart(
        firstState.products.first.id,
        selectedStoreId: firstState.supermarkets.first.id,
      );
      await firstState.updateCartQuantity(
        firstState.cartItems.first.productId,
        3,
        selectedStoreId: firstState.cartItems.first.selectedStoreId,
      );
      await firstState.togglePaymentMethod('amex');
      await firstState.addPaymentMethod(
        PaymentMethodType.wallet,
        'Billetera test',
      );
      final favorite = firstState.products.last;
      firstState.toggleFavorite(favorite);

      final reloadedState = AppState(
        repository: _EmptyProductRepository(),
        userDataStore: store,
      );
      await reloadedState.initialize();

      expect(reloadedState.cartItems, hasLength(1));
      expect(
        reloadedState.productById(reloadedState.cartItems.single.productId),
        isNotNull,
      );
      expect(reloadedState.cartItems.single.quantity, 3);
      expect(
        reloadedState.cartItems.single.selectedStoreId,
        firstState.supermarkets.first.id,
      );
      expect(
        reloadedState.paymentMethods
            .singleWhere((method) => method.id == 'amex')
            .active,
        isTrue,
      );
      expect(
        reloadedState.paymentMethods.any(
          (method) => method.displayName == 'Billetera test' && method.active,
        ),
        isTrue,
      );
      expect(reloadedState.bestComparison?.items, isNotEmpty);
      expect(
        reloadedState.favoriteProducts.map((product) => product.id),
        contains(favorite.id),
      );
      reloadedState.toggleFavorite(favorite);
      expect(reloadedState.favoriteProducts, isEmpty);

      firstState.dispose();
      reloadedState.dispose();
    },
  );

  test('clearing cart wins over an older in-flight comparison', () async {
    final repository = _DelayedPricesRepository();
    final state = AppState(
      repository: repository,
      userDataStore: _MemoryUserDataStore(),
    );
    await state.initialize();
    state.cartItems = [
      CartItem(
        productId: state.products.first.id,
        quantity: 1,
        selectedStoreId: 'coto',
      ),
    ];
    final comparison = state.refreshComparisons();
    await repository.started.future.timeout(const Duration(seconds: 2));
    await state.clearCart();
    repository.release.complete();
    await comparison;

    expect(state.cartItems, isEmpty);
    expect(state.cartComparisons, isEmpty);
    expect(state.selectedStoresPlan, isNull);
    expect(state.bestPerProductPlan, isNull);
    expect(state.isComparing, isFalse);
    state.dispose();
  });
}

class _DelayedGuestRepository extends MockRepository {
  final finish = Completer<List<Supermarket>>();

  @override
  Future<List<Supermarket>> getSupermarkets() => finish.future;
}

class _DelayedPricesRepository extends MockRepository {
  final started = Completer<void>();
  final release = Completer<void>();

  @override
  Future<List<ProductPrice>> getPricesForProduct(String productId) async {
    if (!started.isCompleted) started.complete();
    await release.future;
    return super.getPricesForProduct(productId);
  }
}

class _MemoryUserDataStore implements UserDataStore {
  SavedUserData? data;

  @override
  Future<SavedUserData?> load() async => data;

  @override
  Future<void> save(SavedUserData value) async {
    data = value;
  }
}

class _EmptyProductRepository extends MockRepository {
  @override
  Future<List<Product>> getProducts() async => [];
}

class _FlakyRepository extends MockRepository {
  bool failSearch = false;
  bool failPromotions = false;
  int searchCalls = 0;

  @override
  Future<List<SearchResult>> searchProducts({
    required String query,
    required Set<String> storeIds,
    ShoppingContext context = const ShoppingContext(),
  }) {
    searchCalls++;
    if (failSearch) throw StateError('search unavailable');
    return super.searchProducts(
      query: query,
      storeIds: storeIds,
      context: context,
    );
  }

  @override
  Future<List<Promotion>> getPromotions(DateTime date) {
    if (failPromotions) throw StateError('discounts unavailable');
    return super.getPromotions(date);
  }
}
