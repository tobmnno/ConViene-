import 'dart:async';
import 'dart:convert';

import 'package:conviene/models/product.dart';
import 'package:conviene/models/price_quote.dart';
import 'package:conviene/models/shopping_context.dart';
import 'package:conviene/repositories/community_price_repository.dart';
import 'package:conviene/repositories/mock_repository.dart';
import 'package:conviene/repositories/product_equivalence_repository.dart';
import 'package:conviene/repositories/progressive_search_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'community wrapper forwards official results before all stores finish',
    () async {
      final source = _ControlledProgressiveRepository();
      final communityReply = Completer<http.Response>();
      final client = SupabaseClient(
        'https://example.supabase.co',
        'sb_publishable_test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) => communityReply.future),
      );
      addTearDown(client.dispose);
      final repository = CommunityPriceRepository(source, client);
      final updates = <(List<SearchResult>, Set<String>)>[];
      final search = repository.searchProductsProgressively(
        query: 'leche entera',
        storeIds: {'coto', 'carrefour'},
        onProgress: (rows, pending) => updates.add((rows, pending)),
      );
      await source.partialSent.future.timeout(const Duration(seconds: 2));
      expect(updates.last.$1, isNotEmpty);
      expect(updates.last.$2, {'carrefour'});
      source.finish.complete();
      communityReply.complete(
        http.Response('[]', 200, headers: {'content-type': 'application/json'}),
      );
      final results = await search;
      expect(results, isNotEmpty);
      expect(updates.last.$2, isEmpty);
    },
  );

  test(
    'shows a shared price with its author and keeps it in the cart cache',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'sb_publishable_test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode([
              {
                'id': '43b78369-0fbd-4219-ab68-a62beb610e9e',
                'supermarket_id': 'coto',
                'name': 'Dulce de leche La Paulina',
                'brand': 'La Paulina',
                'presentation': '400 g',
                'unit': 'unidad',
                'category': 'Almacen',
                'ean': '',
                'image_url': 'https://example.com/dulce.png',
                'source_url': '',
                'price': 2499.50,
                'unit_price': 2499.50,
                'in_stock': true,
                'created_by': '4e705ebb-5acb-4af2-b89a-08f9c5078a4a',
                'username': 'lucia',
                'updated_at': '2026-10-16T10:00:00Z',
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final repository = CommunityPriceRepository(MockRepository(), client);

      final results = await repository.searchProducts(
        query: 'Dulce de leche',
        storeIds: {'coto'},
      );
      final contribution = results.singleWhere((item) => item.isCommunityPrice);

      expect(contribution.contributorName, 'lucia');
      expect(contribution.price.priceOriginal, 2499.50);
      expect(contribution.supermarket.id, 'coto');
      expect(await repository.getPricesForProduct(contribution.product.id), [
        contribution.price,
      ]);
      expect(requests.single.url.path, '/rest/v1/rpc/search_community_prices');
    },
  );

  test(
    'sends only editable price fields when updating a contribution',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'sb_publishable_test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({'id': '43b78369-0fbd-4219-ab68-a62beb610e9e'}),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final repository = CommunityPriceRepository(MockRepository(), client);

      await repository.saveContribution(
        id: '43b78369-0fbd-4219-ab68-a62beb610e9e',
        supermarketId: 'coto',
        name: 'Dulce de leche La Paulina',
        brand: 'La Paulina',
        presentation: '400 g',
        unit: 'unidad',
        category: 'Almacen',
        ean: '',
        imageUrl: '',
        sourceUrl: '',
        price: 2600,
        unitPrice: 2600,
        inStock: true,
      );

      expect(requests.single.method, 'PATCH');
      final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(body['price'], 2600);
      expect(body, isNot(contains('created_by')));
      expect(body, isNot(contains('updated_by')));
      expect(body, isNot(contains('supermarket_id')));
    },
  );

  test(
    'keeps a shared cart offer when the official comparison fails',
    () async {
      final client = SupabaseClient(
        'https://example.supabase.co',
        'sb_publishable_test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient(
          (request) async => http.Response(
            jsonEncode([
              {
                'id': '43b78369-0fbd-4219-ab68-a62beb610e9e',
                'supermarket_id': 'coto',
                'name': 'Dulce de leche La Paulina',
                'brand': 'La Paulina',
                'presentation': '400 g',
                'unit': 'unidad',
                'category': 'Almacen',
                'ean': '',
                'image_url': '',
                'source_url': '',
                'price': 2499.50,
                'unit_price': 2499.50,
                'in_stock': true,
                'created_by': '4e705ebb-5acb-4af2-b89a-08f9c5078a4a',
                'username': 'lucia',
                'updated_at': '2026-10-16T10:00:00Z',
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          ),
        ),
      );
      addTearDown(client.dispose);
      final repository = CommunityPriceRepository(
        _FailingEquivalenceRepository(),
        client,
      );

      final result = await repository.findEquivalentProducts(
        product: const Product(
          id: 'community_43b78369-0fbd-4219-ab68-a62beb610e9e',
          ean: '',
          name: 'Dulce de leche La Paulina',
          brand: 'La Paulina',
          presentation: '400 g',
          unit: 'unidad',
          category: 'Almacen',
          imageTag: 'producto',
        ),
        storeIds: {'coto', 'carrefour'},
        context: const ShoppingContext(),
      );

      expect(result.results.single.price.priceOriginal, 2499.50);
      expect(result.storeStatus['coto'], 'found');
      expect(result.storeStatus['carrefour'], 'error');
    },
  );

  test('keeps community results when official search is unavailable', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'sb_publishable_test',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode([
            {
              'id': '43b78369-0fbd-4219-ab68-a62beb610e9e',
              'supermarket_id': 'coto',
              'name': 'Sprite 500 ml',
              'brand': 'Sprite',
              'presentation': '500 ml',
              'unit': 'unidad',
              'price': 1200,
              'unit_price': 1200,
              'in_stock': true,
              'updated_at': '2026-10-19T10:00:00Z',
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );
    addTearDown(client.dispose);
    final repository = CommunityPriceRepository(
      _FailingSearchRepository(),
      client,
    );

    final results = await repository.searchProducts(
      query: 'Sprite',
      storeIds: {'coto'},
    );

    expect(results.single.product.name, 'Sprite 500 ml');
    expect(repository.lastSearchWarning, contains('catálogos oficiales'));
  });

  test('finds a shared EAN even when its name differs', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'sb_publishable_test',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        final params = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode(
            params['query_text'] == '779089500829'
                ? [
                    {
                      'id': '43b78369-0fbd-4219-ab68-a62beb610e9e',
                      'supermarket_id': 'carrefour',
                      'name': 'Gaseosa Sprite Lima Limon',
                      'brand': 'Sprite',
                      'presentation': '500 cc',
                      'unit': 'unidad',
                      'ean': '779089500829',
                      'price': 1350,
                      'unit_price': 1350,
                      'in_stock': true,
                      'updated_at': '2026-10-19T10:00:00Z',
                    },
                  ]
                : [],
          ),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    final repository = CommunityPriceRepository(
      _FailingEquivalenceRepository(),
      client,
    );

    final result = await repository.findEquivalentProducts(
      product: const Product(
        id: 'sprite',
        ean: '779089500829',
        name: 'Sprite 500 ml',
        brand: 'Sprite',
        presentation: '500 ml',
        unit: 'unidad',
        category: 'Bebidas',
        imageTag: 'producto',
      ),
      storeIds: {'carrefour'},
      context: const ShoppingContext(),
    );

    expect(result.results.single.supermarket.id, 'carrefour');
    expect(result.storeStatus['carrefour'], 'found');
  });

  test(
    'starts official, name and EAN comparisons without waiting in series',
    () async {
      final source = _PendingEquivalenceRepository();
      final twoCommunityRequests = Completer<void>();
      var communityRequests = 0;
      final client = SupabaseClient(
        'https://example.supabase.co',
        'sb_publishable_test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          communityRequests++;
          if (communityRequests == 2) twoCommunityRequests.complete();
          return http.Response(
            '[]',
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final repository = CommunityPriceRepository(source, client);
      final comparison = repository.findEquivalentProducts(
        product: const Product(
          id: 'sprite',
          ean: '779089500829',
          name: 'Sprite 500 ml',
          brand: 'Sprite',
          presentation: '500 ml',
          unit: 'unidad',
          category: 'Bebidas',
          imageTag: 'producto',
        ),
        storeIds: {'coto'},
        context: const ShoppingContext(),
      );
      await Future.wait([
        source.started.future,
        twoCommunityRequests.future,
      ]).timeout(const Duration(seconds: 2));
      source.complete();
      final result = await comparison;
      expect(result.storeStatus['coto'], 'not_found');
      expect(communityRequests, 2);
    },
  );
}

class _FailingSearchRepository extends MockRepository {
  @override
  Future<List<SearchResult>> searchProducts({
    required String query,
    required Set<String> storeIds,
    ShoppingContext context = const ShoppingContext(),
  }) async => throw StateError('Scraper unavailable');
}

class _ControlledProgressiveRepository extends MockRepository
    implements ProgressiveSearchRepository {
  final partialSent = Completer<void>();
  final finish = Completer<void>();

  @override
  Future<List<SearchResult>> searchProductsProgressively({
    required String query,
    required Set<String> storeIds,
    required SearchProgress onProgress,
    ShoppingContext context = const ShoppingContext(),
  }) async {
    final rows = await super.searchProducts(
      query: query,
      storeIds: storeIds,
      context: context,
    );
    onProgress(rows.take(1).toList(), {'carrefour'});
    partialSent.complete();
    await finish.future;
    onProgress(rows, const {});
    return rows;
  }
}

class _FailingEquivalenceRepository extends MockRepository
    implements ProductEquivalenceRepository {
  @override
  Future<EquivalentProductsResult> findEquivalentProducts({
    required Product product,
    required Set<String> storeIds,
    required ShoppingContext context,
  }) async => throw StateError('Scraper unavailable');
}

class _PendingEquivalenceRepository extends MockRepository
    implements ProductEquivalenceRepository {
  final started = Completer<void>();
  final _result = Completer<EquivalentProductsResult>();

  @override
  Future<EquivalentProductsResult> findEquivalentProducts({
    required Product product,
    required Set<String> storeIds,
    required ShoppingContext context,
  }) {
    started.complete();
    return _result.future;
  }

  void complete() => _result.complete(
    const EquivalentProductsResult(
      results: [],
      storeStatus: {'coto': 'not_found'},
    ),
  );
}
