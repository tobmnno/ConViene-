enum FulfillmentMode { pickup, delivery }

class ShoppingContext {
  const ShoppingContext({
    this.postalCode = '',
    this.fulfillment = FulfillmentMode.pickup,
    this.cotoStore = '200',
    this.carrefourSalesChannel = '1',
    this.latitude,
    this.longitude,
    this.locationAccuracyMeters,
  });

  final String postalCode;
  final FulfillmentMode fulfillment;
  final String cotoStore;
  final String carrefourSalesChannel;
  final double? latitude;
  final double? longitude;
  final double? locationAccuracyMeters;

  bool get hasDeviceLocation => latitude != null && longitude != null;

  ShoppingContext copyWith({
    String? postalCode,
    FulfillmentMode? fulfillment,
    String? cotoStore,
    String? carrefourSalesChannel,
    double? latitude,
    double? longitude,
    double? locationAccuracyMeters,
  }) {
    return ShoppingContext(
      postalCode: postalCode ?? this.postalCode,
      fulfillment: fulfillment ?? this.fulfillment,
      cotoStore: cotoStore ?? this.cotoStore,
      carrefourSalesChannel:
          carrefourSalesChannel ?? this.carrefourSalesChannel,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationAccuracyMeters:
          locationAccuracyMeters ?? this.locationAccuracyMeters,
    );
  }

  String get fulfillmentApiValue => switch (fulfillment) {
    FulfillmentMode.pickup => 'pickup',
    FulfillmentMode.delivery => 'delivery',
  };

  String get fulfillmentLabel => switch (fulfillment) {
    FulfillmentMode.pickup => 'Retiro en sucursal',
    FulfillmentMode.delivery => 'Envio a domicilio',
  };

  bool get hasPostalCode => RegExp(r'^\d{4}$').hasMatch(postalCode);
}
