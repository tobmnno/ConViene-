import 'package:conviene/models/cart_item.dart';
import 'package:conviene/models/discount.dart';
import 'package:conviene/models/price_quote.dart';
import 'package:conviene/models/product.dart';
import 'package:conviene/models/supermarket.dart';
import 'package:conviene/repositories/conviene_repository.dart';
import 'package:conviene/repositories/mock_repository.dart';
import 'package:conviene/services/discount_engine.dart';
import 'package:conviene/services/payment_method_service.dart';
import 'package:conviene/services/price_comparison_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ordena supermercados por total final ascendente', () async {
    final repository = MockRepository();
    final service = PriceComparisonService(repository, const DiscountEngine());
    final date = DateTime(2026, 8, 20);
    final promotions = await repository.getPromotions(date);
    final methods = const PaymentMethodService().initialMethods();

    final comparisons = await service.compareCart(
      cartItems: const [
        CartItem(productId: 'leche_ilolay', quantity: 2),
        CartItem(productId: 'cafe_virginia', quantity: 1),
        CartItem(productId: 'yerba_taragui', quantity: 1),
      ],
      fecha: date,
      mediosPagoUsuario: methods,
      promociones: promotions,
      storeIds: const {'coto', 'carrefour', 'lagallega'},
    );

    expect(comparisons, hasLength(3));
    expect(comparisons.first.totalFinal <= comparisons[1].totalFinal, isTrue);
    expect(comparisons[1].totalFinal <= comparisons[2].totalFinal, isTrue);
    expect(comparisons.first.hasAllProducts, isTrue);
  });

  test('omite supermercados sin ningun producto disponible', () async {
    final repository = MockRepository();
    final service = PriceComparisonService(repository, const DiscountEngine());
    final date = DateTime(2026, 8, 20);
    final promotions = await repository.getPromotions(date);
    final methods = const PaymentMethodService().initialMethods();

    final comparisons = await service.compareCart(
      cartItems: const [CartItem(productId: 'arroz_gallo', quantity: 1)],
      fecha: date,
      mediosPagoUsuario: methods,
      promociones: promotions,
      storeIds: const {'carrefour'},
    );

    expect(comparisons, isEmpty);
  });

  test('busca equivalentes por nombre para completar el changuito', () async {
    final repository = _ComparableGalletitasRepository();
    final service = PriceComparisonService(repository, const DiscountEngine());

    final result = await service.compareCartOptions(
      cartItems: const [
        CartItem(
          productId: 'galletitas_chocolinas_carrefour',
          quantity: 1,
          selectedStoreId: 'carrefour',
        ),
        CartItem(
          productId: 'galletitas_cerealitas_coto',
          quantity: 1,
          selectedStoreId: 'coto',
        ),
      ],
      fecha: DateTime(2026, 8, 20),
      mediosPagoUsuario: const [],
      promociones: const [],
      storeIds: const {'coto', 'carrefour', 'lagallega'},
    );
    final comparisons = result.singleStoreComparisons;

    expect(comparisons.map((item) => item.supermarket.id), [
      'coto',
      'carrefour',
    ]);
    expect(comparisons.first.hasAllProducts, isTrue);
    expect(comparisons.first.items, hasLength(2));
    expect(comparisons[1].hasAllProducts, isTrue);
    expect(comparisons[1].items, hasLength(2));
    final equivalentLine = comparisons.first.items.firstWhere(
      (item) => item.product.id == 'galletitas_chocolinas_coto',
    );
    expect(equivalentLine.cartProductId, 'galletitas_chocolinas_carrefour');
    expect(
      result.selectedStoresPlan!.items.map((item) => item.supermarket.id),
      ['carrefour', 'coto'],
    );
    expect(
      result.bestPerProductPlan!.items.map((item) => item.supermarket.id),
      ['coto', 'coto'],
    );
  });

  test('no compara productos de distinta cantidad', () async {
    final repository = _DifferentSizeRepository();
    final service = PriceComparisonService(repository, const DiscountEngine());

    final result = await service.compareCartOptions(
      cartItems: const [
        CartItem(
          productId: 'crema_200_coto',
          quantity: 1,
          selectedStoreId: 'coto',
        ),
      ],
      fecha: DateTime(2026, 8, 20),
      mediosPagoUsuario: const [],
      promociones: const [],
      storeIds: const {'coto', 'carrefour'},
    );

    expect(result.singleStoreComparisons.map((item) => item.supermarket.id), [
      'coto',
    ]);
    expect(result.bestPerProductPlan!.items.single.supermarket.id, 'coto');
    expect(
      result.bestPerProductPlan!.items.single.product.presentation,
      '200cc',
    );
  });
}

class _ComparableGalletitasRepository implements ConvieneRepository {
  final _supermarkets = const [
    Supermarket(
      id: 'coto',
      name: 'Coto',
      shortName: 'COTO',
      enabled: true,
      brandColor: 0xFFE42127,
      websiteUrl: 'https://www.coto.com.ar/',
      logoAsset: '',
    ),
    Supermarket(
      id: 'carrefour',
      name: 'Carrefour',
      shortName: 'Carrefour',
      enabled: true,
      brandColor: 0xFF175CD3,
      websiteUrl: 'https://www.carrefour.com.ar/',
      logoAsset: '',
    ),
    Supermarket(
      id: 'lagallega',
      name: 'La Gallega',
      shortName: 'La Gallega',
      enabled: true,
      brandColor: 0xFF16B364,
      websiteUrl: 'https://www.lagallega.com.ar/',
      logoAsset: '',
    ),
  ];

  final _products = const [
    Product(
      id: 'galletitas_chocolinas_carrefour',
      ean: '',
      name: 'Galletitas Chocolinas de chocolate 100 g',
      brand: 'Chocolinas',
      presentation: '100 g',
      unit: 'kg',
      category: 'almacen',
      imageTag: 'generic',
    ),
    Product(
      id: 'galletitas_cerealitas_coto',
      ean: '',
      name: 'Galletitas Cerealitas clasicas 212 g',
      brand: 'Cerealitas',
      presentation: '212 g',
      unit: 'kg',
      category: 'almacen',
      imageTag: 'generic',
    ),
  ];

  @override
  Future<List<Supermarket>> getSupermarkets() async => _supermarkets;

  @override
  Future<List<Product>> getProducts() async => _products;

  @override
  Future<List<ProductPrice>> getPricesForProduct(String productId) async {
    if (productId == 'galletitas_chocolinas_carrefour') {
      return [
        ProductPrice(
          storeId: 'carrefour',
          productId: productId,
          priceOriginal: 900,
          priceUnitario: 9000,
          stock: true,
          url: 'https://www.carrefour.com.ar/',
          fechaActualizacion: DateTime(2026, 8, 20),
        ),
      ];
    }
    if (productId == 'galletitas_cerealitas_coto') {
      return [
        ProductPrice(
          storeId: 'coto',
          productId: productId,
          priceOriginal: 1200,
          priceUnitario: 5660.38,
          stock: true,
          url: 'https://www.coto.com.ar/',
          fechaActualizacion: DateTime(2026, 8, 20),
        ),
      ];
    }
    return [];
  }

  @override
  Future<List<SearchResult>> searchProducts({
    required String query,
    required Set<String> storeIds,
  }) async {
    if (query.contains('Chocolinas')) {
      const equivalentProduct = Product(
        id: 'galletitas_chocolinas_coto',
        ean: '',
        name: 'Galletitas Chocolinas 100 g',
        brand: 'Chocolinas',
        presentation: '100 g',
        unit: 'kg',
        category: 'almacen',
        imageTag: 'generic',
      );
      return [
        SearchResult(
          product: equivalentProduct,
          price: ProductPrice(
            storeId: 'coto',
            productId: equivalentProduct.id,
            priceOriginal: 700,
            priceUnitario: 7000,
            stock: true,
            url: 'https://www.coto.com.ar/',
            fechaActualizacion: DateTime(2026, 8, 20),
          ),
          supermarket: _supermarkets[0],
        ),
      ];
    }
    if (query.contains('Cerealitas')) {
      return [
        SearchResult(
          product: _products[1],
          price: ProductPrice(
            storeId: 'carrefour',
            productId: _products[1].id,
            priceOriginal: 1500,
            priceUnitario: 7075.47,
            stock: true,
            url: 'https://www.carrefour.com.ar/',
            fechaActualizacion: DateTime(2026, 8, 20),
          ),
          supermarket: _supermarkets[1],
        ),
      ];
    }
    return [];
  }

  @override
  Future<List<Promotion>> getPromotions(DateTime date) async => const [];
}

class _DifferentSizeRepository implements ConvieneRepository {
  final _supermarkets = const [
    Supermarket(
      id: 'coto',
      name: 'Coto',
      shortName: 'COTO',
      enabled: true,
      brandColor: 0xFFE42127,
      websiteUrl: 'https://www.coto.com.ar/',
      logoAsset: '',
    ),
    Supermarket(
      id: 'carrefour',
      name: 'Carrefour',
      shortName: 'Carrefour',
      enabled: true,
      brandColor: 0xFF175CD3,
      websiteUrl: 'https://www.carrefour.com.ar/',
      logoAsset: '',
    ),
  ];

  final _selectedProduct = const Product(
    id: 'crema_200_coto',
    ean: '',
    name: 'Crema de leche La Paulina 200cc',
    brand: 'La Paulina',
    presentation: '200cc',
    unit: 'L',
    category: 'lacteos',
    imageTag: 'milk',
  );

  @override
  Future<List<Supermarket>> getSupermarkets() async => _supermarkets;

  @override
  Future<List<Product>> getProducts() async => [_selectedProduct];

  @override
  Future<List<ProductPrice>> getPricesForProduct(String productId) async {
    return [
      ProductPrice(
        storeId: 'coto',
        productId: productId,
        priceOriginal: 2400,
        priceUnitario: 12000,
        stock: true,
        url: 'https://www.coto.com.ar/',
        fechaActualizacion: DateTime(2026, 8, 20),
      ),
    ];
  }

  @override
  Future<List<SearchResult>> searchProducts({
    required String query,
    required Set<String> storeIds,
  }) async {
    const carrefourProduct = Product(
      id: 'crema_350_carrefour',
      ean: '',
      name: 'Crema de leche La Paulina 350cc',
      brand: 'La Paulina',
      presentation: '350cc',
      unit: 'L',
      category: 'lacteos',
      imageTag: 'milk',
    );
    const otherBrandSameSize = Product(
      id: 'crema_200_carrefour',
      ean: '',
      name: 'Crema La Serenisima liviana 200 cc',
      brand: 'La Serenisima',
      presentation: '200 cc',
      unit: 'L',
      category: 'lacteos',
      imageTag: 'milk',
    );
    return [
      SearchResult(
        product: carrefourProduct,
        price: ProductPrice(
          storeId: 'carrefour',
          productId: carrefourProduct.id,
          priceOriginal: 2600,
          priceUnitario: 7428.57,
          stock: true,
          url: 'https://www.carrefour.com.ar/',
          fechaActualizacion: DateTime(2026, 8, 20),
        ),
        supermarket: _supermarkets[1],
      ),
      SearchResult(
        product: otherBrandSameSize,
        price: ProductPrice(
          storeId: 'carrefour',
          productId: otherBrandSameSize.id,
          priceOriginal: 1900,
          priceUnitario: 9500,
          stock: true,
          url: 'https://www.carrefour.com.ar/',
          fechaActualizacion: DateTime(2026, 8, 20),
        ),
        supermarket: _supermarkets[1],
      ),
    ];
  }

  @override
  Future<List<Promotion>> getPromotions(DateTime date) async => const [];
}
