import 'package:conviene/models/cart_item.dart';
import 'package:conviene/models/product.dart';
import 'package:conviene/models/supermarket.dart';
import 'package:conviene/services/cart_share_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shares chosen store for each line and never invents a price', () {
    const product = Product(
      id: 'milk',
      ean: '',
      name: 'Leche entera 1 L',
      brand: '',
      presentation: '1 L',
      unit: 'L',
      category: '',
      imageTag: '',
    );
    const cola = Product(
      id: 'cola',
      ean: '',
      name: 'Gaseosa cola 2 L',
      brand: '',
      presentation: '2 L',
      unit: 'L',
      category: '',
      imageTag: '',
    );
    const store = Supermarket(
      id: 'coto',
      name: 'Coto',
      shortName: 'Coto',
      logoAsset: '',
      brandColor: 0,
      websiteUrl: '',
      enabled: true,
    );
    final text = const CartShareService().buildText(
      items: const [
        CartItem(productId: 'milk', quantity: 2, selectedStoreId: 'coto'),
        CartItem(productId: 'cola', quantity: 1, selectedStoreId: 'gallega'),
      ],
      products: const [product, cola],
      supermarkets: const [
        store,
        Supermarket(
          id: 'gallega',
          name: 'La Gallega',
          shortName: 'La Gallega',
          logoAsset: '',
          brandColor: 0,
          websiteUrl: '',
          enabled: true,
        ),
      ],
    );
    expect(text, contains('2 x Leche entera 1 L - Coto'));
    expect(text, contains('1 x Gaseosa cola 2 L - La Gallega'));
    expect(text, contains('precio y stock'));
    expect(text, isNot(contains(r'$')));
  });
}
