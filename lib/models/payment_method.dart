enum PaymentMethodType { card, bank, wallet }

extension PaymentMethodTypeLabel on PaymentMethodType {
  String get label {
    return switch (this) {
      PaymentMethodType.card => 'Tarjeta',
      PaymentMethodType.bank => 'Banco',
      PaymentMethodType.wallet => 'Billetera',
    };
  }

  String get pluralLabel {
    return switch (this) {
      PaymentMethodType.card => 'Tarjetas',
      PaymentMethodType.bank => 'Bancos',
      PaymentMethodType.wallet => 'Billeteras',
    };
  }
}

class PaymentMethod {
  const PaymentMethod({
    required this.id,
    required this.type,
    required this.entity,
    required this.displayName,
    required this.active,
    this.logoAsset = '',
  });

  final String id;
  final PaymentMethodType type;
  final String entity;
  final String displayName;
  final bool active;
  final String logoAsset;

  PaymentMethod copyWith({bool? active}) {
    return PaymentMethod(
      id: id,
      type: type,
      entity: entity,
      displayName: displayName,
      active: active ?? this.active,
      logoAsset: logoAsset,
    );
  }
}
