import 'package:conviene/models/price_quote.dart';
import 'package:conviene/models/product.dart';
import 'package:conviene/models/supermarket.dart';
import 'package:conviene/models/shopping_context.dart';
import 'package:conviene/repositories/mock_repository.dart';
import 'package:conviene/services/product_search_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prioriza coincidencias de busqueda antes que precio mas bajo', () {
    final service = ProductSearchService(MockRepository());
    final coto = _store('coto', 'Coto');
    final results = [
      _result(
        supermarket: coto,
        productId: 'ilolay_200',
        name: 'Crema De Leche ILOLAY 200 CC',
        presentation: '200 CC',
        price: 1823.40,
      ),
      _result(
        supermarket: coto,
        productId: 'paulina_200',
        name: 'Crema De Leche LA PAULINA 200cc',
        presentation: '200cc',
        price: 2112,
      ),
    ];

    final sorted = service.sortResults(
      results,
      SearchSort.bestPrice,
      query: 'crema la paulina 200cc',
    );

    expect(sorted.first.product.id, 'paulina_200');
  });

  test('deja coincidencias similares debajo de las exactas', () {
    final service = ProductSearchService(MockRepository());
    final coto = _store('coto', 'Coto');
    final exact = _result(
      supermarket: coto,
      productId: 'exact',
      name: 'Galletitas Oreo Frutilla 118 g',
      presentation: '118 g',
      price: 2200,
    );
    final similar = SearchResult(
      product: exact.product,
      price: ProductPrice(
        storeId: coto.id,
        productId: 'similar',
        priceOriginal: 1000,
        priceUnitario: 1000,
        stock: true,
        url: coto.websiteUrl,
        fechaActualizacion: DateTime(2026, 8, 20),
      ),
      supermarket: coto,
      relevanceScore: 99,
      isExactMatch: false,
    );

    final sorted = service.sortResults(
      [similar, exact],
      SearchSort.bestPrice,
      query: 'galletitas oreo frutilla 118g',
    );

    expect(sorted.first.isExactMatch, isTrue);
  });

  test('busqueda especifica muestra solo el producto pedido', () async {
    final store = _store('coto', 'Coto');
    final exact = _result(
      supermarket: store,
      productId: 'plain',
      name: 'Crema La Paulina 200 cc',
      presentation: '200 cc',
      price: 2400,
    );
    final double = SearchResult(
      product: _result(
        supermarket: store,
        productId: 'double',
        name: 'Crema La Paulina Doble 200 cc',
        presentation: '200 cc',
        price: 2000,
      ).product,
      price: _result(
        supermarket: store,
        productId: 'double',
        name: 'Crema La Paulina Doble 200 cc',
        presentation: '200 cc',
        price: 2000,
      ).price,
      supermarket: store,
      isExactMatch: false,
    );
    final service = ProductSearchService(_FixedSearchRepository([double, exact]));

    final found = await service.search(
      query: 'crema la paulina 200cc',
      storeIds: {'coto'},
      sort: SearchSort.bestPrice,
    );

    expect(found.map((result) => result.product.id), ['plain']);
  });

  test('busqueda general sigue mostrando variantes', () async {
    final store = _store('coto', 'Coto');
    final similar = _result(
      supermarket: store,
      productId: 'milk',
      name: 'Leche entera 1 L',
      presentation: '1 L',
      price: 1500,
    );
    final service = ProductSearchService(
      _FixedSearchRepository([
        SearchResult(
          product: similar.product,
          price: similar.price,
          supermarket: similar.supermarket,
          isExactMatch: false,
        ),
      ]),
    );

    final found = await service.search(
      query: 'leche 1L',
      storeIds: {'coto'},
      sort: SearchSort.bestPrice,
    );

    expect(found, hasLength(1));
  });
}

class _FixedSearchRepository extends MockRepository {
  _FixedSearchRepository(this.results);

  final List<SearchResult> results;

  @override
  Future<List<SearchResult>> searchProducts({
    required String query,
    required Set<String> storeIds,
    ShoppingContext context = const ShoppingContext(),
  }) async => results;
}

Supermarket _store(String id, String name) {
  return Supermarket(
    id: id,
    name: name,
    shortName: name,
    enabled: true,
    brandColor: 0xFF175CD3,
    websiteUrl: 'https://example.com/',
    logoAsset: '',
  );
}

SearchResult _result({
  required Supermarket supermarket,
  required String productId,
  required String name,
  required String presentation,
  required double price,
}) {
  final product = Product(
    id: productId,
    ean: '',
    name: name,
    brand: '',
    presentation: presentation,
    unit: 'L',
    category: 'lacteos',
    imageTag: 'milk',
  );
  return SearchResult(
    product: product,
    price: ProductPrice(
      storeId: supermarket.id,
      productId: product.id,
      priceOriginal: price,
      priceUnitario: price,
      stock: true,
      url: supermarket.websiteUrl,
      fechaActualizacion: DateTime(2026, 8, 20),
    ),
    supermarket: supermarket,
  );
}
