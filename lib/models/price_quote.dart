import 'discount.dart';
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
    this.branchId,
    this.pricingScope,
    this.deliveryAvailable,
    this.hasStoreOffer = false,
    this.quantityOffers = const [],
  });

  final String storeId;
  final String productId;
  final double priceOriginal;
  final double priceUnitario;
  final bool stock;
  final String url;
  final DateTime fechaActualizacion;
  final String? branchId;
  final String? pricingScope;
  final bool? deliveryAvailable;
  final bool hasStoreOffer;
  final List<Promotion> quantityOffers;
}

class SearchResult {
  const SearchResult({
    required this.product,
    required this.price,
    required this.supermarket,
    this.relevanceScore = 0,
    this.isExactMatch = true,
    this.matchType = 'exact',
    this.communityPriceId,
    this.contributorId,
    this.contributorName,
    this.contributedAt,
  });

  final Product product;
  final ProductPrice price;
  final Supermarket supermarket;
  final double relevanceScore;
  final bool isExactMatch;
  final String matchType;
  final String? communityPriceId;
  final String? contributorId;
  final String? contributorName;
  final DateTime? contributedAt;

  bool get isCommunityPrice => communityPriceId != null;
}
