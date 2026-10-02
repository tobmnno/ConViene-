// ignore_for_file: deprecated_member_use

import 'dart:html' as html;

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

  Future<DeviceLocation> locate() async {
    final position = await html.window.navigator.geolocation.getCurrentPosition(
      enableHighAccuracy: false,
      timeout: const Duration(seconds: 12),
      maximumAge: const Duration(minutes: 5),
    );
    final coordinates = position.coords;
    final latitude = coordinates?.latitude?.toDouble();
    final longitude = coordinates?.longitude?.toDouble();
    if (latitude == null || longitude == null) {
      throw StateError('No se pudo obtener una ubicacion valida.');
    }
    return DeviceLocation(
      latitude: latitude,
      longitude: longitude,
      accuracyMeters: coordinates?.accuracy?.toDouble() ?? 0,
    );
  }
}
