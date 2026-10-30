import 'package:conviene/models/discount.dart';
import 'package:conviene/models/payment_method.dart';
import 'package:conviene/models/product.dart';
import 'package:conviene/services/discount_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = DiscountEngine();
  const product = Product(
    id: 'leche',
    ean: '1',
    name: 'Leche entera',
    brand: 'Ilolay',
    presentation: '1 L',
    unit: 'L',
    category: 'lacteos',
    imageTag: 'milk',
  );
  final date = DateTime(2026, 8, 20);
  final promotion = Promotion(
    id: 'coto_visa_20',
    storeId: 'coto',
    tipoMedioPago: PaymentMethodType.card,
    entidad: 'Visa',
    porcentajeDescuento: 20,
    topeReintegro: 5000,
    diasSemana: const {DateTime.thursday},
    fechaInicio: DateTime(2026, 1, 1),
    fechaFin: DateTime(2026, 12, 31),
    condiciones: 'En un pago',
    categorias: const ['lacteos'],
    applicabilityScope: 'general_confirmed',
  );
  const visa = PaymentMethod(
    id: 'visa',
    type: PaymentMethodType.card,
    entity: 'Visa',
    displayName: 'Visa',
    active: true,
  );

  test('solo un alcance general confirmado afecta el total', () {
    DiscountQuote calculate(String scope) => engine.calcularPrecioFinal(
      product: product,
      supermercado: 'coto',
      precioOriginal: 1000,
      fecha: date,
      mediosPagoUsuario: const [visa],
      promociones: [
        Promotion(
          id: 'scope',
          storeId: 'coto',
          tipoMedioPago: PaymentMethodType.card,
          entidad: 'Visa',
          porcentajeDescuento: 20,
          topeReintegro: 0,
          diasSemana: const {DateTime.thursday},
          fechaInicio: DateTime(2026, 1, 1),
          fechaFin: DateTime(2026, 12, 31),
          condiciones: '',
          categorias: const ['todos'],
          applicabilityScope: scope,
        ),
      ],
    );
    expect(calculate('restricted').precioFinal, 1000);
    expect(calculate('unknown').precioFinal, 1000);
    expect(calculate('general_confirmed').precioFinal, 800);
  });

  test('evidencia antigua o feed externo no calculan ahorro', () {
    final today = DateTime.now();
    Promotion offer(String source, DateTime captured) => Promotion(
      id: source,
      storeId: 'coto',
      tipoMedioPago: PaymentMethodType.card,
      entidad: 'Visa',
      porcentajeDescuento: 20,
      topeReintegro: 0,
      diasSemana: {today.weekday},
      fechaInicio: today,
      fechaFin: today,
      condiciones: '',
      categorias: const ['todos'],
      applicabilityScope: 'general_confirmed',
      sourceType: source,
      capturedAt: captured,
    );
    DiscountQuote quote(Promotion promotion) => engine.calcularPrecioFinal(
      product: product,
      supermercado: 'coto',
      precioOriginal: 1000,
      fecha: today,
      mediosPagoUsuario: const [visa],
      promociones: [promotion],
    );
    expect(
      quote(
        offer('official_api', today.subtract(const Duration(days: 2))),
      ).precioFinal,
      1000,
    );
    expect(quote(offer('third_party_feed', today)).precioFinal, 1000);
    expect(quote(offer('official_api', today)).precioFinal, 800);
  });

  test('calcula precio final con descuento compatible', () {
    final quote = engine.calcularPrecioFinal(
      product: product,
      supermercado: 'coto',
      precioOriginal: 1599,
      fecha: date,
      mediosPagoUsuario: const [visa],
      promociones: [promotion],
    );

    expect(quote.descuentoAplicado, isTrue);
    expect(quote.porcentaje, 20);
    expect(quote.importeDescuento, closeTo(319.8, 0.001));
    expect(quote.precioFinal, closeTo(1279.2, 0.001));
    expect(quote.promocionUsada?.id, 'coto_visa_20');
  });

  test('mantiene precio original sin medios activos', () {
    final quote = engine.calcularPrecioFinal(
      product: product,
      supermercado: 'coto',
      precioOriginal: 1599,
      fecha: date,
      mediosPagoUsuario: const [],
      promociones: [promotion],
    );

    expect(quote.descuentoAplicado, isFalse);
    expect(quote.precioFinal, 1599);
  });

  test('respeta tope de reintegro', () {
    final cappedPromotion = Promotion(
      id: 'coto_visa_20_cap',
      storeId: 'coto',
      tipoMedioPago: PaymentMethodType.card,
      entidad: 'Visa',
      porcentajeDescuento: 20,
      topeReintegro: 100,
      diasSemana: const {DateTime.thursday},
      fechaInicio: DateTime(2026, 1, 1),
      fechaFin: DateTime(2026, 12, 31),
      condiciones: 'En un pago',
      categorias: const ['lacteos'],
      applicabilityScope: 'general_confirmed',
    );

    final quote = engine.calcularPrecioFinal(
      product: product,
      supermercado: 'coto',
      precioOriginal: 1599,
      fecha: date,
      mediosPagoUsuario: const [visa],
      promociones: [cappedPromotion],
    );

    expect(quote.rawDiscount, closeTo(319.8, 0.001));
    expect(quote.importeDescuento, 100);
    expect(quote.precioFinal, 1499);
  });

  test('elige el mayor descuento efectivo despues de aplicar topes', () {
    final capped = Promotion(
      id: 'visa_40_cap',
      storeId: 'coto',
      tipoMedioPago: PaymentMethodType.card,
      entidad: 'Visa',
      porcentajeDescuento: 40,
      topeReintegro: 100,
      diasSemana: const {DateTime.thursday},
      fechaInicio: DateTime(2026, 1, 1),
      fechaFin: DateTime(2026, 12, 31),
      condiciones: 'Con tope',
      categorias: const ['todos'],
      applicabilityScope: 'general_confirmed',
    );
    final uncapped = Promotion(
      id: 'visa_15_sin_tope',
      storeId: 'coto',
      tipoMedioPago: PaymentMethodType.card,
      entidad: 'Visa',
      porcentajeDescuento: 15,
      topeReintegro: 0,
      diasSemana: const {DateTime.thursday},
      fechaInicio: DateTime(2026, 1, 1),
      fechaFin: DateTime(2026, 12, 31),
      condiciones: 'Sin tope',
      categorias: const ['todos'],
      applicabilityScope: 'general_confirmed',
    );

    final quote = engine.calcularPrecioFinal(
      product: product,
      supermercado: 'coto',
      precioOriginal: 1000,
      fecha: date,
      mediosPagoUsuario: const [visa],
      promociones: [capped, uncapped],
    );

    expect(quote.promocionUsada?.id, 'visa_15_sin_tope');
    expect(quote.importeDescuento, 150);
    expect(quote.precioFinal, 850);
  });

  test('aplica descuentos sin tope', () {
    final uncappedPromotion = Promotion(
      id: 'coto_visa_10_sin_tope',
      storeId: 'coto',
      tipoMedioPago: PaymentMethodType.card,
      entidad: 'Visa',
      porcentajeDescuento: 10,
      topeReintegro: 0,
      diasSemana: const {DateTime.thursday},
      fechaInicio: DateTime(2026, 1, 1),
      fechaFin: DateTime(2026, 12, 31),
      condiciones: 'Sin tope',
      categorias: const ['lacteos'],
      applicabilityScope: 'general_confirmed',
    );

    final quote = engine.calcularPrecioFinal(
      product: product,
      supermercado: 'coto',
      precioOriginal: 1599,
      fecha: date,
      mediosPagoUsuario: const [visa],
      promociones: [uncappedPromotion],
    );

    expect(quote.importeDescuento, closeTo(159.9, 0.001));
    expect(quote.precioFinal, closeTo(1439.1, 0.001));
  });

  test('no aplica una promocion si no alcanza la compra minima', () {
    final minimumPromotion = Promotion(
      id: 'carrefour_mercado_pago_minimo',
      storeId: 'carrefour',
      tipoMedioPago: PaymentMethodType.card,
      entidad: 'Visa',
      porcentajeDescuento: 15,
      topeReintegro: 15000,
      compraMinima: 20000,
      diasSemana: const {DateTime.thursday},
      fechaInicio: DateTime(2026, 1, 1),
      fechaFin: DateTime(2026, 12, 31),
      condiciones: 'Compra minima de 20000',
      categorias: const ['lacteos'],
      applicabilityScope: 'general_confirmed',
    );

    final quote = engine.calcularPrecioFinal(
      product: product,
      supermercado: 'carrefour',
      precioOriginal: 1599,
      fecha: date,
      mediosPagoUsuario: const [visa],
      promociones: [minimumPromotion],
    );

    expect(quote.descuentoAplicado, isFalse);
    expect(quote.precioFinal, 1599);
  });

  test('reconoce promociones compatibles con mas de un tipo de medio', () {
    final mixedPromotion = Promotion(
      id: 'lagallega_debito_saldo',
      storeId: 'lagallega',
      tipoMedioPago: PaymentMethodType.card,
      entidad: 'Visa, debito y saldo',
      porcentajeDescuento: 20,
      topeReintegro: 10000,
      diasSemana: const {DateTime.thursday},
      fechaInicio: DateTime(2026, 1, 1),
      fechaFin: DateTime(2026, 12, 31),
      condiciones: 'Saldo en cuenta o debito asociado',
      categorias: const ['lacteos'],
      applicabilityScope: 'general_confirmed',
      entidadesCompatibles: const {'Visa', 'Saldo en cuenta'},
      tiposMedioPagoCompatibles: const {
        PaymentMethodType.card,
        PaymentMethodType.wallet,
      },
    );
    const saldo = PaymentMethod(
      id: 'saldo_en_cuenta',
      type: PaymentMethodType.wallet,
      entity: 'Saldo en cuenta',
      displayName: 'Saldo en cuenta',
      active: true,
    );

    final quote = engine.calcularPrecioFinal(
      product: product,
      supermercado: 'lagallega',
      precioOriginal: 1599,
      fecha: date,
      mediosPagoUsuario: const [saldo],
      promociones: [mixedPromotion],
    );

    expect(quote.descuentoAplicado, isTrue);
    expect(quote.medioPago?.entity, 'Saldo en cuenta');
  });

  test('exige todos los grupos de medios de una promocion combinada', () {
    final combinedPromotion = Promotion(
      id: 'lagallega_modo_credicoop',
      storeId: 'lagallega',
      tipoMedioPago: PaymentMethodType.wallet,
      entidad: 'MODO',
      porcentajeDescuento: 30,
      topeReintegro: 9000,
      diasSemana: const {DateTime.thursday},
      fechaInicio: DateTime(2026, 1, 1),
      fechaFin: DateTime(2026, 12, 31),
      condiciones: 'MODO con Banco Credicoop',
      categorias: const ['lacteos'],
      applicabilityScope: 'general_confirmed',
      entidadesCompatibles: const {'MODO', 'Banco Credicoop'},
      entidadesRequeridas: const [
        {'MODO'},
        {'Banco Credicoop'},
      ],
      tiposMedioPagoCompatibles: const {
        PaymentMethodType.wallet,
        PaymentMethodType.bank,
      },
    );
    const modo = PaymentMethod(
      id: 'modo',
      type: PaymentMethodType.wallet,
      entity: 'MODO',
      displayName: 'MODO',
      active: true,
    );
    const credicoop = PaymentMethod(
      id: 'credicoop',
      type: PaymentMethodType.bank,
      entity: 'Banco Credicoop',
      displayName: 'Credicoop',
      active: true,
    );

    final incomplete = engine.calcularPrecioFinal(
      product: product,
      supermercado: 'lagallega',
      precioOriginal: 1599,
      fecha: date,
      mediosPagoUsuario: const [modo],
      promociones: [combinedPromotion],
    );
    final complete = engine.calcularPrecioFinal(
      product: product,
      supermercado: 'lagallega',
      precioOriginal: 1599,
      fecha: date,
      mediosPagoUsuario: const [modo, credicoop],
      promociones: [combinedPromotion],
    );

    expect(incomplete.descuentoAplicado, isFalse);
    expect(complete.descuentoAplicado, isTrue);
  });

  test('Visa de Comafi requiere la tarjeta y el banco correcto', () {
    final promotion = Promotion(
      id: 'coto_comafi',
      storeId: 'coto',
      tipoMedioPago: PaymentMethodType.card,
      entidad: 'Visa y Banco Comafi',
      porcentajeDescuento: 35,
      topeReintegro: 15000,
      diasSemana: const {DateTime.thursday},
      fechaInicio: DateTime(2026, 1, 1),
      fechaFin: DateTime(2026, 12, 31),
      condiciones: 'Visa de Banco Comafi',
      categorias: const ['todos'],
      applicabilityScope: 'general_confirmed',
      entidadesCompatibles: const {'Visa', 'Banco Comafi'},
      entidadesRequeridas: const [
        {'Visa'},
        {'Banco Comafi'},
      ],
      tiposMedioPagoCompatibles: const {
        PaymentMethodType.card,
        PaymentMethodType.bank,
      },
    );
    const galicia = PaymentMethod(
      id: 'galicia',
      type: PaymentMethodType.bank,
      entity: 'Banco Galicia',
      displayName: 'Banco Galicia',
      active: true,
    );
    const comafi = PaymentMethod(
      id: 'comafi',
      type: PaymentMethodType.bank,
      entity: 'Banco Comafi',
      displayName: 'Banco Comafi',
      active: true,
    );
    const mislabeledVisa = PaymentMethod(
      id: 'visa_wallet',
      type: PaymentMethodType.wallet,
      entity: 'Visa',
      displayName: 'Visa',
      active: true,
    );

    expect(promotion.isCompatibleWithAny(const [visa, galicia]), isFalse);
    expect(promotion.isCompatibleWithAny(const [comafi]), isFalse);
    expect(
      promotion.isCompatibleWithAny(const [mislabeledVisa, comafi]),
      isFalse,
    );
    expect(promotion.isCompatibleWithAny(const [visa, comafi]), isTrue);
  });

  test('Visa y Mastercard son alternativas cuando ambas sirven', () {
    final promotion = Promotion(
      id: 'coto_marcas',
      storeId: 'coto',
      tipoMedioPago: PaymentMethodType.card,
      entidad: 'Visa y Mastercard',
      porcentajeDescuento: 20,
      topeReintegro: 0,
      diasSemana: const {DateTime.thursday},
      fechaInicio: DateTime(2026, 1, 1),
      fechaFin: DateTime(2026, 12, 31),
      condiciones: 'Visa o Mastercard',
      categorias: const ['todos'],
      applicabilityScope: 'general_confirmed',
      entidadesCompatibles: const {'Visa', 'Mastercard'},
    );
    const mastercard = PaymentMethod(
      id: 'mastercard',
      type: PaymentMethodType.card,
      entity: 'Mastercard',
      displayName: 'Mastercard',
      active: true,
    );

    expect(promotion.isCompatibleWithAny(const [mastercard]), isTrue);
  });

  test('no toma entidades vacias como comodin', () {
    final carrefourCardPromotion = Promotion(
      id: 'carrefour_banco_card',
      storeId: 'carrefour',
      tipoMedioPago: PaymentMethodType.card,
      entidad: 'Tarjeta Carrefour Banco',
      porcentajeDescuento: 15,
      topeReintegro: 0,
      diasSemana: const {DateTime.thursday},
      fechaInicio: DateTime(2026, 1, 1),
      fechaFin: DateTime(2026, 12, 31),
      condiciones: 'Solo tarjeta Carrefour Banco',
      categorias: const ['lacteos'],
      applicabilityScope: 'general_confirmed',
    );

    final quote = engine.calcularPrecioFinal(
      product: product,
      supermercado: 'carrefour',
      precioOriginal: 1599,
      fecha: date,
      mediosPagoUsuario: const [visa],
      promociones: [carrefourCardPromotion],
    );

    expect(quote.descuentoAplicado, isFalse);
  });

  test('no aplica respaldos sin verificar ni promociones vencidas', () {
    final unverified = Promotion(
      id: 'respaldo',
      storeId: 'coto',
      tipoMedioPago: PaymentMethodType.card,
      entidad: 'Visa',
      porcentajeDescuento: 90,
      topeReintegro: 0,
      diasSemana: const {DateTime.thursday},
      fechaInicio: DateTime(2026, 1, 1),
      fechaFin: DateTime(2026, 12, 31),
      condiciones: '',
      categorias: const ['todos'],
      applicabilityScope: 'general_confirmed',
      calculationStatus: 'not_calculable',
    );
    final expired = Promotion(
      id: 'vencida',
      storeId: 'coto',
      tipoMedioPago: PaymentMethodType.card,
      entidad: 'Visa',
      porcentajeDescuento: 90,
      topeReintegro: 0,
      diasSemana: const {DateTime.thursday},
      fechaInicio: DateTime(2026, 1, 1),
      fechaFin: DateTime(2026, 7, 31),
      condiciones: '',
      categorias: const ['todos'],
      applicabilityScope: 'general_confirmed',
    );
    final quote = engine.calcularPrecioFinal(
      product: product,
      supermercado: 'coto',
      precioOriginal: 1000,
      fecha: date,
      mediosPagoUsuario: const [visa],
      promociones: [unverified, expired],
    );
    expect(quote.descuentoAplicado, isFalse);
  });

  test('compra minima se evalua sobre el subtotal indicado', () {
    final minimum = Promotion(
      id: 'minimo',
      storeId: 'coto',
      tipoMedioPago: PaymentMethodType.card,
      entidad: 'Visa',
      porcentajeDescuento: 20,
      topeReintegro: 0,
      compraMinima: 3000,
      diasSemana: const {DateTime.thursday},
      fechaInicio: DateTime(2026, 1, 1),
      fechaFin: DateTime(2026, 12, 31),
      condiciones: '',
      categorias: const ['todos'],
      applicabilityScope: 'general_confirmed',
    );
    final quote = engine.calcularPrecioFinal(
      product: product,
      supermercado: 'coto',
      precioOriginal: 1000,
      purchaseTotal: 4000,
      fecha: date,
      mediosPagoUsuario: const [visa],
      promociones: [minimum],
    );
    expect(quote.importeDescuento, 200);
  });

  test('no acumula por defecto con un precio de oferta existente', () {
    final quote = engine.calcularPrecioFinal(
      product: product,
      supermercado: 'coto',
      precioOriginal: 1000,
      fecha: date,
      mediosPagoUsuario: const [visa],
      promociones: [promotion],
      hasStoreOffer: true,
    );
    expect(quote.descuentoAplicado, isFalse);
  });

  test('un reintegro informado por la fuente se marca como estimado', () {
    final estimated = Promotion(
      id: 'estimado',
      storeId: 'coto',
      tipoMedioPago: PaymentMethodType.card,
      entidad: 'Visa',
      porcentajeDescuento: 20,
      topeReintegro: 100,
      diasSemana: const {DateTime.thursday},
      fechaInicio: DateTime(2026, 1, 1),
      fechaFin: DateTime(2026, 12, 31),
      condiciones: 'Tope mensual sujeto a consumos anteriores',
      categorias: const ['todos'],
      applicabilityScope: 'general_confirmed',
      calculationStatus: 'estimate',
      capFrequency: 'monthly',
    );
    final quote = engine.calcularPrecioFinal(
      product: product,
      supermercado: 'coto',
      precioOriginal: 1000,
      fecha: date,
      mediosPagoUsuario: const [visa],
      promociones: [estimated],
    );
    expect(quote.importeDescuento, 100);
    expect(quote.estimated, isTrue);
  });

  test('2x1 por EAN de una sucursal no descuenta sin sucursal confirmada', () {
    final today = DateTime.now();
    final offer = Promotion(
      id: 'coto-200-1-2x1',
      storeId: 'coto',
      tipoMedioPago: PaymentMethodType.card,
      entidad: 'Coto',
      porcentajeDescuento: 0,
      topeReintegro: 0,
      diasSemana: {today.weekday},
      fechaInicio: today,
      fechaFin: today,
      condiciones: 'Llevando 2',
      categorias: const ['todos'],
      applicabilityScope: 'restricted',
      promotionKind: 'store_product',
      mechanic: 'buy_n_pay_m',
      productEans: const {'1'},
      branchIds: const {'200'},
      requiredQuantity: 2,
      chargedQuantity: 1,
      sourceType: 'official_api',
      verificationStatus: 'source_reported',
      calculationStatus: 'estimate',
      capturedAt: DateTime.now(),
    );
    DiscountQuote quote(int quantity, String branch) =>
        engine.calcularPrecioFinal(
          product: product,
          supermercado: 'coto',
          precioOriginal: quantity * 1980,
          fecha: today,
          mediosPagoUsuario: const [],
          promociones: [offer],
          quantity: quantity,
          branchId: branch,
        );
    expect(quote(1, '200').precioFinal, 1980);
    expect(quote(2, '200').precioFinal, 3960);
    expect(quote(3, '200').precioFinal, 5940);
    expect(quote(2, '201').precioFinal, 3960);
    expect(quote(2, '200').descuentoAplicado, isFalse);
  });

  test('tope mensual consumido reduce el reintegro y puede agotarlo', () {
    final monthly = Promotion(
      id: 'monthly',
      storeId: 'coto',
      tipoMedioPago: PaymentMethodType.card,
      entidad: 'Visa',
      porcentajeDescuento: 20,
      topeReintegro: 100,
      diasSemana: const {DateTime.thursday},
      fechaInicio: DateTime(2026),
      fechaFin: DateTime(2026, 12, 31),
      condiciones: '',
      categorias: const ['todos'],
      applicabilityScope: 'general_confirmed',
      capFrequency: 'monthly',
    );
    final key = monthly.capUsageKey(date)!;
    DiscountQuote quote(double used) => engine.calcularPrecioFinal(
      product: product,
      supermercado: 'coto',
      precioOriginal: 1000,
      fecha: date,
      mediosPagoUsuario: const [visa],
      promociones: [monthly],
      usedRefundCaps: {key: used},
    );
    expect(quote(60).importeDescuento, 40);
    expect(quote(100).descuentoAplicado, isFalse);
    expect(monthly.capUsageKey(DateTime(2026, 9, 1)), isNot(key));
    final accountA = Promotion(
      id: 'account',
      storeId: 'coto',
      tipoMedioPago: PaymentMethodType.card,
      entidad: 'Visa',
      porcentajeDescuento: 20,
      topeReintegro: 100,
      diasSemana: const {DateTime.thursday},
      fechaInicio: DateTime(2026, 1),
      fechaFin: DateTime(2026, 6, 30),
      condiciones: '',
      categorias: const ['todos'],
      applicabilityScope: 'general_confirmed',
      capFrequency: 'account',
    );
    final accountB = Promotion(
      id: 'account',
      storeId: 'coto',
      tipoMedioPago: PaymentMethodType.card,
      entidad: 'Visa',
      porcentajeDescuento: 20,
      topeReintegro: 100,
      diasSemana: const {DateTime.thursday},
      fechaInicio: DateTime(2026, 7),
      fechaFin: DateTime(2026, 12, 31),
      condiciones: '',
      categorias: const ['todos'],
      applicabilityScope: 'general_confirmed',
      capFrequency: 'account',
    );
    expect(accountA.capUsageKey(date), isNot(accountB.capUsageKey(date)));
  });

  test('no aplica un beneficio fuera de las sucursales adheridas', () {
    final restricted = Promotion(
      id: 'sucursal',
      storeId: 'coto',
      tipoMedioPago: PaymentMethodType.card,
      entidad: 'Visa',
      porcentajeDescuento: 20,
      topeReintegro: 0,
      diasSemana: const {DateTime.thursday},
      fechaInicio: DateTime(2026, 1, 1),
      fechaFin: DateTime(2026, 12, 31),
      condiciones: '',
      categorias: const ['todos'],
      applicabilityScope: 'restricted',
      branchIds: const {'200'},
    );
    DiscountQuote quote(String? branch) => engine.calcularPrecioFinal(
      product: product,
      supermercado: 'coto',
      precioOriginal: 1000,
      fecha: date,
      mediosPagoUsuario: const [visa],
      promociones: [restricted],
      branchId: branch,
    );
    expect(quote(null).descuentoAplicado, isFalse);
    expect(quote('201').descuentoAplicado, isFalse);
    expect(quote('200').importeDescuento, 0);
  });

  test('calcula 2x1, 3x2 y segunda unidad solo para el EAN alcanzado', () {
    Promotion quantityPromo(
      String mechanic,
      int required,
      int charged, {
      double secondDiscount = 0,
    }) => Promotion(
      id: mechanic,
      storeId: 'coto',
      tipoMedioPago: PaymentMethodType.card,
      entidad: '',
      porcentajeDescuento: 0,
      topeReintegro: 0,
      diasSemana: const {DateTime.thursday},
      fechaInicio: DateTime(2026, 1, 1),
      fechaFin: DateTime(2026, 12, 31),
      condiciones: '',
      categorias: const ['todos'],
      applicabilityScope: 'general_confirmed',
      promotionKind: 'store_product',
      mechanic: mechanic,
      productEans: const {'1'},
      requiredQuantity: required,
      chargedQuantity: charged,
      secondUnitDiscount: secondDiscount,
    );
    DiscountQuote quote(Promotion promo, int quantity) =>
        engine.calcularPrecioFinal(
          product: product,
          supermercado: 'coto',
          precioOriginal: quantity * 1000,
          quantity: quantity,
          fecha: date,
          mediosPagoUsuario: const [],
          promociones: [promo],
        );
    expect(quote(quantityPromo('buy_n_pay_m', 2, 1), 5).precioFinal, 3000);
    expect(quote(quantityPromo('buy_n_pay_m', 3, 2), 7).precioFinal, 5000);
    expect(
      quote(
        quantityPromo('second_unit_discount', 2, 1, secondDiscount: 50),
        3,
      ).precioFinal,
      2500,
    );
    final bundle = Promotion(
      id: 'pack',
      storeId: 'coto',
      tipoMedioPago: PaymentMethodType.card,
      entidad: '',
      porcentajeDescuento: 0,
      topeReintegro: 0,
      diasSemana: const {DateTime.thursday},
      fechaInicio: DateTime(2026, 1, 1),
      fechaFin: DateTime(2026, 12, 31),
      condiciones: '',
      categorias: const ['todos'],
      applicabilityScope: 'general_confirmed',
      promotionKind: 'store_product',
      mechanic: 'fixed_bundle_price',
      productEans: const {'1'},
      requiredQuantity: 3,
      bundlePrice: 2500,
    );
    expect(quote(bundle, 4).precioFinal, 3500);
    expect(
      quote(quantityPromo('buy_n_pay_m', 2, 1), 1).descuentoAplicado,
      isFalse,
    );
    final other = Product(
      id: 'other',
      ean: '2',
      name: product.name,
      brand: product.brand,
      presentation: product.presentation,
      unit: product.unit,
      category: product.category,
      imageTag: product.imageTag,
    );
    expect(
      engine
          .calcularPrecioFinal(
            product: other,
            supermercado: 'coto',
            precioOriginal: 2000,
            quantity: 2,
            fecha: date,
            mediosPagoUsuario: const [],
            promociones: [quantityPromo('buy_n_pay_m', 2, 1)],
          )
          .descuentoAplicado,
      isFalse,
    );
  });

  test(
    'oferta Carrefour verificada puede coexistir con precio unitario de oferta',
    () {
      final today = DateTime.now();
      final offer = Promotion(
        id: 'carrefour-2x1',
        storeId: 'carrefour',
        tipoMedioPago: PaymentMethodType.card,
        entidad: 'Carrefour',
        porcentajeDescuento: 0,
        topeReintegro: 0,
        diasSemana: {today.weekday},
        fechaInicio: today,
        fechaFin: today,
        condiciones: '',
        categorias: const ['todos'],
        applicabilityScope: 'general_confirmed',
        promotionKind: 'store_product',
        mechanic: 'buy_n_pay_m',
        productEans: const {'1'},
        requiredQuantity: 2,
        chargedQuantity: 1,
        sourceType: 'official_api',
        calculationStatus: 'estimate',
        capturedAt: today,
      );
      final quote = engine.calcularPrecioFinal(
        product: product,
        supermercado: 'carrefour',
        precioOriginal: 2000,
        quantity: 2,
        fecha: today,
        mediosPagoUsuario: const [],
        promociones: [offer],
        hasStoreOffer: true,
      );
      expect(quote.precioFinal, 1000);
      expect(quote.estimated, isTrue);
    },
  );
}
