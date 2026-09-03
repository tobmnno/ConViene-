import '../models/payment_method.dart';

class PaymentMethodService {
  const PaymentMethodService();

  List<PaymentMethod> initialMethods() {
    return const [
      // Tarjetas
      PaymentMethod(
        id: 'visa',
        type: PaymentMethodType.card,
        entity: 'Visa',
        displayName: 'Visa',
        active: true,
        logoAsset: 'assets/logos/payment_visa.png',
      ),
      PaymentMethod(
        id: 'mastercard',
        type: PaymentMethodType.card,
        entity: 'Mastercard',
        displayName: 'Mastercard',
        active: true,
        logoAsset: 'assets/logos/payment_mastercard.png',
      ),
      PaymentMethod(
        id: 'amex',
        type: PaymentMethodType.card,
        entity: 'American Express',
        displayName: 'American Express',
        active: false,
        logoAsset: 'assets/logos/payment_amex.png',
      ),
      PaymentMethod(
        id: 'cabal',
        type: PaymentMethodType.card,
        entity: 'Cabal',
        displayName: 'Cabal',
        active: false,
        logoAsset: 'assets/logos/payment_cabal.jpg',
      ),
      PaymentMethod(
        id: 'maestro',
        type: PaymentMethodType.card,
        entity: 'Maestro',
        displayName: 'Maestro',
        active: false,
        logoAsset: 'assets/logos/payment_maestro.png',
      ),
      PaymentMethod(
        id: 'naranja_x',
        type: PaymentMethodType.card,
        entity: 'Naranja X',
        displayName: 'Naranja X',
        active: false,
        logoAsset: 'assets/logos/payment_naranja_x.png',
      ),
      PaymentMethod(
        id: 'tarjeta_carrefour_banco',
        type: PaymentMethodType.card,
        entity: 'Tarjeta Carrefour Banco',
        displayName: 'Mi Carrefour Mastercard',
        active: false,
        logoAsset: 'assets/logos/payment_mi_carrefour.png',
      ),

      // Bancos
      PaymentMethod(
        id: 'banco_nacion',
        type: PaymentMethodType.bank,
        entity: 'Banco Nacion',
        displayName: 'Banco Nacion',
        active: false,
        logoAsset: 'assets/logos/payment_banco_nacion.png',
      ),
      PaymentMethod(
        id: 'banco_galicia',
        type: PaymentMethodType.bank,
        entity: 'Banco Galicia',
        displayName: 'Banco Galicia',
        active: false,
        logoAsset: 'assets/logos/payment_galicia.png',
      ),
      PaymentMethod(
        id: 'banco_macro',
        type: PaymentMethodType.bank,
        entity: 'Banco Macro',
        displayName: 'Banco Macro',
        active: false,
        logoAsset: 'assets/logos/payment_banco_macro.png',
      ),
      PaymentMethod(
        id: 'banco_patagonia',
        type: PaymentMethodType.bank,
        entity: 'Banco Patagonia',
        displayName: 'Banco Patagonia',
        active: false,
        logoAsset: 'assets/logos/payment_banco_patagonia.png',
      ),
      PaymentMethod(
        id: 'carrefour_banco',
        type: PaymentMethodType.bank,
        entity: 'Carrefour Banco',
        displayName: 'Carrefour Banco',
        active: false,
        logoAsset: 'assets/logos/payment_mi_carrefour.png',
      ),
      PaymentMethod(
        id: 'banco_provincia',
        type: PaymentMethodType.bank,
        entity: 'Banco Provincia',
        displayName: 'Banco Provincia',
        active: false,
        logoAsset: 'assets/logos/payment_banco_provincia_iso.jpg',
      ),
      PaymentMethod(
        id: 'banco_ciudad',
        type: PaymentMethodType.bank,
        entity: 'Banco Ciudad',
        displayName: 'Banco Ciudad',
        active: false,
        logoAsset: 'assets/logos/payment_banco_ciudad.png',
      ),
      PaymentMethod(
        id: 'banco_santander',
        type: PaymentMethodType.bank,
        entity: 'Banco Santander',
        displayName: 'Santander',
        active: false,
        logoAsset: 'assets/logos/payment_banco_santander.png',
      ),
      PaymentMethod(
        id: 'bbva',
        type: PaymentMethodType.bank,
        entity: 'BBVA',
        displayName: 'BBVA',
        active: false,
        logoAsset: 'assets/logos/payment_bbva.png',
      ),
      PaymentMethod(
        id: 'icbc',
        type: PaymentMethodType.bank,
        entity: 'ICBC',
        displayName: 'ICBC',
        active: false,
        logoAsset: 'assets/logos/payment_icbc.png',
      ),
      PaymentMethod(
        id: 'banco_supervielle',
        type: PaymentMethodType.bank,
        entity: 'Banco Supervielle',
        displayName: 'Supervielle',
        active: false,
        logoAsset: 'assets/logos/payment_banco_supervielle.png',
      ),
      PaymentMethod(
        id: 'banco_credicoop',
        type: PaymentMethodType.bank,
        entity: 'Banco Credicoop',
        displayName: 'Credicoop',
        active: false,
        logoAsset: 'assets/logos/payment_banco_credicoop.png',
      ),
      PaymentMethod(
        id: 'banco_hipotecario',
        type: PaymentMethodType.bank,
        entity: 'Banco Hipotecario',
        displayName: 'Hipotecario',
        active: false,
        logoAsset: 'assets/logos/payment_banco_hipotecario.png',
      ),
      PaymentMethod(
        id: 'bancor',
        type: PaymentMethodType.bank,
        entity: 'Bancor',
        displayName: 'Bancor',
        active: false,
        logoAsset: 'assets/logos/payment_bancor.png',
      ),
      PaymentMethod(
        id: 'banco_santa_fe',
        type: PaymentMethodType.bank,
        entity: 'Banco Santa Fe',
        displayName: 'Banco Santa Fe',
        active: false,
        logoAsset: 'assets/logos/payment_banco_santa_fe.png',
      ),
      PaymentMethod(
        id: 'banco_san_juan',
        type: PaymentMethodType.bank,
        entity: 'Banco San Juan',
        displayName: 'Banco San Juan',
        active: false,
        logoAsset: 'assets/logos/payment_banco_san_juan.png',
      ),
      PaymentMethod(
        id: 'banco_santa_cruz',
        type: PaymentMethodType.bank,
        entity: 'Banco Santa Cruz',
        displayName: 'Banco Santa Cruz',
        active: false,
        logoAsset: 'assets/logos/payment_banco_santa_cruz.png',
      ),
      PaymentMethod(
        id: 'banco_entre_rios',
        type: PaymentMethodType.bank,
        entity: 'Banco Entre Rios',
        displayName: 'Banco Entre Rios',
        active: false,
        logoAsset: 'assets/logos/payment_banco_entre_rios.png',
      ),
      PaymentMethod(
        id: 'banco_chubut',
        type: PaymentMethodType.bank,
        entity: 'Banco Chubut',
        displayName: 'Banco Chubut',
        active: false,
        logoAsset: 'assets/logos/payment_banco_chubut.png',
      ),
      PaymentMethod(
        id: 'bica',
        type: PaymentMethodType.bank,
        entity: 'Bica',
        displayName: 'Bica',
        active: false,
        logoAsset: 'assets/logos/payment_bica.png',
      ),
      PaymentMethod(
        id: 'banco_comafi',
        type: PaymentMethodType.bank,
        entity: 'Banco Comafi',
        displayName: 'Comafi',
        active: false,
        logoAsset: 'assets/logos/payment_banco_comafi.png',
      ),
      PaymentMethod(
        id: 'banco_columbia',
        type: PaymentMethodType.bank,
        entity: 'Banco Columbia',
        displayName: 'Columbia',
        active: false,
        logoAsset: 'assets/logos/payment_banco_columbia.png',
      ),
      PaymentMethod(
        id: 'reba',
        type: PaymentMethodType.bank,
        entity: 'Reba',
        displayName: 'Reba',
        active: false,
        logoAsset: 'assets/logos/payment_reba.png',
      ),
      PaymentMethod(
        id: 'banco_corrientes',
        type: PaymentMethodType.bank,
        entity: 'Banco Corrientes',
        displayName: 'Banco Corrientes',
        active: false,
        logoAsset: 'assets/logos/payment_banco_corrientes.png',
      ),
      PaymentMethod(
        id: 'banco_neuquen',
        type: PaymentMethodType.bank,
        entity: 'Banco Neuquen',
        displayName: 'Banco Neuquen',
        active: false,
        logoAsset: 'assets/logos/payment_banco_neuquen.png',
      ),
      PaymentMethod(
        id: 'banco_piano',
        type: PaymentMethodType.bank,
        entity: 'Banco Piano',
        displayName: 'Banco Piano',
        active: false,
        logoAsset: 'assets/logos/payment_banco_piano.png',
      ),
      PaymentMethod(
        id: 'banco_saenz',
        type: PaymentMethodType.bank,
        entity: 'Banco Saenz',
        displayName: 'Banco Saenz',
        active: false,
        logoAsset: 'assets/logos/payment_banco_saenz.png',
      ),
      PaymentMethod(
        id: 'banco_mariva',
        type: PaymentMethodType.bank,
        entity: 'Banco Mariva',
        displayName: 'Banco Mariva',
        active: false,
        logoAsset: 'assets/logos/payment_banco_mariva.png',
      ),
      PaymentMethod(
        id: 'banco_cmf',
        type: PaymentMethodType.bank,
        entity: 'Banco CMF',
        displayName: 'Banco CMF',
        active: false,
        logoAsset: 'assets/logos/payment_banco_cmf.png',
      ),
      PaymentMethod(
        id: 'banco_yoy',
        type: PaymentMethodType.bank,
        entity: 'YOY',
        displayName: 'YOY',
        active: false,
        logoAsset: 'assets/logos/payment_banco_yoy.jpg',
      ),

      // Billeteras y programas de beneficios
      PaymentMethod(
        id: 'mercado_pago',
        type: PaymentMethodType.wallet,
        entity: 'Mercado Pago',
        displayName: 'Mercado Pago',
        active: true,
        logoAsset: 'assets/logos/payment_mercado_pago.png',
      ),
      PaymentMethod(
        id: 'uala',
        type: PaymentMethodType.wallet,
        entity: 'Uala',
        displayName: 'Uala',
        active: false,
        logoAsset: 'assets/logos/payment_uala.png',
      ),
      PaymentMethod(
        id: 'modo',
        type: PaymentMethodType.wallet,
        entity: 'MODO',
        displayName: 'MODO',
        active: false,
        logoAsset: 'assets/logos/payment_modo.png',
      ),
      PaymentMethod(
        id: 'cuenta_digital_carrefour',
        type: PaymentMethodType.wallet,
        entity: 'Cuenta Digital Carrefour Banco',
        displayName: 'Cuenta Digital Mi Carrefour',
        active: false,
        logoAsset: 'assets/logos/payment_mi_carrefour.png',
      ),
      PaymentMethod(
        id: 'club_la_nacion',
        type: PaymentMethodType.wallet,
        entity: 'Club La Nacion',
        displayName: 'Club La Nacion',
        active: false,
        logoAsset: 'assets/logos/payment_club_la_nacion.png',
      ),
      PaymentMethod(
        id: 'nave_galicia',
        type: PaymentMethodType.wallet,
        entity: 'Nave Galicia',
        displayName: 'Galicia Nave',
        active: false,
        logoAsset: 'assets/logos/payment_galicia.png',
      ),
      PaymentMethod(
        id: 'cuenta_dni',
        type: PaymentMethodType.wallet,
        entity: 'Cuenta DNI',
        displayName: 'Cuenta DNI',
        active: false,
        logoAsset: 'assets/logos/payment_cuenta_dni.png',
      ),
      PaymentMethod(
        id: 'empleado_publico',
        type: PaymentMethodType.wallet,
        entity: 'Empleado publico',
        displayName: 'Empleado publico',
        active: false,
        logoAsset: 'assets/logos/payment_empleado_publico.png',
      ),
    ];
  }

  List<PaymentMethod> toggle(List<PaymentMethod> methods, String methodId) {
    return [
      for (final method in methods)
        if (method.id == methodId)
          method.copyWith(active: !method.active)
        else
          method,
    ];
  }

  PaymentMethodAddResult addCustom({
    required List<PaymentMethod> methods,
    required PaymentMethodType type,
    required String displayName,
  }) {
    final cleanName = displayName.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleanName.isEmpty) {
      return PaymentMethodAddResult(methods: methods, added: false);
    }

    final normalizedName = _normalize(cleanName);
    final existingIndex = methods.indexWhere(
      (method) =>
          method.type == type &&
          (_normalize(method.entity) == normalizedName ||
              _normalize(method.displayName) == normalizedName),
    );

    if (existingIndex >= 0) {
      return PaymentMethodAddResult(
        methods: [
          for (var index = 0; index < methods.length; index += 1)
            if (index == existingIndex)
              methods[index].copyWith(active: true)
            else
              methods[index],
        ],
        added: false,
      );
    }

    final id = _uniqueId(methods, type, cleanName);
    return PaymentMethodAddResult(
      methods: [
        ...methods,
        PaymentMethod(
          id: id,
          type: type,
          entity: cleanName,
          displayName: cleanName,
          active: true,
          logoAsset: '',
        ),
      ],
      added: true,
    );
  }

  String _uniqueId(
    List<PaymentMethod> methods,
    PaymentMethodType type,
    String value,
  ) {
    final prefix = switch (type) {
      PaymentMethodType.card => 'tarjeta',
      PaymentMethodType.bank => 'banco',
      PaymentMethodType.wallet => 'billetera',
    };
    final usedIds = {for (final method in methods) method.id};
    final baseId = 'custom_${prefix}_${_slug(value)}';
    if (!usedIds.contains(baseId)) {
      return baseId;
    }

    var suffix = 2;
    while (usedIds.contains('${baseId}_$suffix')) {
      suffix += 1;
    }
    return '${baseId}_$suffix';
  }

  String _slug(String value) {
    final normalized = _normalize(value);
    final slug = normalized
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return slug.isEmpty ? 'medio' : slug;
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n')
        .trim();
  }
}

class PaymentMethodAddResult {
  const PaymentMethodAddResult({required this.methods, required this.added});

  final List<PaymentMethod> methods;
  final bool added;
}
