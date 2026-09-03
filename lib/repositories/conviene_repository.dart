import '../models/discount.dart';
import '../models/price_quote.dart';
import '../models/product.dart';
import '../models/supermarket.dart';

abstract class ConvieneRepository {
  Future<List<Supermarket>> getSupermarkets();

  Future<List<Product>> getProducts();

  Future<List<SearchResult>> searchProducts({
    required String query,
    required Set<String> storeIds,
  });

  Future<List<ProductPrice>> getPricesForProduct(String productId);

  Future<List<Promotion>> getPromotions(DateTime date);
}
