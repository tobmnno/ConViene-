import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/cart_item.dart';
import '../models/payment_method.dart';
import '../models/product.dart';

abstract interface class UserDataStore {
  Future<SavedUserData?> load();

  Future<void> save(SavedUserData data);
}

abstract interface class StringPreferences {
  Future<String?> getString(String key);

  Future<void> setString(String key, String value);
}

class SharedPreferencesStringStore implements StringPreferences {
  SharedPreferencesStringStore([SharedPreferencesAsync? preferences])
    : _providedPreferences = preferences;

  final SharedPreferencesAsync? _providedPreferences;

  SharedPreferencesAsync get _preferences =>
      _providedPreferences ?? SharedPreferencesAsync();

  @override
  Future<String?> getString(String key) => _preferences.getString(key);

  @override
  Future<void> setString(String key, String value) =>
      _preferences.setString(key, value);
}

class LocalUserDataStore implements UserDataStore {
  LocalUserDataStore({StringPreferences? preferences})
    : _preferences = preferences ?? SharedPreferencesStringStore();

  static const _storageKey = 'conviene.user_data.v1';
  final StringPreferences _preferences;

  @override
  Future<SavedUserData?> load() async {
    final encoded = await _preferences.getString(_storageKey);
    if (encoded == null || encoded.isEmpty) return null;

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, dynamic> || decoded['version'] != 1) {
        return null;
      }

      final cart = <CartItem>[];
      final cartJson = decoded['cart'];
      if (cartJson is List) {
        for (final entry in cartJson.whereType<Map<String, dynamic>>()) {
          final id = entry['productId'];
          final quantity = entry['quantity'];
          final storeId = entry['selectedStoreId'];
          if (id is! String || id.isEmpty || quantity is! int || quantity < 1) {
            continue;
          }
          cart.add(
            CartItem(
              productId: id,
              quantity: quantity.clamp(1, 99).toInt(),
              selectedStoreId: storeId is String ? storeId : null,
            ),
          );
        }
      }

      final products = decoded['products'];
      final productSnapshots = products is List
          ? products.map(_productFromJson).whereType<Product>().toList()
          : const <Product>[];

      final activeIds = decoded['activePaymentMethodIds'];
      final favoriteIds = decoded['favoriteProductIds'];
      final customJson = decoded['customPaymentMethods'];
      return SavedUserData(
        cartItems: cart,
        productSnapshots: productSnapshots,
        favoriteProductIds: favoriteIds is List
            ? favoriteIds.whereType<String>().toSet()
            : const {},
        activePaymentMethodIds: activeIds is List
            ? activeIds.whereType<String>().toSet()
            : const {},
        customPaymentMethods: customJson is List
            ? customJson
                  .map(_paymentMethodFromJson)
                  .whereType<PaymentMethod>()
                  .toList()
            : const [],
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  @override
  Future<void> save(SavedUserData data) async {
    final payload = {
      'version': 1,
      'cart': [
        for (final item in data.cartItems)
          {
            'productId': item.productId,
            'quantity': item.quantity.clamp(1, 99).toInt(),
            'selectedStoreId': item.selectedStoreId,
          },
      ],
      'products': [
        for (final product in data.productSnapshots)
          {
            'id': product.id,
            'ean': product.ean,
            'name': product.name,
            'brand': product.brand,
            'presentation': product.presentation,
            'unit': product.unit,
            'category': product.category,
            'imageTag': product.imageTag,
            'imageUrl': product.imageUrl,
          },
      ],
      'favoriteProductIds': data.favoriteProductIds.toList(),
      'activePaymentMethodIds': data.activePaymentMethodIds.toList(),
      'customPaymentMethods': [
        for (final method in data.customPaymentMethods)
          {
            'id': method.id,
            'type': method.type.name,
            'entity': method.entity,
            'displayName': method.displayName,
            'active': method.active,
          },
      ],
    };
    await _preferences.setString(_storageKey, jsonEncode(payload));
  }

  PaymentMethod? _paymentMethodFromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final typeName = raw['type'];
    final entity = raw['entity'];
    final displayName = raw['displayName'];
    if (id is! String ||
        !id.startsWith('custom_') ||
        typeName is! String ||
        entity is! String ||
        displayName is! String) {
      return null;
    }
    final type = PaymentMethodType.values.where(
      (value) => value.name == typeName,
    );
    if (type.isEmpty) return null;
    return PaymentMethod(
      id: id,
      type: type.first,
      entity: entity,
      displayName: displayName,
      active: raw['active'] is bool ? raw['active'] as bool : true,
    );
  }

  Product? _productFromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final id = raw['id'];
    final name = raw['name'];
    if (id is! String || id.isEmpty || name is! String || name.isEmpty) {
      return null;
    }
    return Product(
      id: id,
      ean: raw['ean'] is String ? raw['ean'] as String : '',
      name: name,
      brand: raw['brand'] is String ? raw['brand'] as String : '',
      presentation: raw['presentation'] is String
          ? raw['presentation'] as String
          : '',
      unit: raw['unit'] is String ? raw['unit'] as String : '',
      category: raw['category'] is String ? raw['category'] as String : '',
      imageTag: raw['imageTag'] is String ? raw['imageTag'] as String : '',
      imageUrl: raw['imageUrl'] is String ? raw['imageUrl'] as String : '',
    );
  }
}

class SavedUserData {
  const SavedUserData({
    required this.cartItems,
    required this.productSnapshots,
    this.favoriteProductIds = const {},
    required this.activePaymentMethodIds,
    required this.customPaymentMethods,
  });

  final List<CartItem> cartItems;
  final List<Product> productSnapshots;
  final Set<String> favoriteProductIds;
  final Set<String> activePaymentMethodIds;
  final List<PaymentMethod> customPaymentMethods;
}
