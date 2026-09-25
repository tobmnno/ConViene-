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
    final septemberStart = DateTime(2026, 9, 1);
    final septemberEnd = DateTime(2026, 9, 30);
    final fallbackEnd = DateTime(2026, 12, 31);
    const cotoSource = 'https://www.coto.com.ar/descuentos';
    const laGallegaSource = 'https://www.lagallega.com.ar/Beneficios.asp';

    return [
      Promotion(
        id: 'promo_coto_visa_master_3_6_cuotas_electro_sep',
        storeId: 'coto',
        tipoMedioPago: PaymentMethodType.card,
        entidad: 'Visa y Mastercard',
        porcentajeDescuento: 0,
        topeReintegro: 0,
        diasSemana: allDays,
        fechaInicio: septemberStart,
        fechaFin: septemberEnd,
        condiciones:
            '3-6 cuotas sin interes con tarjetas de credito Visa y Mastercard. Productos de Electro. Aplican exclusiones y legales de Coto.',
        categorias: const ['electro'],
        titulo: 'Visa y Mastercard electro',
        beneficio: '3-6 cuotas',
        canal: 'Digital',
        textoVigencia: 'Del 01/09 al 30/09/2026',
        fuenteUrl: cotoSource,
        entidadesCompatibles: const {'Visa', 'Mastercard'},
      ),
      Promotion(
        id: 'promo_lagallega_santa_fe_30_reintegro',
        storeId: 'lagallega',
        tipoMedioPago: PaymentMethodType.bank,
        entidad: 'Banco Santa Fe',
        porcentajeDescuento: 30,
        topeReintegro: 25000,
        diasSemana: allDays,
        fechaInicio: septemberStart,
        fechaFin: fallbackEnd,
        condiciones:
            '30% de reintegro con tarjeta fisica Banco Santa Fe. Tope mensual \$25.000. Tarjetas de credito Visa y Mastercard del banco.',
        categorias: const ['todos'],
        titulo: 'Banco Santa Fe',
        beneficio: '30% OFF',
        canal: '',
        textoVigencia: 'Todos los dias',
        fuenteUrl: laGallegaSource,
        entidadesCompatibles: const {'Banco Santa Fe', 'Visa', 'Mastercard'},
        tiposMedioPagoCompatibles: const {
          PaymentMethodType.bank,
          PaymentMethodType.card,
        },
      ),
      Promotion(
        id: 'promo_lagallega_coinag_20_reintegro',
        storeId: 'lagallega',
        tipoMedioPago: PaymentMethodType.bank,
        entidad: 'Banco Coinag',
        porcentajeDescuento: 20,
        topeReintegro: 14000,
        diasSemana: allDays,
        fechaInicio: septemberStart,
        fechaFin: fallbackEnd,
        condiciones:
            '20% de reintegro con tarjeta fisica Banco Coinag. Tope \$14.000 en una compra unica por cuenta por mes con Visa credito.',
        categorias: const ['todos'],
        titulo: 'Banco Coinag',
        beneficio: '20% OFF',
        canal: '',
        textoVigencia: 'Todos los dias',
        fuenteUrl: laGallegaSource,
        entidadesCompatibles: const {'Banco Coinag', 'Visa'},
        tiposMedioPagoCompatibles: const {
          PaymentMethodType.bank,
          PaymentMethodType.card,
        },
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
