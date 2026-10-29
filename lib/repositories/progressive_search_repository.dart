import '../models/price_quote.dart';
import '../models/shopping_context.dart';

typedef SearchProgress =
    void Function(List<SearchResult> results, Set<String> pendingStoreIds);

abstract class ProgressiveSearchRepository {
  Future<List<SearchResult>> searchProductsProgressively({
    required String query,
    required Set<String> storeIds,
    required SearchProgress onProgress,
    ShoppingContext context = const ShoppingContext(),
  });
}
