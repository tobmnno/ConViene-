import '../models/discount.dart';
import '../models/payment_method.dart';
import '../models/price_quote.dart';
import '../models/product.dart';
import '../models/supermarket.dart';
import 'conviene_repository.dart';

class MockRepository implements ConvieneRepository {
  MockRepository();

  static final DateTime _updatedAt = DateTime(2026, 9, 3, 12);

  final List<Supermarket> _supermarkets = const [
    Supermarket(
      id: 'coto',
      name: 'Coto',
      shortName: 'COTO',
      enabled: true,
      brandColor: 0xFFE42127,
      websiteUrl: 'https://www.coto.com.ar/',
      logoAsset: 'assets/logos/coto.svg',
    ),
    Supermarket(
      id: 'carrefour',
      name: 'Carrefour',
      shortName: 'Carrefour',
      enabled: true,
      brandColor: 0xFF175CD3,
      websiteUrl: 'https://www.carrefour.com.ar/',
      logoAsset: 'assets/logos/carrefour.svg',
    ),
    Supermarket(
      id: 'lagallega',
      name: 'La Gallega',
      shortName: 'La Gallega',
      enabled: true,
      brandColor: 0xFF16B364,
      websiteUrl: 'https://www.lagallega.com.ar/',
      logoAsset: 'assets/logos/la_gallega.png',
    ),
    Supermarket(
      id: 'dia',
      name: 'Dia',
      shortName: 'Dia',
      enabled: false,
      brandColor: 0xFFE30613,
      websiteUrl: 'https://www.diaonline.com.ar/',
      logoAsset: '',
    ),
    Supermarket(
      id: 'changomas',
      name: 'ChangoMas',
      shortName: 'ChangoMas',
      enabled: false,
      brandColor: 0xFFE7344C,
      websiteUrl: 'https://www.masonline.com.ar/',
      logoAsset: '',
    ),
    Supermarket(
      id: 'laanonima',
      name: 'La Anonima',
      shortName: 'La Anonima',
      enabled: false,
      brandColor: 0xFF0E5AA7,
      websiteUrl: 'https://www.laanonimaonline.com/',
      logoAsset: '',
    ),
  ];

  final List<Product> _products = const [
    Product(
      id: 'leche_ilolay',
      ean: '7790787000016',
      name: 'Leche entera Ilolay',
      brand: 'Ilolay',
      presentation: '1 L',
      unit: 'L',
      category: 'lacteos',
      imageTag: 'milk',
    ),
    Product(
      id: 'cafe_virginia',
      ean: '7790150022515',
      name: 'Cafe La Virginia',
      brand: 'La Virginia',
      presentation: '500 g',
      unit: 'kg',
      category: 'almacen',
      imageTag: 'coffee',
    ),
    Product(
      id: 'yerba_taragui',
      ean: '7790387010019',
      name: 'Yerba Taragui',
      brand: 'Taragui',
      presentation: '1 kg',
      unit: 'kg',
      category: 'almacen',
      imageTag: 'yerba',
    ),
    Product(
      id: 'pan_bimbo',
      ean: '7796989000111',
      name: 'Pan lactal Bimbo',
      brand: 'Bimbo',
      presentation: '550 g',
      unit: 'kg',
      category: 'panificados',
      imageTag: 'bread',
    ),
    Product(
      id: 'aceite_natura',
      ean: '7790272001018',
      name: 'Aceite Natura',
      brand: 'Natura',
      presentation: '900 ml',
      unit: 'L',
      category: 'almacen',
      imageTag: 'oil',
    ),
    Product(
      id: 'arroz_gallo',
      ean: '7790070411200',
      name: 'Arroz Gallo oro',
      brand: 'Gallo',
      presentation: '1 kg',
      unit: 'kg',
      category: 'almacen',
      imageTag: 'rice',
    ),
  ];

  late final List<ProductPrice> _prices = [
    ProductPrice(
      storeId: 'lagallega',
      productId: 'leche_ilolay',
      priceOriginal: 1099,
      priceUnitario: 1099,
      stock: true,
      url: 'https://www.lagallega.com.ar/',
      fechaActualizacion: _updatedAt,
    ),
    ProductPrice(
      storeId: 'coto',
      productId: 'leche_ilolay',
      priceOriginal: 1189,
      priceUnitario: 1189,
      stock: true,
      url: 'https://www.coto.com.ar/',
      fechaActualizacion: _updatedAt,
    ),
    ProductPrice(
      storeId: 'carrefour',
      productId: 'leche_ilolay',
      priceOriginal: 1259,
      priceUnitario: 1259,
      stock: true,
      url: 'https://www.carrefour.com.ar/',
      fechaActualizacion: _updatedAt,
    ),
    ProductPrice(
      storeId: 'lagallega',
      productId: 'cafe_virginia',
      priceOriginal: 3890,
      priceUnitario: 7780,
      stock: true,
      url: 'https://www.lagallega.com.ar/',
      fechaActualizacion: _updatedAt,
    ),
    ProductPrice(
      storeId: 'coto',
      productId: 'cafe_virginia',
      priceOriginal: 3690,
      priceUnitario: 7380,
      stock: true,
      url: 'https://www.coto.com.ar/',
      fechaActualizacion: _updatedAt,
    ),
    ProductPrice(
      storeId: 'carrefour',
      productId: 'cafe_virginia',
      priceOriginal: 3980,
      priceUnitario: 7960,
      stock: true,
      url: 'https://www.carrefour.com.ar/',
      fechaActualizacion: _updatedAt,
    ),
    ProductPrice(
      storeId: 'lagallega',
      productId: 'yerba_taragui',
      priceOriginal: 3190,
      priceUnitario: 3190,
      stock: true,
      url: 'https://www.lagallega.com.ar/',
      fechaActualizacion: _updatedAt,
    ),
    ProductPrice(
      storeId: 'coto',
      productId: 'yerba_taragui',
      priceOriginal: 3050,
      priceUnitario: 3050,
      stock: true,
      url: 'https://www.coto.com.ar/',
      fechaActualizacion: _updatedAt,
    ),
    ProductPrice(
      storeId: 'carrefour',
      productId: 'yerba_taragui',
      priceOriginal: 3330,
      priceUnitario: 3330,
      stock: true,
      url: 'https://www.carrefour.com.ar/',
      fechaActualizacion: _updatedAt,
    ),
    ProductPrice(
      storeId: 'lagallega',
      productId: 'pan_bimbo',
      priceOriginal: 1880,
      priceUnitario: 3418.18,
      stock: true,
      url: 'https://www.lagallega.com.ar/',
      fechaActualizacion: _updatedAt,
    ),
    ProductPrice(
      storeId: 'coto',
      productId: 'pan_bimbo',
      priceOriginal: 1790,
      priceUnitario: 3254.55,
      stock: true,
      url: 'https://www.coto.com.ar/',
      fechaActualizacion: _updatedAt,
    ),
    ProductPrice(
      storeId: 'carrefour',
      productId: 'pan_bimbo',
      priceOriginal: 1760,
      priceUnitario: 3200,
      stock: true,
      url: 'https://www.carrefour.com.ar/',
      fechaActualizacion: _updatedAt,
    ),
    ProductPrice(
      storeId: 'lagallega',
      productId: 'aceite_natura',
      priceOriginal: 2390,
      priceUnitario: 2655.56,
      stock: true,
      url: 'https://www.lagallega.com.ar/',
      fechaActualizacion: _updatedAt,
    ),
    ProductPrice(
      storeId: 'coto',
      productId: 'aceite_natura',
      priceOriginal: 2490,
      priceUnitario: 2766.67,
      stock: true,
      url: 'https://www.coto.com.ar/',
      fechaActualizacion: _updatedAt,
    ),
    ProductPrice(
      storeId: 'carrefour',
      productId: 'aceite_natura',
      priceOriginal: 2580,
      priceUnitario: 2866.67,
      stock: true,
      url: 'https://www.carrefour.com.ar/',
      fechaActualizacion: _updatedAt,
    ),
    ProductPrice(
      storeId: 'lagallega',
      productId: 'arroz_gallo',
      priceOriginal: 2140,
      priceUnitario: 2140,
      stock: true,
      url: 'https://www.lagallega.com.ar/',
      fechaActualizacion: _updatedAt,
    ),
    ProductPrice(
      storeId: 'coto',
      productId: 'arroz_gallo',
      priceOriginal: 2190,
      priceUnitario: 2190,
      stock: true,
      url: 'https://www.coto.com.ar/',
      fechaActualizacion: _updatedAt,
    ),
  ];

  @override
  Future<List<Supermarket>> getSupermarkets() async {
    return _supermarkets;
  }

  @override
  Future<List<Product>> getProducts() async {
    return _products;
  }

  @override
  Future<List<ProductPrice>> getPricesForProduct(String productId) async {
    return _prices.where((price) => price.productId == productId).toList();
  }

  @override
  Future<List<Promotion>> getPromotions(DateTime date) async {
    final promotions = _promotions();
    return promotions.where((promotion) => promotion.appliesOn(date)).toList();
  }

  @override
  Future<List<SearchResult>> searchProducts({
    required String query,
    required Set<String> storeIds,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final normalizedQuery = _normalize(query);
    final matches = _products.where((product) {
      final haystack = _normalize(
        '${product.name} ${product.brand} ${product.presentation}',
      );
      return normalizedQuery.isEmpty || haystack.contains(normalizedQuery);
    });

    return [
      for (final product in matches)
        for (final price in _prices.where(
          (price) =>
              price.productId == product.id && storeIds.contains(price.storeId),
        ))
          SearchResult(
            product: product,
            price: price,
            supermarket: _supermarkets.firstWhere(
              (store) => store.id == price.storeId,
            ),
          ),
    ];
  }

  List<Promotion> _promotions() {
    const allDays = {
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
      DateTime.saturday,
      DateTime.sunday,
    };
    const mondayToFriday = {
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
    };
    const weekend = {DateTime.saturday, DateTime.sunday};
    const mondayWednesday = {DateTime.monday, DateTime.wednesday};
    final septemberStart = DateTime(2026, 9, 1);
    final septemberEnd = DateTime(2026, 9, 30);
    const cotoSource = 'https://www.coto.com.ar/descuentos/';
    const laGallegaSource = 'https://www.lagallega.com.ar/Beneficios.asp';
    const carrefourSource = 'https://www.carrefour.com.ar/descuentos-bancarios';

    return [
      Promotion(
        id: 'promo_coto_visa_master_6_cuotas_electro_sep',
        storeId: 'coto',
        tipoMedioPago: PaymentMethodType.card,
        entidad: 'Visa y Mastercard',
        porcentajeDescuento: 0,
        topeReintegro: 0,
        diasSemana: allDays,
        fechaInicio: septemberStart,
        fechaFin: septemberEnd,
        condiciones:
            '6 cuotas sin interes con tarjetas de credito Visa y Mastercard. Aplica en electrodomesticos. Aplican exclusiones.',
        categorias: const ['electro'],
        titulo: 'Visa y Mastercard electro',
        beneficio: '6 cuotas',
        canal: 'Digital',
        textoVigencia: 'Del 01/09 al 30/09/2026',
        fuenteUrl: cotoSource,
        entidadesCompatibles: const {'Visa', 'Mastercard'},
      ),
      Promotion(
        id: 'promo_lagallega_nave_galicia_qr_sep',
        storeId: 'lagallega',
        tipoMedioPago: PaymentMethodType.bank,
        entidad: 'Banco Galicia',
        porcentajeDescuento: 20,
        topeReintegro: 20000,
        diasSemana: allDays,
        fechaInicio: septemberStart,
        fechaFin: septemberEnd,
        condiciones:
            'Unicamente para pagos con QR desde la aplicacion Galicia Nave, con tarjetas de credito Mastercard y Visa asociadas.',
        categorias: const ['todos'],
        titulo: 'Banco Galicia Nave',
        beneficio: '20% OFF',
        canal: 'Tienda y online',
        textoVigencia: 'Todos los dias de septiembre',
        fuenteUrl: laGallegaSource,
        entidadesCompatibles: const {'Banco Galicia', 'Nave Galicia'},
        tiposMedioPagoCompatibles: const {
          PaymentMethodType.bank,
          PaymentMethodType.wallet,
        },
      ),
      Promotion(
        id: 'promo_carrefour_empleado_publico_miercoles_15_sep',
        storeId: 'carrefour',
        tipoMedioPago: PaymentMethodType.wallet,
        entidad: 'Empleado publico',
        porcentajeDescuento: 15,
        topeReintegro: 20000,
        diasSemana: const {DateTime.wednesday},
        fechaInicio: septemberStart,
        fechaFin: septemberEnd,
        condiciones:
            'Si sos empleada/o publico. Descuento valido en Market durante septiembre.',
        categorias: const ['todos'],
        titulo: 'Empleado publico miercoles',
        beneficio: '15% OFF',
        canal: 'Market',
        textoVigencia: 'Miercoles de septiembre',
        fuenteUrl: carrefourSource,
      ),
      Promotion(
        id: 'promo_carrefour_mercado_pago_qr_3_cuotas_sep',
        storeId: 'carrefour',
        tipoMedioPago: PaymentMethodType.wallet,
        entidad: 'Mercado Pago',
        porcentajeDescuento: 0,
        topeReintegro: 0,
        diasSemana: allDays,
        fechaInicio: septemberStart,
        fechaFin: septemberEnd,
        condiciones:
            'Hasta 3 cuotas sin interes pagando con QR desde Mercado Pago. Compra minima informada: \$150.000.',
        categorias: const ['todos'],
        titulo: 'Mercado Pago QR',
        beneficio: '3 cuotas',
        canal: 'Market',
        textoVigencia: 'Todos los dias de septiembre',
        fuenteUrl: carrefourSource,
      ),
      Promotion(
        id: 'promo_carrefour_naranja_4_cuotas_sep',
        storeId: 'carrefour',
        tipoMedioPago: PaymentMethodType.card,
        entidad: 'Naranja X',
        porcentajeDescuento: 0,
        topeReintegro: 0,
        diasSemana: allDays,
        fechaInicio: septemberStart,
        fechaFin: septemberEnd,
        condiciones:
            '4 cuotas sin interes para toda la compra con Tarjeta Naranja.',
        categorias: const ['todos'],
        titulo: 'Tarjeta Naranja',
        beneficio: '4 cuotas',
        canal: 'Tiendas seleccionadas',
        textoVigencia: 'Todos los dias de septiembre',
        fuenteUrl: carrefourSource,
      ),
      Promotion(
        id: 'promo_carrefour_club_la_nacion_lunes_15_sep',
        storeId: 'carrefour',
        tipoMedioPago: PaymentMethodType.wallet,
        entidad: 'Club La Nacion',
        porcentajeDescuento: 15,
        topeReintegro: 0,
        diasSemana: const {DateTime.monday},
        fechaInicio: septemberStart,
        fechaFin: septemberEnd,
        condiciones: '15% de descuento con Club La Nacion. Sin tope informado.',
        categorias: const ['todos'],
        titulo: 'Club La Nacion',
        beneficio: '15% OFF',
        canal: 'Online',
        textoVigencia: 'Lunes de septiembre',
        fuenteUrl: carrefourSource,
      ),
      Promotion(
        id: 'promo_carrefour_cuenta_digital_viernes_15_sep',
        storeId: 'carrefour',
        tipoMedioPago: PaymentMethodType.wallet,
        entidad: 'Cuenta Digital Carrefour Banco',
        porcentajeDescuento: 15,
        topeReintegro: 0,
        diasSemana: const {DateTime.friday},
        fechaInicio: septemberStart,
        fechaFin: septemberEnd,
        condiciones:
            '15% de descuento con Cuenta Digital Carrefour Banco. No incluye categorias excluidas por legales.',
        categorias: const ['todos'],
        titulo: 'Cuenta Digital viernes',
        beneficio: '15% OFF',
        canal: 'Online y Market',
        textoVigencia: 'Viernes de septiembre',
        fuenteUrl: carrefourSource,
      ),
      Promotion(
        id: 'promo_carrefour_cuenta_digital_fin_de_semana_10_sep',
        storeId: 'carrefour',
        tipoMedioPago: PaymentMethodType.wallet,
        entidad: 'Cuenta Digital Carrefour Banco',
        porcentajeDescuento: 10,
        topeReintegro: 0,
        diasSemana: weekend,
        fechaInicio: septemberStart,
        fechaFin: septemberEnd,
        condiciones:
            '10% de descuento con Cuenta Digital Carrefour Banco. Sin tope informado.',
        categorias: const ['todos'],
        titulo: 'Cuenta Digital fin de semana',
        beneficio: '10% OFF',
        canal: 'Online y Market',
        textoVigencia: 'Sabados y domingos de septiembre',
        fuenteUrl: carrefourSource,
      ),
      Promotion(
        id: 'promo_carrefour_patagonia_singular_miercoles_35_sep',
        storeId: 'carrefour',
        tipoMedioPago: PaymentMethodType.bank,
        entidad: 'Banco Patagonia',
        porcentajeDescuento: 35,
        topeReintegro: 25000,
        diasSemana: const {DateTime.wednesday},
        fechaInicio: septemberStart,
        fechaFin: septemberEnd,
        condiciones:
            '35% de descuento con tarjeta Visa del Banco Patagonia. Tope informado: \$25.000.',
        categorias: const ['todos'],
        titulo: 'Banco Patagonia Visa',
        beneficio: '35% OFF',
        canal: 'Online y Market',
        textoVigencia: 'Miercoles de septiembre',
        fuenteUrl: carrefourSource,
      ),
      Promotion(
        id: 'promo_carrefour_patagonia_plus_miercoles_30_sep',
        storeId: 'carrefour',
        tipoMedioPago: PaymentMethodType.bank,
        entidad: 'Banco Patagonia',
        porcentajeDescuento: 30,
        topeReintegro: 20000,
        diasSemana: const {DateTime.wednesday},
        fechaInicio: septemberStart,
        fechaFin: septemberEnd,
        condiciones:
            '30% de descuento con Visa, Mastercard y American Express Plus del Banco Patagonia.',
        categorias: const ['todos'],
        titulo: 'Banco Patagonia Plus',
        beneficio: '30% OFF',
        canal: 'Online y Market',
        textoVigencia: 'Miercoles de septiembre',
        fuenteUrl: carrefourSource,
      ),
      Promotion(
        id: 'promo_carrefour_patagonia_visa_miercoles_20_sep',
        storeId: 'carrefour',
        tipoMedioPago: PaymentMethodType.bank,
        entidad: 'Banco Patagonia',
        porcentajeDescuento: 20,
        topeReintegro: 15000,
        diasSemana: const {DateTime.wednesday},
        fechaInicio: septemberStart,
        fechaFin: septemberEnd,
        condiciones:
            '20% de descuento con tarjeta Visa del Banco Patagonia. Tope informado: \$15.000.',
        categorias: const ['todos'],
        titulo: 'Banco Patagonia Visa clasica',
        beneficio: '20% OFF',
        canal: 'Online y Market',
        textoVigencia: 'Miercoles de septiembre',
        fuenteUrl: carrefourSource,
      ),
      Promotion(
        id: 'promo_carrefour_patagonia_sueldo_miercoles_15_sep',
        storeId: 'carrefour',
        tipoMedioPago: PaymentMethodType.bank,
        entidad: 'Banco Patagonia',
        porcentajeDescuento: 15,
        topeReintegro: 10000,
        diasSemana: const {DateTime.wednesday},
        fechaInicio: septemberStart,
        fechaFin: septemberEnd,
        condiciones:
            '15% de ahorro con Visa, Mastercard y Amex para clientes con plan sueldo Banco Patagonia.',
        categorias: const ['todos'],
        titulo: 'Banco Patagonia plan sueldo',
        beneficio: '15% OFF',
        canal: 'Online y Market',
        textoVigencia: 'Miercoles de septiembre',
        fuenteUrl: carrefourSource,
      ),
      Promotion(
        id: 'promo_carrefour_banco_tarjeta_jueves_20_sep',
        storeId: 'carrefour',
        tipoMedioPago: PaymentMethodType.card,
        entidad: 'Tarjeta Carrefour Banco',
        porcentajeDescuento: 20,
        topeReintegro: 10000,
        diasSemana: const {DateTime.thursday},
        fechaInicio: septemberStart,
        fechaFin: septemberEnd,
        condiciones:
            '20% de descuento con tarjeta de credito de Carrefour Banco. Tope informado: \$10.000.',
        categorias: const ['todos'],
        titulo: 'Tarjeta Carrefour Banco jueves',
        beneficio: '20% OFF',
        canal: 'Online y Market',
        textoVigencia: 'Jueves de septiembre',
        fuenteUrl: carrefourSource,
        entidadesCompatibles: const {
          'Tarjeta Carrefour Banco',
          'Carrefour Banco',
        },
        tiposMedioPagoCompatibles: const {
          PaymentMethodType.card,
          PaymentMethodType.bank,
        },
      ),
      Promotion(
        id: 'promo_carrefour_todos_los_medios_jueves_10_sep',
        storeId: 'carrefour',
        tipoMedioPago: PaymentMethodType.card,
        entidad: 'Todos los medios de pago',
        porcentajeDescuento: 10,
        topeReintegro: 8000,
        diasSemana: const {DateTime.thursday},
        fechaInicio: septemberStart,
        fechaFin: septemberEnd,
        condiciones:
            '10% OFF todos los medios de pago, exclusivo online. Tope informado: \$8.000.',
        categorias: const ['todos'],
        titulo: 'Todos los medios de pago',
        beneficio: '10% OFF',
        canal: 'Online',
        textoVigencia: 'Jueves de septiembre',
        fuenteUrl: carrefourSource,
        cualquierEntidad: true,
        tiposMedioPagoCompatibles: const {
          PaymentMethodType.card,
          PaymentMethodType.bank,
          PaymentMethodType.wallet,
        },
      ),
      Promotion(
        id: 'promo_carrefour_tarjeta_banco_3_cuotas_finde_sep',
        storeId: 'carrefour',
        tipoMedioPago: PaymentMethodType.card,
        entidad: 'Tarjeta Carrefour Banco',
        porcentajeDescuento: 0,
        topeReintegro: 0,
        diasSemana: weekend,
        fechaInicio: septemberStart,
        fechaFin: septemberEnd,
        condiciones:
            '3 cuotas sin interes con Tarjeta de Credito Carrefour Banco.',
        categorias: const ['todos'],
        titulo: 'Tarjeta Carrefour Banco fin de semana',
        beneficio: '3 cuotas',
        canal: 'Online y Market',
        textoVigencia: 'Sabados y domingos de septiembre',
        fuenteUrl: carrefourSource,
      ),
      Promotion(
        id: 'promo_carrefour_modo_jubilados_lunes_viernes_5_sep',
        storeId: 'carrefour',
        tipoMedioPago: PaymentMethodType.wallet,
        entidad: 'MODO',
        porcentajeDescuento: 5,
        topeReintegro: 5000,
        diasSemana: mondayToFriday,
        fechaInicio: septemberStart,
        fechaFin: septemberEnd,
        condiciones:
            '5% de ahorro para jubilados o pensionados pagando con MODO. Tope informado: \$5.000.',
        categorias: const ['todos'],
        titulo: 'MODO jubilados',
        beneficio: '5% OFF',
        canal: 'Market',
        textoVigencia: 'Lunes a viernes de septiembre',
        fuenteUrl: carrefourSource,
      ),
      Promotion(
        id: 'promo_carrefour_cuenta_dni_miercoles_10_sep',
        storeId: 'carrefour',
        tipoMedioPago: PaymentMethodType.wallet,
        entidad: 'Cuenta DNI',
        porcentajeDescuento: 10,
        topeReintegro: 0,
        diasSemana: const {DateTime.wednesday},
        fechaInicio: septemberStart,
        fechaFin: septemberEnd,
        condiciones:
            '10% de descuento con Cuenta DNI. La comunicacion informa beneficio adicional para jubilados.',
        categorias: const ['todos'],
        titulo: 'Cuenta DNI',
        beneficio: '10% OFF',
        canal: 'Market',
        textoVigencia: 'Miercoles de septiembre',
        fuenteUrl: carrefourSource,
      ),
      Promotion(
        id: 'promo_carrefour_mercado_pago_lunes_miercoles_6_cuotas_sep',
        storeId: 'carrefour',
        tipoMedioPago: PaymentMethodType.wallet,
        entidad: 'Mercado Pago',
        porcentajeDescuento: 0,
        topeReintegro: 0,
        diasSemana: mondayWednesday,
        fechaInicio: septemberStart,
        fechaFin: septemberEnd,
        condiciones:
            'Hasta 6 cuotas sin interes con Mercado Pago los lunes y miercoles.',
        categorias: const ['todos'],
        titulo: 'Mercado Pago cuotas',
        beneficio: '6 cuotas',
        canal: 'Online y Market',
        textoVigencia: 'Lunes y miercoles de septiembre',
        fuenteUrl: carrefourSource,
      ),
      Promotion(
        id: 'promo_carrefour_mercado_pago_saldo_jueves_15_sep',
        storeId: 'carrefour',
        tipoMedioPago: PaymentMethodType.wallet,
        entidad: 'Mercado Pago',
        porcentajeDescuento: 15,
        topeReintegro: 0,
        diasSemana: const {DateTime.thursday},
        fechaInicio: septemberStart,
        fechaFin: septemberEnd,
        condiciones:
            '15% de descuento sin tope informado pagando con dinero en cuenta de Mercado Pago.',
        categorias: const ['todos'],
        titulo: 'Mercado Pago dinero en cuenta',
        beneficio: '15% OFF',
        canal: 'Online y Market',
        textoVigencia: 'Jueves de septiembre',
        fuenteUrl: carrefourSource,
      ),
    ];
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
        .replaceAll('ñ', 'n');
  }
}
