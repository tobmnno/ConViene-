import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:conviene/models/product.dart';
import 'package:conviene/models/price_quote.dart';
import 'package:conviene/models/shopping_context.dart';
import 'package:conviene/repositories/mock_repository.dart';
import 'package:conviene/repositories/product_equivalence_repository.dart';
import 'package:conviene/services/product_comparison_service.dart';
import 'package:conviene/state/app_state.dart';
import 'package:conviene/state/app_scope.dart';
import 'package:conviene/widgets/product_comparison_trigger.dart';
import 'package:conviene/widgets/product_comparison_panel.dart';
import 'package:conviene/models/payment_method.dart';
import 'package:conviene/models/discount.dart';

const milk = Product(
  id: 'milk',
  ean: '7790742448309',
  name: 'Leche entera 1 L',
  brand: 'Ilolay',
  presentation: '1 L',
  unit: 'L',
  category: 'lacteos',
  imageTag: 'milk',
);

class ComparisonRepository extends MockRepository
    implements ProductEquivalenceRepository {
  int calls = 0;
  Set<String>? stores;
  Completer<EquivalentProductsResult>? pending;
  @override
  Future<EquivalentProductsResult> findEquivalentProducts({
    required Product product,
    required Set<String> storeIds,
    required ShoppingContext context,
  }) async {
    calls++;
    stores = storeIds;
    if (pending != null) return pending!.future;
    return EquivalentProductsResult(
      results: [
        SearchResult(
          product: product,
          price: ProductPrice(
            storeId: 'coto',
            productId: product.id,
            priceOriginal: 1500,
            priceUnitario: 1500,
            stock: true,
            url: 'https://www.coto.com.ar/productos/leche',
            fechaActualizacion: DateTime.now(),
            pricingScope: 'selected_store',
          ),
          supermarket: (await getSupermarkets()).first,
        ),
      ],
      storeStatus: const {
        'coto': 'found',
        'carrefour': 'error',
        'lagallega': 'not_found',
      },
    );
  }
}

void main() {
  test(
    'personalized ordering changes with cards, caps, minimums and dates',
    () async {
      final repo = ComparisonRepository();
      final stores = await repo.getSupermarkets();
      final state = AppState(
        repository: repo,
        initialDate: DateTime(2026, 10, 23),
      );
      final rows = [
        for (final store in stores.take(2))
          SearchResult(
            product: milk,
            supermarket: store,
            price: ProductPrice(
              storeId: store.id,
              productId: milk.id,
              priceOriginal: store.id == 'coto' ? 100 : 110,
              priceUnitario: 100,
              stock: true,
              url: '',
              fechaActualizacion: DateTime.now(),
            ),
          ),
      ];
      state.paymentMethods = [];
      final promo = Promotion(
        id: 'bank',
        storeId: 'carrefour',
        tipoMedioPago: PaymentMethodType.card,
        entidad: 'Visa',
        porcentajeDescuento: 20,
        topeReintegro: 100,
        diasSemana: const {5},
        fechaInicio: DateTime(2026, 10, 1),
        fechaFin: DateTime(2026, 10, 31),
        condiciones: 'Reintegro',
        categorias: const ['todos'],
        applicabilityScope: 'general_confirmed',
        compraMinima: 200,
        capFrequency: 'monthly',
      );
      state.promotions = [promo];
      expect(sortedProductOffers(state, rows).first.supermarket.id, 'coto');
      state.paymentMethods = [
        const PaymentMethod(
          id: 'visa',
          type: PaymentMethodType.card,
          entity: 'Visa',
          displayName: 'Visa',
          active: true,
        ),
      ];
      expect(sortedProductOffers(state, rows).first.supermarket.id, 'coto');
      expect(
        sortedProductOffers(state, rows, quantity: 2).first.supermarket.id,
        'carrefour',
      );
      expect(state.discountForResult(rows.last, quantity: 2).estimated, isTrue);
      state.usedRefundCaps[promo.capUsageKey(state.selectedDate)!] = 100;
      expect(
        sortedProductOffers(state, rows, quantity: 2).first.supermarket.id,
        'coto',
      );
      state.usedRefundCaps.clear();
      state.selectedDate = DateTime(2026, 11, 6);
      expect(
        sortedProductOffers(state, rows, quantity: 2).first.supermarket.id,
        'coto',
      );
      state.dispose();
    },
  );

  testWidgets(
    'fast hover does not request; keyboard opens; child actions stay independent',
    (tester) async {
      final repo = ComparisonRepository();
      final state = AppState(repository: repo);
      var favorite = 0;
      await tester.pumpWidget(
        AppScope(
          notifier: state,
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: ProductComparisonTrigger(
                  product: milk,
                  child: SizedBox(
                    width: 260,
                    height: 140,
                    child: Column(
                      children: [
                        const Text('Tarjeta'),
                        IconButton(
                          tooltip: 'Favorito',
                          onPressed: () => favorite++,
                          icon: const Icon(Icons.favorite),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.text('Tarjeta')));
      await tester.pump(const Duration(milliseconds: 100));
      await mouse.moveTo(Offset.zero);
      await tester.pump(const Duration(milliseconds: 400));
      expect(repo.calls, 0);
      await tester.tap(find.byTooltip('Favorito'));
      await tester.pump();
      expect(favorite, 1);
      expect(repo.calls, 0);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('No se pudo consultar'), findsOneWidget);
      expect(state.cartItems, isEmpty);
      Navigator.of(tester.element(find.text('No se pudo consultar'))).pop();
      await tester.pumpAndSettle();
      await mouse.removePointer();
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );
  test(
    'deduplicates requests, expires cache and separates purchase contexts',
    () async {
      final repository = ComparisonRepository()..pending = Completer();
      var now = DateTime(2026, 10, 22);
      final service = ProductComparisonService(repository, clock: () => now);
      final first = service.compare(milk, const ShoppingContext());
      final second = service.compare(milk, const ShoppingContext());
      expect(repository.calls, 1);
      repository.pending!.complete(
        const EquivalentProductsResult(
          results: [],
          storeStatus: {
            'coto': 'not_found',
            'carrefour': 'not_found',
            'lagallega': 'not_found',
          },
        ),
      );
      await Future.wait([first, second]);
      await service.compare(milk, const ShoppingContext());
      expect(repository.calls, 1);
      now = now.add(const Duration(minutes: 6));
      await service.compare(milk, const ShoppingContext());
      await service.compare(milk, const ShoppingContext(cotoStore: '401'));
      expect(repository.calls, 3);
      expect(repository.stores, {'coto', 'carrefour', 'lagallega'});
    },
  );

  test(
    'preserves partial responses and explicitly retries source errors',
    () async {
      final repository = ComparisonRepository();
      final service = ProductComparisonService(repository);
      final result = await service.compare(milk, const ShoppingContext());
      expect(result.storeStatus['carrefour'], 'error');
      expect(result.results.single.product.ean, milk.ean);
      await service.compare(milk, const ShoppingContext());
      expect(repository.calls, 1);
      await service.compare(milk, const ShoppingContext(), refresh: true);
      expect(repository.calls, 2);
    },
  );

  test(
    'an edited contribution invalidates old and in-flight comparisons',
    () async {
      final repository = ComparisonRepository()..pending = Completer();
      final service = ProductComparisonService(repository);
      final oldRequest = service.compare(milk, const ShoppingContext());
      service.invalidateCache();
      final oldPending = repository.pending!;
      repository.pending = Completer();
      final newRequest = service.compare(milk, const ShoppingContext());
      expect(repository.calls, 2);
      repository.pending!.complete(
        const EquivalentProductsResult(
          results: [],
          storeStatus: {'coto': 'not_found'},
        ),
      );
      await newRequest;
      oldPending.complete(
        const EquivalentProductsResult(
          results: [],
          storeStatus: {'coto': 'error'},
        ),
      );
      await oldRequest;
      final current = await service.compare(milk, const ShoppingContext());
      expect(repository.calls, 2);
      expect(current.storeStatus['coto'], 'not_found');
    },
  );

  testWidgets(
    'tap and hover compare without modifying cart or filters; Escape closes',
    (tester) async {
      final repository = ComparisonRepository();
      final state = AppState(repository: repository)
        ..selectedStoreIds = {'coto'};
      await tester.pumpWidget(
        AppScope(
          notifier: state,
          child: const MaterialApp(
            home: Scaffold(
              body: Center(
                child: ProductComparisonTrigger(
                  product: milk,
                  child: SizedBox(
                    width: 250,
                    height: 100,
                    child: Text('Producto'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Producto'));
      await tester.pumpAndSettle();
      expect(find.text('No se pudo consultar'), findsOneWidget);
      expect(state.cartItems, isEmpty);
      expect(state.selectedStoreIds, {'coto'});
      Navigator.of(tester.element(find.text('No se pudo consultar'))).pop();
      await tester.pumpAndSettle();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.text('Producto')));
      await tester.pump(const Duration(milliseconds: 360));
      await tester.pumpAndSettle();
      expect(find.text('No se pudo consultar'), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(ProductComparisonPanel)).dy,
        greaterThan(tester.getBottomLeft(find.text('Producto')).dy),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('No se pudo consultar'), findsNothing);
      await mouse.removePointer();
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );
}
