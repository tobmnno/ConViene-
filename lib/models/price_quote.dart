import 'product.dart';
import 'supermarket.dart';

class ProductPrice {
  const ProductPrice({
    required this.storeId,
    required this.productId,
    required this.priceOriginal,
    required this.priceUnitario,
    required this.stock,
    required this.url,
    required this.fechaActualizacion,
  });

  final String storeId;
  final String productId;
  final double priceOriginal;
  final double priceUnitario;
  final bool stock;
  final String url;
  final DateTime fechaActualizacion;
}

class SearchResult {
  const SearchResult({
    required this.product,
    required this.price,
    required this.supermarket,
    this.relevanceScore = 0,
    this.isExactMatch = true,
  });

  final Product product;
  final ProductPrice price;
  final Supermarket supermarket;
  final double relevanceScore;
  final bool isExactMatch;
}
