import 'dart:convert';

import 'package:conviene/models/payment_method.dart';
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
                  'image': 'https://www.lagallega.com.ar/foto.jpg',
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
    expect(
      results.single.product.imageUrl,
      startsWith('http://127.0.0.1:8000/image?url='),
    );
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

  test(
    'consume discounts API contract and maps compatible payment methods',
    () async {
      final repository = ApiRepository(
        baseUrl: Uri.parse('http://127.0.0.1:8000'),
        fallback: MockRepository(),
        client: MockClient((request) async {
          expect(request.url.path, '/discounts');
          expect(request.url.queryParameters['date'], '2026-09-04');
          expect(request.url.queryParametersAll['stores'], [
            'carrefour',
            'coto',
            'la_gallega',
          ]);
          return http.Response(
            jsonEncode({
              'date': '2026-09-04',
              'stores': ['la_gallega'],
              'count': 1,
              'results': [
                {
                  'id': 'la_gallega_banco_santa_fe',
                  'store': 'la_gallega',
                  'title': 'Banco Santa Fe',
                  'benefit': '30% OFF',
                  'payment_type': 'bank',
                  'entity': 'Banco Santa Fe',
                  'percentage': 30,
                  'refund_cap': 25000,
                  'weekdays': [1, 2, 3, 4, 5, 6, 7],
                  'start_date': '2026-09-01',
                  'end_date': '2026-12-31',
                  'conditions':
                      '30% de reintegro con tarjeta fisica Banco Santa Fe.',
                  'categories': ['todos'],
                  'channel': '',
                  'valid_text': 'Todos los dias',
                  'source_url': 'https://www.lagallega.com.ar/Beneficios.asp',
                  'compatible_entities': [
                    'Banco Santa Fe',
                    'Visa',
                    'Mastercard',
                  ],
                  'compatible_payment_types': ['bank', 'card'],
                  'any_entity': false,
                  'scraped_at': '2026-09-04T00:00:00+00:00',
                },
              ],
              'warnings': <String>[],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final promotions = await repository.getPromotions(DateTime(2026, 9, 4));

      expect(promotions, hasLength(1));
      expect(promotions.single.storeId, 'lagallega');
      expect(promotions.single.tipoMedioPago, PaymentMethodType.bank);
      expect(promotions.single.porcentajeDescuento, 30);
      expect(promotions.single.topeReintegro, 25000);
      expect(promotions.single.entidadesCompatibles, contains('Visa'));
      expect(
        promotions.single.tiposMedioPagoCompatibles,
        contains(PaymentMethodType.card),
      );
    },
  );
}
