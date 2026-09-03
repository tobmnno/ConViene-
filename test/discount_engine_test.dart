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
  );
  const visa = PaymentMethod(
    id: 'visa',
    type: PaymentMethodType.card,
    entity: 'Visa',
    displayName: 'Visa',
    active: true,
  );

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
}
