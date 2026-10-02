import 'dart:convert';

import 'package:conviene/models/payment_method.dart';
import 'package:conviene/models/shopping_context.dart';
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
                'match_type': 'exact',
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
    expect(results.single.relevanceScore, 98.4);
    expect(results.single.isExactMatch, isTrue);

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

  test('sends the selected purchase context to the scraper API', () async {
    final repository = ApiRepository(
      baseUrl: Uri.parse('http://127.0.0.1:8000'),
      fallback: MockRepository(),
      client: MockClient((request) async {
        expect(request.url.queryParameters['postal_code'], '2000');
        expect(request.url.queryParameters['fulfillment'], 'delivery');
        expect(request.url.queryParameters['coto_store'], '401');
        expect(request.url.queryParameters['carrefour_sales_channel'], '2');
        expect(request.url.queryParameters['latitude'], '-32.95');
        expect(request.url.queryParameters['longitude'], '-60.65');
        return http.Response(
          jsonEncode({
            'query': 'leche',
            'stores': ['coto'],
            'count': 0,
            'results': <Object>[],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final results = await repository.searchProducts(
      query: 'leche',
      storeIds: {'coto'},
      context: const ShoppingContext(
        postalCode: '2000',
        fulfillment: FulfillmentMode.delivery,
        cotoStore: '401',
        carrefourSalesChannel: '2',
        latitude: -32.95,
        longitude: -60.65,
      ),
    );

    expect(results, isEmpty);
  });

  test('uses the nearest configured Coto branch suggestion', () async {
    final repository = ApiRepository(
      baseUrl: Uri.parse('http://127.0.0.1:8000'),
      fallback: MockRepository(),
      client: MockClient((request) async {
        expect(request.url.path, '/stores/nearby');
        expect(request.url.queryParameters['latitude'], '-32.95');
        expect(request.url.queryParameters['longitude'], '-60.65');
        return http.Response(
          jsonEncode({
            'suggestions': [
              {'id': '401', 'name': 'Coto Centro', 'distance_km': 1.2},
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final suggestion = await repository.findNearbyCotoStore(
      latitude: -32.95,
      longitude: -60.65,
    );

    expect(suggestion?.storeId, '401');
    expect(suggestion?.name, 'Coto Centro');
    expect(suggestion?.distanceKm, 1.2);
  });

  test('does not reuse prices after the purchase context changes', () async {
    final repository = ApiRepository(
      baseUrl: Uri.parse('http://127.0.0.1:8000'),
      fallback: MockRepository(),
      client: MockClient((request) async {
        final price = request.url.queryParameters['coto_store'] == '401'
            ? 2000
            : 1500;
        return http.Response(
          jsonEncode({
            'query': 'leche',
            'stores': ['coto'],
            'count': 1,
            'results': [
              {
                'product': {
                  'id': 'leche-prueba',
                  'store': 'coto',
                  'name': 'Leche prueba 1 L',
                  'price': price,
                  'available': true,
                },
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final first = await repository.searchProducts(
      query: 'leche',
      storeIds: {'coto'},
      context: const ShoppingContext(cotoStore: '200'),
    );
    expect(
      (await repository.getPricesForProduct(
        first.single.product.id,
      )).single.priceOriginal,
      1500,
    );

    final second = await repository.searchProducts(
      query: 'leche',
      storeIds: {'coto'},
      context: const ShoppingContext(cotoStore: '401'),
    );
    expect(
      (await repository.getPricesForProduct(
        second.single.product.id,
      )).single.priceOriginal,
      2000,
    );
  });

  test('recognizes compact litre and gram presentations from stores', () async {
    final repository = ApiRepository(
      baseUrl: Uri.parse('http://127.0.0.1:8000'),
      fallback: MockRepository(),
      client: MockClient(
        (request) async => http.Response(
          jsonEncode({
            'results': [
              {
                'product': {
                  'id': 'leche-1l',
                  'store': 'coto',
                  'name': 'Leche prueba 1l',
                  'price': 2050,
                  'available': true,
                },
              },
              {
                'product': {
                  'id': 'cafe-400g',
                  'store': 'coto',
                  'name': 'Cafe prueba 400g',
                  'price': 4000,
                  'available': true,
                },
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );

    final results = await repository.searchProducts(
      query: 'prueba',
      storeIds: {'coto'},
    );

    expect(results[0].product.unit, 'L');
    expect(results[0].price.priceUnitario, 2050);
    expect(results[1].product.unit, 'kg');
    expect(results[1].price.priceUnitario, 10000);
  });

  test('keeps an empty valid discounts response without mock data', () async {
    final repository = ApiRepository(
      baseUrl: Uri.parse('http://127.0.0.1:8000'),
      fallback: MockRepository(),
      client: MockClient(
        (request) async => http.Response(
          jsonEncode({
            'date': '2026-10-01',
            'stores': ['carrefour', 'coto', 'la_gallega'],
            'count': 0,
            'results': <Object>[],
            'warnings': <String>[],
          }),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );

    final promotions = await repository.getPromotions(DateTime(2026, 10, 1));

    expect(promotions, isEmpty);
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
                  'minimum_purchase': 90000,
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
                  'required_entity_groups': [
                    ['Banco Santa Fe'],
                    ['Visa', 'Mastercard'],
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
      expect(promotions.single.compraMinima, 90000);
      expect(promotions.single.entidadesCompatibles, contains('Visa'));
      expect(promotions.single.entidadesRequeridas, hasLength(2));
      expect(
        promotions.single.tiposMedioPagoCompatibles,
        contains(PaymentMethodType.card),
      );
    },
  );
}
