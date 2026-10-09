import 'package:conviene/models/cart_item.dart';
import 'package:conviene/models/payment_method.dart';
import 'package:conviene/models/product.dart';
import 'package:conviene/services/user_data_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('serializes shopping choices without card or price details', () async {
    final preferences = _MemoryStringPreferences();
    final store = LocalUserDataStore(preferences: preferences);
    await store.save(
      const SavedUserData(
        cartItems: [
          CartItem(productId: 'milk-1', quantity: 2, selectedStoreId: 'coto'),
        ],
        productSnapshots: [
          Product(
            id: 'milk-1',
            ean: '12345678',
            name: 'Leche entera 1L',
            brand: 'Marca',
            presentation: '1 L',
            unit: 'L',
            category: 'Leches',
            imageTag: '',
            imageUrl: 'https://example.test/milk.jpg',
          ),
        ],
        activePaymentMethodIds: {'visa'},
        favoriteProductIds: {'milk-1'},
        customPaymentMethods: [
          PaymentMethod(
            id: 'custom_wallet_prueba',
            type: PaymentMethodType.wallet,
            entity: 'Billetera prueba',
            displayName: 'Billetera prueba',
            active: true,
          ),
        ],
      ),
    );

    final restored = await store.load();
    expect(restored?.cartItems.single.productId, 'milk-1');
    expect(restored?.cartItems.single.quantity, 2);
    expect(restored?.productSnapshots.single.name, 'Leche entera 1L');
    expect(restored?.activePaymentMethodIds, {'visa'});
    expect(restored?.favoriteProductIds, {'milk-1'});
    expect(
      restored?.customPaymentMethods.single.displayName,
      'Billetera prueba',
    );
    expect(preferences.value, isNot(contains('price')));
    expect(preferences.value, isNot(contains('number')));
  });

  test(
    'ignores malformed saved data rather than failing app startup',
    () async {
      final store = LocalUserDataStore(
        preferences: _MemoryStringPreferences('{bad json'),
      );

      expect(await store.load(), isNull);
    },
  );

  test('loads older saved data without favorites', () async {
    final store = LocalUserDataStore(
      preferences: _MemoryStringPreferences(
        '{"version":1,"cart":[],"products":[],"activePaymentMethodIds":[],"customPaymentMethods":[]}',
      ),
    );
    expect((await store.load())?.favoriteProductIds, isEmpty);
  });
}

class _MemoryStringPreferences implements StringPreferences {
  _MemoryStringPreferences([this.value]);

  String? value;

  @override
  Future<String?> getString(String key) async => value;

  @override
  Future<void> setString(String key, String value) async {
    this.value = value;
  }
}
