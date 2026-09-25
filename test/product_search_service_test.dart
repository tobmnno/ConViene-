import 'package:conviene/models/price_quote.dart';
import 'package:conviene/models/product.dart';
import 'package:conviene/models/supermarket.dart';
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
