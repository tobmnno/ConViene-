class DeviceLocation {
  const DeviceLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
}

class DeviceLocationService {
  const DeviceLocationService();

  Future<DeviceLocation> locate() {
    throw UnsupportedError(
      'La ubicacion solo esta disponible en la version web.',
    );
  }
}
