import '../models/cart_item.dart';

class CartService {
  const CartService();

  List<CartItem> addProduct(
    List<CartItem> items,
    String productId, {
    String? selectedStoreId,
  }) {
    final existingIndex = items.indexWhere(
      (item) =>
          item.productId == productId &&
          item.selectedStoreId == selectedStoreId,
    );
    if (existingIndex == -1) {
      return [
        ...items,
        CartItem(
          productId: productId,
          quantity: 1,
          selectedStoreId: selectedStoreId,
        ),
      ];
    }
    final updated = [...items];
    final existing = updated[existingIndex];
    updated[existingIndex] = existing.copyWith(quantity: existing.quantity + 1);
    return updated;
  }

  List<CartItem> updateQuantity(
    List<CartItem> items,
    String productId,
    int quantity,
    String? selectedStoreId,
  ) {
    if (quantity <= 0) {
      return removeProduct(items, productId, selectedStoreId);
    }
    return [
      for (final item in items)
        if (item.productId == productId &&
            item.selectedStoreId == selectedStoreId)
          item.copyWith(quantity: quantity)
        else
          item,
    ];
  }

  List<CartItem> removeProduct(
    List<CartItem> items,
    String productId,
    String? selectedStoreId,
  ) {
    return items
        .where(
          (item) =>
              item.productId != productId ||
              item.selectedStoreId != selectedStoreId,
        )
        .toList();
  }
}
