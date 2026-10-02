import 'cart_item.dart';
import 'product.dart';
import 'supermarket.dart';

class StoreComparison {
  const StoreComparison({
    required this.supermarket,
    required this.items,
    required this.missingProducts,
    required this.totalOriginal,
    required this.totalDiscount,
    required this.totalFinal,
    this.missingStatus = const {},
  });

  final Supermarket supermarket;
  final List<PricedCartItem> items;
  final List<Product> missingProducts;
  final double totalOriginal;
  final double totalDiscount;
  final double totalFinal;
  final Map<String, String> missingStatus;

  bool get hasSourceError => missingStatus.values.contains('error');

  String missingLabel(Product product) => switch (missingStatus[product.id]) {
    'error' => 'No se pudo consultar',
    'unavailable' => 'Sin stock publicado',
    _ => 'No encontrado',
  };

  int get foundProductsCount => items.length;

  int get totalProductsCount => items.length + missingProducts.length;

  bool get hasAllProducts => missingProducts.isEmpty;
}

class MultiStoreComparison {
  const MultiStoreComparison({
    required this.items,
    required this.missingProducts,
    required this.totalOriginal,
    required this.totalDiscount,
    required this.totalFinal,
  });

  final List<PricedCartItem> items;
  final List<Product> missingProducts;
  final double totalOriginal;
  final double totalDiscount;
  final double totalFinal;

  int get foundProductsCount => items.length;

  int get totalProductsCount => items.length + missingProducts.length;

  int get storeCount => items.map((item) => item.supermarket.id).toSet().length;

  bool get hasAllProducts => missingProducts.isEmpty;
}

class CartComparisonResult {
  const CartComparisonResult({
    required this.singleStoreComparisons,
    required this.selectedStoresPlan,
    required this.bestPerProductPlan,
  });

  final List<StoreComparison> singleStoreComparisons;
  final MultiStoreComparison? selectedStoresPlan;
  final MultiStoreComparison? bestPerProductPlan;
}
