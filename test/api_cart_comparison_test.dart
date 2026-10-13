import 'dart:convert';

import 'package:conviene/models/cart_item.dart';
import 'package:conviene/models/shopping_context.dart';
import 'package:conviene/repositories/api_repository.dart';
import 'package:conviene/repositories/mock_repository.dart';
import 'package:conviene/services/discount_engine.dart';
import 'package:conviene/services/price_comparison_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> milk(String store, String name, double price) => {
  'match_type': 'exact',
  'score': 100,
  'product': {
    'store': store,
    'name': name,
    'ean': '7790742363107',
    'brand': 'La Serenisima',
    'price': price,
    'available': true,
    'scraped_at': '2026-10-02T12:00:00Z',
  },
};

Map<String, dynamic> offer(
  String store,
  String name,
  String ean,
  String brand,
  double price,
) => {
  'match_type': 'exact',
  'score': 100,
  'product': {
    'store': store,
    'name': name,
    'ean': ean,
    'brand': brand,
    'price': price,
    'available': true,
    'scraped_at': '2026-10-13T12:00:00Z',
  },
};

void main() {
  test(
    'mixed cart is complete only per product when no store has both SKUs',
    () async {
      final sweet = offer(
        'la_gallega',
        'dulce de leche la paulina x 200 gr',
        '7794990184897',
        'La Paulina',
        2079,
      );
      final condom = offer(
        'coto',
        'Preservativos Sup/Fino TULIPAN Bli 6 Uni',
        '7791014001536',
        'TULIPAN',
        6605.99,
      );
      final carrefourCondom = offer(
        'carrefour',
        'Preservativos Tulipan super fino 6 u',
        '7791014001536',
        'TULIPAN',
        7230,
      );
      final repository = ApiRepository(
        baseUrl: Uri.parse('http://localhost:8010'),
        fallback: MockRepository(),
        client: MockClient((request) async {
          if (request.url.path == '/search') {
            final query = request.url.queryParameters['q'] ?? '';
            return http.Response(
              jsonEncode({
                'results': [query.contains('dulce') ? sweet : condom],
              }),
              200,
            );
          }
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final product = body['product'] as Map<String, dynamic>;
          final isSweet = product['ean'] == '7794990184897';
          return http.Response(
            jsonEncode({
              'results': isSweet ? [sweet] : [condom, carrefourCondom],
              'store_status': isSweet
                  ? {
                      'coto': 'not_found',
                      'carrefour': 'not_found',
                      'la_gallega': 'found',
                    }
                  : {
                      'coto': 'found',
                      'carrefour': 'found',
                      'la_gallega': 'not_found',
                    },
            }),
            200,
          );
        }),
      );
      final selectedSweet = (await repository.searchProducts(
        query: 'dulce de leche',
        storeIds: {'lagallega'},
      )).single;
      final selectedCondom = (await repository.searchProducts(
        query: 'preservativo',
        storeIds: {'coto'},
      )).single;
      final result =
          await PriceComparisonService(
            repository,
            const DiscountEngine(),
          ).compareCartOptions(
            cartItems: [
              CartItem(
                productId: selectedSweet.product.id,
                quantity: 1,
                selectedStoreId: 'lagallega',
              ),
              CartItem(
                productId: selectedCondom.product.id,
                quantity: 1,
                selectedStoreId: 'coto',
              ),
            ],
            fecha: DateTime(2026, 10, 13),
            mediosPagoUsuario: const [],
            promociones: const [],
            storeIds: {'coto', 'carrefour', 'lagallega'},
          );

      expect(
        result.singleStoreComparisons.every((row) => !row.hasAllProducts),
        isTrue,
      );
      expect(
        result.singleStoreComparisons.every(
          (row) => row.foundProductsCount == 1,
        ),
        isTrue,
      );
      expect(result.selectedStoresPlan!.hasAllProducts, isTrue);
      expect(result.selectedStoresPlan!.storeCount, 2);
      expect(result.selectedStoresPlan!.totalFinal, closeTo(8684.99, 0.01));
      expect(result.bestPerProductPlan!.hasAllProducts, isTrue);
      expect(result.bestPerProductPlan!.totalFinal, closeTo(8684.99, 0.01));
      final coto = result.singleStoreComparisons.firstWhere(
        (row) => row.supermarket.id == 'coto',
      );
      expect(coto.missingLabel(selectedSweet.product), 'No verificado');
    },
  );

  test(
    'compares the official abbreviated milk names without changing the chosen store',
    () async {
      var comparisons = 0;
      final repository = ApiRepository(
        baseUrl: Uri.parse('http://localhost:8010'),
        fallback: MockRepository(),
        client: MockClient((request) async {
          if (request.url.path == '/search') {
            return http.Response(
              jsonEncode({
                'results': [
                  milk('carrefour', 'Leche La Serenisima liviana 1% 1L', 1939),
                ],
              }),
              200,
            );
          }
          expect(request.method, 'POST');
          expect(request.url.path, '/products/equivalents');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['product']['ean'], '7790742363107');
          expect(
            body['stores'],
            containsAll(['carrefour', 'coto', 'la_gallega']),
          );
          expect(body['context']['coto_store'], '200');
          comparisons++;
          return http.Response(
            jsonEncode({
              'results': [
                milk('carrefour', 'Leche La Serenisima liviana 1% 1L', 1900),
                milk(
                  'coto',
                  'Leche Larga Vida Parcialmente Descremada Liviana 1% La Serenisima 1l',
                  2915,
                ),
                milk(
                  'la_gallega',
                  'Leche larga vida la serenisima 1 % x 1 litro',
                  2838,
                ),
              ],
              'store_status': {
                'carrefour': 'found',
                'coto': 'found',
                'la_gallega': 'found',
              },
            }),
            200,
          );
        }),
      );
      final selected = (await repository.searchProducts(
        query: 'leche',
        storeIds: {'carrefour'},
      )).single;
      expect(selected.product.ean, '7790742363107');
      expect(selected.product.brand, 'La Serenisima');
      final service = PriceComparisonService(
        repository,
        const DiscountEngine(),
      );
      final result = await service.compareCartOptions(
        cartItems: [
          CartItem(
            productId: selected.product.id,
            quantity: 2,
            selectedStoreId: 'carrefour',
          ),
        ],
        fecha: DateTime(2026, 10, 2),
        mediosPagoUsuario: const [],
        promociones: const [],
        storeIds: {'coto', 'carrefour', 'lagallega'},
      );
      expect(comparisons, 1);
      expect(
        result.singleStoreComparisons.every((store) => store.hasAllProducts),
        isTrue,
      );
      expect(result.singleStoreComparisons.first.totalFinal, 3800);
      expect(result.singleStoreComparisons.last.totalFinal, 5830);
      expect(
        result.selectedStoresPlan!.items.single.supermarket.id,
        'carrefour',
      );
      expect(
        result.selectedStoresPlan!.items.single.cartProductId,
        selected.product.id,
      );
      expect(
        result.selectedStoresPlan!.totalFinal,
        3800,
      ); // Refreshes even the originally chosen store.
    },
  );

  test(
    'keeps same-EAN milk with abbreviated fat label but rejects another percentage',
    () async {
      final repository = ApiRepository(
        baseUrl: Uri.parse('http://localhost:8010'),
        fallback: MockRepository(),
        client: MockClient((request) async {
          if (request.url.path == '/search') {
            return http.Response(
              jsonEncode({
                'results': [
                  milk('carrefour', 'Leche La Serenisima liviana 1% 1L', 2000),
                ],
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'results': [
                milk('carrefour', 'Leche La Serenisima liviana 1% 1L', 2000),
                milk(
                  'la_gallega',
                  'leche la serenisima descremada x1l sachet md',
                  1900,
                ),
                milk('coto', 'Leche La Serenisima semidescremada 2% 1L', 1800),
              ],
              'store_status': {
                'carrefour': 'found',
                'la_gallega': 'found',
                'coto': 'found',
              },
            }),
            200,
          );
        }),
      );
      final selected = (await repository.searchProducts(
        query: 'leche',
        storeIds: {'carrefour'},
      )).single;
      final comparison =
          await PriceComparisonService(
            repository,
            const DiscountEngine(),
          ).compareCartOptions(
            cartItems: [
              CartItem(
                productId: selected.product.id,
                quantity: 1,
                selectedStoreId: 'carrefour',
              ),
            ],
            fecha: DateTime(2026, 10, 13),
            mediosPagoUsuario: const [],
            promociones: const [],
            storeIds: {'coto', 'carrefour', 'lagallega'},
          );
      final byStore = {
        for (final row in comparison.singleStoreComparisons)
          row.supermarket.id: row,
      };
      expect(byStore['lagallega']!.hasAllProducts, isTrue);
      expect(byStore['lagallega']!.totalFinal, 1900);
      expect(byStore['coto']!.hasAllProducts, isFalse);
    },
  );

  for (final status in ['error', 'unavailable', 'not_found']) {
    test('keeps $status distinct from fabricated offers', () async {
      final repository = ApiRepository(
        baseUrl: Uri.parse('http://localhost:8010'),
        fallback: MockRepository(),
        client: MockClient((request) async {
          if (request.url.path == '/search') {
            return http.Response(
              jsonEncode({
                'results': [
                  milk('carrefour', 'Leche La Serenisima liviana 1% 1L', 1939),
                ],
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'results': [
                milk('carrefour', 'Leche La Serenisima liviana 1% 1L', 1939),
              ],
              'store_status': {'carrefour': 'found', 'coto': status},
            }),
            200,
          );
        }),
      );
      final selected = (await repository.searchProducts(
        query: 'leche',
        storeIds: {'carrefour'},
      )).single;
      final result =
          await PriceComparisonService(
            repository,
            const DiscountEngine(),
          ).compareCart(
            cartItems: [
              CartItem(
                productId: selected.product.id,
                quantity: 1,
                selectedStoreId: 'carrefour',
              ),
            ],
            fecha: DateTime(2026, 10, 2),
            mediosPagoUsuario: const [],
            promociones: const [],
            storeIds: {'carrefour', 'coto'},
          );
      final coto = result.firstWhere((store) => store.supermarket.id == 'coto');
      expect(coto.items, isEmpty);
      expect(coto.missingStatus[selected.product.id], status);
      expect(coto.hasSourceError, status == 'error');
      expect(coto.hasAllProducts, isFalse);
      expect(
        coto.missingLabel(selected.product),
        status == 'error'
            ? 'No se pudo consultar'
            : status == 'unavailable'
            ? 'Sin stock publicado'
            : 'No verificado',
      );
    });
  }

  test('equivalence network failure never falls back to demo prices', () async {
    final repository = ApiRepository(
      baseUrl: Uri.parse('http://localhost:8010'),
      fallback: MockRepository(),
      client: MockClient((_) async => http.Response('not available', 503)),
    );
    final product = (await MockRepository().getProducts()).first;
    final response = await repository.findEquivalentProducts(
      product: product,
      storeIds: {'coto', 'lagallega'},
      context: const ShoppingContext(),
    );
    expect(response.results, isEmpty);
    expect(response.storeStatus, {'coto': 'error', 'lagallega': 'error'});
  });

  test('a failed refresh cannot retain the selected cached price', () async {
    final repository = ApiRepository(
      baseUrl: Uri.parse('http://localhost:8010'),
      fallback: MockRepository(),
      client: MockClient((request) async {
        if (request.url.path == '/search') {
          return http.Response(
            jsonEncode({
              'results': [
                milk('carrefour', 'Leche La Serenisima liviana 1% 1L', 1939),
              ],
            }),
            200,
          );
        }
        return http.Response('temporarily unavailable', 503);
      }),
    );
    final selected = (await repository.searchProducts(
      query: 'leche',
      storeIds: {'carrefour'},
    )).single;

    final result =
        await PriceComparisonService(
          repository,
          const DiscountEngine(),
        ).compareCartOptions(
          cartItems: [
            CartItem(
              productId: selected.product.id,
              quantity: 1,
              selectedStoreId: 'carrefour',
            ),
          ],
          fecha: DateTime(2026, 10, 13),
          mediosPagoUsuario: const [],
          promociones: const [],
          storeIds: {'carrefour', 'coto'},
        );

    expect(result.selectedStoresPlan!.items, isEmpty);
    expect(result.selectedStoresPlan!.missingProducts, hasLength(1));
    expect(result.bestPerProductPlan!.items, isEmpty);
    expect(
      result.singleStoreComparisons.every((row) => row.hasSourceError),
      isTrue,
    );
  });

  test(
    'persisted demo products cannot become real prices after API failure',
    () async {
      final repository = ApiRepository(
        baseUrl: Uri.parse('http://localhost:8010'),
        fallback: MockRepository(),
        client: MockClient((_) async => http.Response('unavailable', 503)),
      );
      final demo = (await MockRepository().getProducts()).first;
      final result =
          await PriceComparisonService(
            repository,
            const DiscountEngine(),
          ).compareCartOptions(
            cartItems: [CartItem(productId: demo.id, quantity: 1)],
            fecha: DateTime(2026, 10, 13),
            mediosPagoUsuario: const [],
            promociones: const [],
            storeIds: {'coto', 'carrefour', 'lagallega'},
          );

      expect(
        result.singleStoreComparisons.every((row) => row.items.isEmpty),
        isTrue,
      );
      expect(result.selectedStoresPlan!.items, isEmpty);
      expect(result.bestPerProductPlan!.items, isEmpty);
    },
  );

  test(
    'similar or conflicting barcode matches are not priced as equivalents',
    () async {
      final repository = ApiRepository(
        baseUrl: Uri.parse('http://localhost:8010'),
        fallback: MockRepository(),
        client: MockClient((request) async {
          if (request.url.path == '/search') {
            return http.Response(
              jsonEncode({
                'results': [
                  milk('carrefour', 'Leche La Serenisima liviana 1% 1L', 1939),
                ],
              }),
              200,
            );
          }
          final similar = milk(
            'coto',
            'Leche La Serenisima liviana 1% 1L',
            1800,
          );
          similar['match_type'] = 'similar';
          final wrongBarcode = milk(
            'lagallega',
            'Leche La Serenisima liviana 1% 1L',
            1700,
          );
          (wrongBarcode['product'] as Map<String, dynamic>)['ean'] =
              '7790742448309';
          return http.Response(
            jsonEncode({
              'results': [
                milk('carrefour', 'Leche La Serenisima liviana 1% 1L', 1939),
                similar,
                wrongBarcode,
              ],
              'store_status': {
                'carrefour': 'found',
                'coto': 'found',
                'la_gallega': 'found',
              },
            }),
            200,
          );
        }),
      );
      final selected = (await repository.searchProducts(
        query: 'leche',
        storeIds: {'carrefour'},
      )).single;

      final result =
          await PriceComparisonService(
            repository,
            const DiscountEngine(),
          ).compareCartOptions(
            cartItems: [
              CartItem(
                productId: selected.product.id,
                quantity: 1,
                selectedStoreId: 'carrefour',
              ),
            ],
            fecha: DateTime(2026, 10, 13),
            mediosPagoUsuario: const [],
            promociones: const [],
            storeIds: {'carrefour', 'coto', 'lagallega'},
          );

      expect(
        result.selectedStoresPlan!.items.single.supermarket.id,
        'carrefour',
      );
      expect(
        result.bestPerProductPlan!.items.single.supermarket.id,
        'carrefour',
      );
      for (final storeId in ['coto', 'lagallega']) {
        final store = result.singleStoreComparisons.firstWhere(
          (row) => row.supermarket.id == storeId,
        );
        expect(store.items, isEmpty);
        expect(store.missingLabel(selected.product), 'No verificado');
      }
    },
  );
}
