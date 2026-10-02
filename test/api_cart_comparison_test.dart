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

void main() {
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
            : 'No encontrado',
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
}
