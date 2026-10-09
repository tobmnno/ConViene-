import '../models/cart_item.dart';
import '../models/product.dart';
import '../models/supermarket.dart';

class CartShareService {
  const CartShareService();

  String buildText({
    required List<CartItem> items,
    required List<Product> products,
    required List<Supermarket> supermarkets,
  }) {
    final productsById = {for (final product in products) product.id: product};
    final storesById = {for (final store in supermarkets) store.id: store.name};
    final lines = <String>[];
    for (final item in items) {
      final product = productsById[item.productId];
      if (product == null) continue;
      final store = item.selectedStoreId == null
          ? 'supermercado por elegir'
          : storesById[item.selectedStoreId] ?? 'supermercado por elegir';
      lines.add('${item.quantity} x ${product.name} - $store');
    }
    return [
      'Mi changuito en Conviene',
      '',
      ...lines,
      '',
      'Consulta precio y stock antes de comprar: pueden cambiar segun sucursal y momento.',
    ].join('\n');
  }
}
