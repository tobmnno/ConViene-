import '../models/cart_item.dart';
import '../models/discount.dart';
import '../state/app_state.dart';

class CartQuantitySuggestion {
  const CartQuantitySuggestion(this.key, this.promotion, this.one, this.two);
  final String key;
  final Promotion promotion;
  final DiscountQuote one;
  final DiscountQuote two;
  bool get samePrice => (one.precioFinal - two.precioFinal).abs() < .01;
}

CartQuantitySuggestion? quantitySuggestion(
  AppState state,
  PricedCartItem line,
) {
  if (state.isComparing || line.quantity != 1 || !line.price.stock) return null;
  final id = line.cartProductId ?? line.product.id;
  if (!state.cartItems.any(
    (item) =>
        item.productId == id &&
        item.selectedStoreId == line.supermarket.id &&
        item.quantity == 1,
  ))
    return null;
  final two = state.previewCartLine(line, 2);
  final p = two.promocionUsada;
  if (p == null ||
      p.promotionKind != 'store_product' ||
      p.mechanic != 'buy_n_pay_m' ||
      p.requiredQuantity != 2 ||
      p.chargedQuantity != 1 ||
      p.sourceType != 'official_api' ||
      p.fuenteUrl.isEmpty ||
      !p.appliesOn(DateTime.now()) ||
      !p.canCalculate)
    return null;
  final key = '$id|${line.supermarket.id}|${p.id}|1';
  if (state.dismissedQuantitySuggestions.contains(key)) return null;
  return CartQuantitySuggestion(key, p, state.previewCartLine(line, 1), two);
}
