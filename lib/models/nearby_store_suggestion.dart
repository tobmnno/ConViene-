class NearbyStoreSuggestion {
  const NearbyStoreSuggestion({
    required this.storeId,
    required this.name,
    required this.distanceKm,
  });

  final String storeId;
  final String name;
  final double distanceKm;
}
