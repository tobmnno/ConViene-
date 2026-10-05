import 'package:conviene/models/discount.dart';
import 'package:conviene/models/price_quote.dart';
import 'package:conviene/models/shopping_context.dart';
import 'package:conviene/models/payment_method.dart';
import 'package:conviene/models/product.dart';
import 'package:conviene/repositories/mock_repository.dart';
import 'package:conviene/services/user_data_store.dart';
import 'package:conviene/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

      firstState.dispose();
      reloadedState.dispose();
    },
  );
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

  @override
  Future<List<SearchResult>> searchProducts({
    required String query,
    required Set<String> storeIds,
    ShoppingContext context = const ShoppingContext(),
  }) {
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
