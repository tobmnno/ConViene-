import 'dart:convert';

import 'package:conviene/repositories/api_repository.dart';
import 'package:conviene/repositories/mock_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('consume scraper API contract and maps store aliases', () async {
    final repository = ApiRepository(
      baseUrl: Uri.parse('http://127.0.0.1:8000'),
      fallback: MockRepository(),
      client: MockClient((request) async {
        expect(request.url.path, '/search');
        expect(request.url.queryParameters['q'], 'leche');
        expect(request.url.queryParametersAll['stores'], ['la_gallega']);
        return http.Response(
          jsonEncode({
            'query': 'leche',
            'stores': ['la_gallega'],
            'count': 1,
            'results': [
              {
                'score': 98.4,
                'normalized_query': 'leche',
                'normalized_name': 'leche entera ilolay',
                'product': {
                  'store': 'la_gallega',
                  'name': 'Leche Entera Ilolay 1 L',
                  'price': r'$1.099,00',
                  'url': 'https://www.lagallega.com.ar/',
                  'available': true,
                  'scraped_at': '2026-08-21T12:00:00Z',
                },
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final results = await repository.searchProducts(
      query: 'leche',
      storeIds: {'lagallega'},
    );

    expect(results, hasLength(1));
    expect(results.single.supermarket.id, 'lagallega');
    expect(results.single.product.id, 'api_leche-entera-ilolay-1-l');
    expect(results.single.product.presentation, '1 L');
    expect(results.single.price.priceOriginal, 1099);

    final prices = await repository.getPricesForProduct(
      results.single.product.id,
    );
    expect(prices.single.storeId, 'lagallega');
  });

  test('falls back to mock results when scraper API is unavailable', () async {
    final repository = ApiRepository(
      baseUrl: Uri.parse('http://127.0.0.1:8000'),
      fallback: MockRepository(),
      client: MockClient((request) async => http.Response('nope', 500)),
    );

    final results = await repository.searchProducts(
      query: 'leche entera',
      storeIds: {'coto', 'carrefour', 'lagallega'},
    );

    expect(results, isNotEmpty);
    expect(results.map((result) => result.supermarket.id), contains('coto'));
  });
}
