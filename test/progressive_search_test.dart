import 'dart:async';
import 'dart:convert';

import 'package:conviene/models/price_quote.dart';
import 'package:conviene/repositories/api_repository.dart';
import 'package:conviene/repositories/mock_repository.dart';
import 'package:conviene/screens/search_screen.dart';
import 'package:conviene/state/app_scope.dart';
import 'package:conviene/state/app_state.dart';
import 'package:conviene/theme/app_theme.dart';
import 'package:conviene/widgets/product_skeleton_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _searchResponse(String store, String name, {String ean = ''}) =>
    http.Response(
      jsonEncode({
        'results': [
          {
            'score': 100,
            'match_type': 'exact',
            'product': {
              'store': store,
              'name': name,
              'ean': ean,
              'price': 2000,
              'available': true,
            },
          },
        ],
        'store_status': {store: 'found'},
      }),
      200,
    );

void main() {
  test('shows a verified store before another store responds', () async {
    final coto = Completer<http.Response>();
    final carrefour = Completer<http.Response>();
    final firstUpdate = Completer<void>();
    final updates = <(List<SearchResult>, Set<String>)>[];
    final requests = <String>[];
    final repository = ApiRepository(
      baseUrl: Uri.parse('http://127.0.0.1:8000'),
      fallback: MockRepository(),
      client: MockClient((request) {
        final store = request.url.queryParametersAll['stores']!.single;
        requests.add(store);
        return store == 'coto' ? coto.future : carrefour.future;
      }),
    );

    final search = repository.searchProductsProgressively(
      query: 'leche entera',
      storeIds: {'coto', 'carrefour'},
      onProgress: (rows, pending) {
        updates.add((rows, pending));
        if (rows.any((row) => row.supermarket.id == 'coto') &&
            !firstUpdate.isCompleted) {
          firstUpdate.complete();
        }
      },
    );
    coto.complete(_searchResponse('coto', 'Leche entera 1 L'));
    await firstUpdate.future.timeout(const Duration(seconds: 2));
    expect(updates.last.$1, hasLength(1));
    expect(updates.last.$2, {'carrefour'});

    carrefour.complete(_searchResponse('carrefour', 'Leche entera 1 L'));
    final finalRows = await search;
    expect(finalRows, hasLength(2));
    expect(updates.last.$2, isEmpty);
    expect(requests, containsAll(['coto', 'carrefour']));
    expect(requests, hasLength(2));
  });

  test('keeps healthy results when one store fails', () async {
    final repository = ApiRepository(
      baseUrl: Uri.parse('http://127.0.0.1:8000'),
      fallback: MockRepository(),
      client: MockClient((request) async {
        final store = request.url.queryParametersAll['stores']!.single;
        return store == 'coto'
            ? http.Response('unavailable', 503)
            : _searchResponse('carrefour', 'Leche entera 1 L');
      }),
    );
    final rows = await repository.searchProductsProgressively(
      query: 'leche entera',
      storeIds: {'coto', 'carrefour'},
      onProgress: (_, _) {},
    );
    expect(rows, hasLength(1));
    expect(repository.lastSearchWarning, contains('Coto'));
  });

  test(
    'EAN still gets cross-store name matches after early exact result',
    () async {
      final requests = <Set<String>>[];
      final repository = ApiRepository(
        baseUrl: Uri.parse('http://127.0.0.1:8000'),
        fallback: MockRepository(),
        client: MockClient((request) async {
          final stores = request.url.queryParametersAll['stores']!.toSet();
          requests.add(stores);
          if (stores.length == 2) {
            return http.Response(
              jsonEncode({
                'results': [
                  ...(jsonDecode(
                        _searchResponse(
                          'coto',
                          'Leche Ilolay 1 L',
                          ean: '7790787002528',
                        ).body,
                      )['results']
                      as List<dynamic>),
                  {
                    'score': 90,
                    'match_type': 'name_match',
                    'product': {
                      'store': 'carrefour',
                      'name': 'Leche Ilolay 1 L',
                      'price': 2300,
                      'available': true,
                    },
                  },
                ],
                'store_status': {'coto': 'found', 'carrefour': 'found'},
              }),
              200,
            );
          }
          return stores.single == 'coto'
              ? _searchResponse(
                  'coto',
                  'Leche Ilolay 1 L',
                  ean: '7790787002528',
                )
              : http.Response(
                  jsonEncode({
                    'results': <Object>[],
                    'store_status': {'carrefour': 'not_found'},
                  }),
                  200,
                );
        }),
      );
      final seen = <List<SearchResult>>[];
      final rows = await repository.searchProductsProgressively(
        query: '7790787002528',
        storeIds: {'coto', 'carrefour'},
        onProgress: (partial, _) => seen.add(partial),
      );
      expect(seen.any((partial) => partial.length == 1), isTrue);
      expect(
        rows.map((row) => row.supermarket.id),
        containsAll(['coto', 'carrefour']),
      );
      expect(
        requests.any((stores) => stores.containsAll({'coto', 'carrefour'})),
        isTrue,
      );
    },
  );

  test('an incomplete EAN fallback does not erase a healthy store', () async {
    final repository = ApiRepository(
      baseUrl: Uri.parse('http://127.0.0.1:8000'),
      fallback: MockRepository(),
      client: MockClient((request) async {
        final stores = request.url.queryParametersAll['stores']!.toSet();
        if (stores.length == 2) {
          return _searchResponse(
            'coto',
            'Leche Ilolay 1 L',
            ean: '7790787002528',
          );
        }
        return stores.single == 'coto'
            ? _searchResponse('coto', 'Leche Ilolay 1 L', ean: '7790787002528')
            : _searchResponse('carrefour', 'Leche Ilolay 1 L');
      }),
    );
    final results = await repository.searchProductsProgressively(
      query: '7790787002528',
      storeIds: {'coto', 'carrefour'},
      onProgress: (_, _) {},
    );
    expect(
      results.map((row) => row.supermarket.id),
      containsAll(['coto', 'carrefour']),
    );
  });

  test(
    'EAN fallback cannot replace an already exact store with a name match',
    () async {
      final repository = ApiRepository(
        baseUrl: Uri.parse('http://127.0.0.1:8000'),
        fallback: MockRepository(),
        client: MockClient((request) async {
          final stores = request.url.queryParametersAll['stores']!.toSet();
          if (stores.length == 2) {
            return http.Response(
              jsonEncode({
                'results': [
                  ...((jsonDecode(
                        _searchResponse('coto', 'Sprite parecida 500 ml').body,
                      )['results'])
                      as List<dynamic>),
                  ...((jsonDecode(
                        _searchResponse(
                          'carrefour',
                          'Sprite 500 ml',
                          ean: '7790895000829',
                        ).body,
                      )['results'])
                      as List<dynamic>),
                ],
                'store_status': {'coto': 'found', 'carrefour': 'found'},
              }),
              200,
            );
          }
          return stores.single == 'carrefour'
              ? _searchResponse(
                  'carrefour',
                  'Sprite 500 ml',
                  ean: '7790895000829',
                )
              : http.Response(
                  jsonEncode({
                    'results': <Object>[],
                    'store_status': {'coto': 'not_found'},
                  }),
                  200,
                );
        }),
      );
      final results = await repository.searchProductsProgressively(
        query: '7790895000829',
        storeIds: {'coto', 'carrefour'},
        onProgress: (_, _) {},
      );
      expect(
        results
            .singleWhere((row) => row.supermarket.id == 'carrefour')
            .product
            .ean,
        '7790895000829',
      );
      expect(results.map((row) => row.supermarket.id), contains('coto'));
    },
  );

  test(
    'EAN identification still runs when every store misses the code',
    () async {
      final requests = <Set<String>>[];
      final repository = ApiRepository(
        baseUrl: Uri.parse('http://127.0.0.1:8000'),
        fallback: MockRepository(),
        client: MockClient((request) async {
          final stores = request.url.queryParametersAll['stores']!.toSet();
          requests.add(stores);
          if (stores.length == 2) {
            return _searchResponse('carrefour', 'Sprite 500 ml');
          }
          return http.Response(
            jsonEncode({
              'results': <Object>[],
              'store_status': {stores.single: 'not_found'},
            }),
            200,
          );
        }),
      );
      final progress = <Set<String>>[];
      final results = await repository.searchProductsProgressively(
        query: '7790895000829',
        storeIds: {'coto', 'carrefour'},
        onProgress: (_, pending) => progress.add(pending),
      );
      expect(results.map((row) => row.supermarket.id), contains('carrefour'));
      expect(requests.any((stores) => stores.length == 2), isTrue);
      expect(progress.any((pending) => pending.contains('carrefour')), isTrue);
      expect(progress.last, isEmpty);
    },
  );

  test(
    'AppState exposes early products and ignores a superseded search',
    () async {
      final slow = Completer<http.Response>();
      final early = Completer<http.Response>();
      final first = Completer<void>();
      final repository = ApiRepository(
        baseUrl: Uri.parse('http://127.0.0.1:8000'),
        fallback: MockRepository(),
        client: MockClient((request) {
          final query = request.url.queryParameters['q'];
          final store = request.url.queryParametersAll['stores']!.single;
          if (query == 'leche entera') {
            return store == 'coto' ? early.future : slow.future;
          }
          return Future.value(_searchResponse(store, 'Arroz largo fino'));
        }),
      );
      final state = AppState(repository: repository);
      state.selectedStoreIds = {'coto', 'carrefour'};
      state.addListener(() {
        if (state.searchResults.any(
          (row) => row.product.name == 'Leche entera',
        )) {
          if (!first.isCompleted) first.complete();
        }
      });
      final oldSearch = state.searchProducts('leche entera');
      early.complete(_searchResponse('coto', 'Leche entera'));
      await first.future.timeout(const Duration(seconds: 2));
      expect(
        state.productById(state.searchResults.first.product.id),
        isNotNull,
      );
      expect(state.searchPendingStoreIds, {'carrefour'});
      await state.searchProducts('arroz largo fino');
      slow.complete(_searchResponse('carrefour', 'Leche entera'));
      await oldSearch;
      expect(
        state.searchResults.every(
          (row) => row.product.name == 'Arroz largo fino',
        ),
        isTrue,
      );
      expect(state.searchPendingStoreIds, isEmpty);
      state.dispose();
    },
  );

  testWidgets('skeletons yield to results without hiding ready cards', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final state = AppState(repository: MockRepository());
    state.selectedStoreIds = {'coto', 'carrefour'};
    state.isSearching = true;
    state.searchPendingStoreIds = {'coto', 'carrefour'};
    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: MaterialApp(
          home: Scaffold(body: SearchScreen(onBack: () {})),
        ),
      ),
    );
    expect(find.byType(ProductSkeletonCard), findsNWidgets(2));
    final rowsFuture = MockRepository().searchProducts(
      query: 'leche entera',
      storeIds: {'coto'},
    );
    await tester.pump(const Duration(milliseconds: 200));
    final rows = await rowsFuture;
    state.searchResults = rows.take(1).toList();
    state.searchPendingStoreIds = {'carrefour'};
    state.notifyListeners();
    await tester.pump();
    expect(find.byType(ProductSkeletonCard), findsOneWidget);
    expect(find.text(rows.first.product.name), findsWidgets);
    state.searchPendingStoreIds = {};
    state.notifyListeners();
    await tester.pump();
    expect(find.byType(ProductSkeletonCard), findsNothing);
    state.isSearching = false;
    state.searchPendingStoreIds = {};
    state.notifyListeners();
    await tester.pump();
    expect(find.byType(ProductSkeletonCard), findsNothing);
    state.dispose();
  });

  testWidgets('skeleton fits narrow dark mode and reduced motion', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(dark: true),
        home: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(body: ProductSkeletonCard()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ProductSkeletonCard), findsOneWidget);
    expect(tester.takeException(), isNull);
    buildAppTheme();
  });
}
