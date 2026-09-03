import 'discount.dart';
import 'price_quote.dart';
import 'product.dart';
import 'supermarket.dart';

class CartItem {
  const CartItem({
    required this.productId,
    required this.quantity,
    this.selectedStoreId,
  });

  final String productId;
  final int quantity;
  final String? selectedStoreId;

  CartItem copyWith({int? quantity, String? selectedStoreId}) {
    return CartItem(
      productId: productId,
      quantity: quantity ?? this.quantity,
      selectedStoreId: selectedStoreId ?? this.selectedStoreId,
    );
  }
}

class PricedCartItem {
  const PricedCartItem({
    required this.product,
    required this.supermarket,
    required this.quantity,
    required this.price,
    required this.discount,
    this.cartProductId,
  });

  final Product product;
  final Supermarket supermarket;
  final int quantity;
  final ProductPrice price;
  final DiscountQuote discount;
  final String? cartProductId;
}
