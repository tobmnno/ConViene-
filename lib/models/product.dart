class Product {
  const Product({
    required this.id,
    required this.ean,
    required this.name,
    required this.brand,
    required this.presentation,
    required this.unit,
    required this.category,
    required this.imageTag,
    this.imageUrl = '',
  });

  final String id;
  final String ean;
  final String name;
  final String brand;
  final String presentation;
  final String unit;
  final String category;
  final String imageTag;
  final String imageUrl;
}
