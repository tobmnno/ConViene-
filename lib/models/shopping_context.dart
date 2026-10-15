enum FulfillmentMode { pickup, delivery }

class ShoppingContext {
  const ShoppingContext({
    this.postalCode = '',
    this.fulfillment = FulfillmentMode.pickup,
    this.cotoStore = '200',
    this.carrefourSalesChannel = '1',
    this.latitude,
    this.longitude,
  });

  final String postalCode;
  final FulfillmentMode fulfillment;
  final String cotoStore;
  final String carrefourSalesChannel;
  final double? latitude;
  final double? longitude;

  String get fulfillmentApiValue => switch (fulfillment) {
    FulfillmentMode.pickup => 'pickup',
    FulfillmentMode.delivery => 'delivery',
  };

  bool get hasPostalCode => RegExp(r'^\d{4}$').hasMatch(postalCode);
}
