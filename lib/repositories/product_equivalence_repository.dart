import '../models/price_quote.dart';
import '../models/product.dart';
import '../models/shopping_context.dart';

class EquivalentProductsResult {
  const EquivalentProductsResult({
    required this.results,
    required this.storeStatus,
  });

  final List<SearchResult> results;
  final Map<String, String> storeStatus;
}

abstract interface class ProductEquivalenceRepository {
  Future<EquivalentProductsResult> findEquivalentProducts({
    required Product product,
    required Set<String> storeIds,
    required ShoppingContext context,
  });
}
