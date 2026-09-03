class Supermarket {
  const Supermarket({
    required this.id,
    required this.name,
    required this.shortName,
    required this.enabled,
    required this.brandColor,
    required this.websiteUrl,
    required this.logoAsset,
  });

  final String id;
  final String name;
  final String shortName;
  final bool enabled;
  final int brandColor;
  final String websiteUrl;
  final String logoAsset;
}
