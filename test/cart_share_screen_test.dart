import 'package:conviene/models/cart_item.dart';
import 'package:conviene/models/discount.dart';
import 'package:conviene/models/price_quote.dart';
import 'package:conviene/models/product.dart';
import 'package:conviene/models/store_comparison.dart';
import 'package:conviene/models/supermarket.dart';
import 'package:conviene/repositories/mock_repository.dart';
import 'package:conviene/screens/cart_screen.dart';
import 'package:conviene/screens/cart_share_screen.dart';
import 'package:conviene/screens/store_comparison_screen.dart';
import 'package:conviene/state/app_scope.dart';
import 'package:conviene/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _store = Supermarket(
  id: 'coto',
  name: 'Coto',
  shortName: 'COTO',
  enabled: true,
  brandColor: 0xFFE42127,
  websiteUrl: '',
  logoAsset: '',
);

const _product = Product(
  id: 'test-condom',
  ean: '7791014001536',
  name: 'Preservativos Tulipan superfino 6 u',
  brand: 'Tulipan',
  presentation: '6 u',
  unit: 'u',
  category: 'higiene',
  imageTag: '',
);

void main() {
  testWidgets('la imagen compartible no inventa un total sin precios', (
    tester,
  ) async {
    final state = AppState(repository: MockRepository())
      ..supermarkets = [_store]
      ..products = [_product]
      ..cartItems = const [
        CartItem(
          productId: 'test-condom',
          quantity: 1,
          selectedStoreId: 'coto',
        ),
      ];
    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: const MaterialApp(home: CartShareScreen()),
      ),
    );

    expect(find.text('Subtotal verificado'), findsOneWidget);
    expect(find.text('Sin precios'), findsOneWidget);
    expect(
      find.textContaining('Coto · x1 · precio no verificado'),
      findsOneWidget,
    );
    state.dispose();
  });

  testWidgets(
    'changuito mixto no dice que no hay precios ni muestra ahorro cero',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final line = PricedCartItem(
        product: _product,
        supermarket: _store,
        quantity: 1,
        price: ProductPrice(
          storeId: 'coto',
          productId: 'test-condom',
          priceOriginal: 6605.99,
          priceUnitario: 6605.99,
          stock: true,
          url: '',
          fechaActualizacion: DateTime(2026, 10, 9),
        ),
        discount: DiscountQuote.noDiscount(6605.99),
        cartProductId: 'test-condom',
      );
      final plan = MultiStoreComparison(
        items: [line],
        missingProducts: const [],
        totalOriginal: 6605.99,
        totalDiscount: 0,
        totalFinal: 6605.99,
      );
      final state = AppState(repository: MockRepository())
        ..supermarkets = [_store]
        ..products = [_product]
        ..cartItems = const [
          CartItem(
            productId: 'test-condom',
            quantity: 1,
            selectedStoreId: 'coto',
          ),
        ]
        ..selectedStoresPlan = plan
        ..bestPerProductPlan = plan
        ..isBootstrapping = false;
      await tester.pumpWidget(
        AppScope(
          notifier: state,
          child: const MaterialApp(home: Scaffold(body: CartScreen())),
        ),
      );

      expect(
        find.textContaining('Ningun supermercado tiene el changuito completo'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Todavia no encontramos precios'),
        findsNothing,
      );
      expect(find.textContaining('Ahorras'), findsNothing);
      state.dispose();
    },
  );

  testWidgets('abre la imagen compartible desde un changuito con precio real', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final line = PricedCartItem(
      product: _product,
      supermarket: _store,
      quantity: 1,
      price: ProductPrice(
        storeId: 'coto',
        productId: _product.id,
        priceOriginal: 6605.99,
        priceUnitario: 6605.99,
        stock: true,
        url: '',
        fechaActualizacion: DateTime(2026, 10, 13),
      ),
      discount: DiscountQuote.noDiscount(6605.99),
      cartProductId: _product.id,
    );
    final plan = MultiStoreComparison(
      items: [line],
      missingProducts: const [],
      totalOriginal: 6605.99,
      totalDiscount: 0,
      totalFinal: 6605.99,
    );
    final state = AppState(repository: MockRepository())
      ..supermarkets = [_store]
      ..products = [_product]
      ..cartItems = const [
        CartItem(
          productId: 'test-condom',
          quantity: 1,
          selectedStoreId: 'coto',
        ),
      ]
      ..selectedStoresPlan = plan
      ..bestPerProductPlan = plan
      ..isBootstrapping = false;
    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: const MaterialApp(home: Scaffold(body: CartScreen())),
      ),
    );

    await tester.tap(find.byTooltip('Compartir imagen del changuito'));
    await tester.pumpAndSettle();

    expect(find.byType(CartShareScreen), findsOneWidget);
    expect(find.text('Preservativos Tulipan superfino 6 u'), findsOneWidget);
    expect(find.text('Coto · x1'), findsOneWidget);
    expect(find.text('Total verificado'), findsOneWidget);
    expect(find.textContaining('6.605'), findsWidgets);
    expect(find.text('Changuito copiado para compartir.'), findsNothing);
    expect(tester.takeException(), isNull);
    state.dispose();
  });

  testWidgets('comparacion parcial cabe en una pantalla estrecha', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(344, 614));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const comparison = StoreComparison(
      supermarket: _store,
      items: const [],
      missingProducts: const [_product],
      totalOriginal: 0,
      totalDiscount: 0,
      totalFinal: 0,
      missingStatus: const {'test-condom': 'unavailable'},
    );
    final state = AppState(repository: MockRepository())
      ..cartComparisons = [comparison];
    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: const MaterialApp(home: StoreComparisonScreen()),
      ),
    );
    expect(find.text('Sin precio'), findsOneWidget);
    expect(find.textContaining('sin stock publicado'), findsOneWidget);
    expect(tester.takeException(), isNull);
    state.dispose();
  });

  testWidgets('opcion completa mantiene un encabezado legible a 320 px', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 614));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final line = PricedCartItem(
      product: _product,
      supermarket: _store,
      quantity: 1,
      price: ProductPrice(
        storeId: 'coto',
        productId: _product.id,
        priceOriginal: 6605.99,
        priceUnitario: 6605.99,
        stock: true,
        url: '',
        fechaActualizacion: DateTime(2026, 10, 28),
      ),
      discount: DiscountQuote.noDiscount(6605.99),
    );
    final state = AppState(repository: MockRepository())
      ..cartComparisons = [
        StoreComparison(
          supermarket: _store,
          items: [line],
          missingProducts: const [],
          totalOriginal: 6605.99,
          totalDiscount: 0,
          totalFinal: 6605.99,
        ),
      ];
    addTearDown(state.dispose);
    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: const MaterialApp(home: StoreComparisonScreen()),
      ),
    );

    expect(find.text('Compra completa'), findsOneWidget);
    expect(find.text('Coto'), findsOneWidget);
    expect(find.text('MEJOR OPCION'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mejor mix pone el importe debajo en pantalla estrecha', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final line = PricedCartItem(
      product: _product,
      supermarket: _store,
      quantity: 1,
      price: ProductPrice(
        storeId: 'coto',
        productId: _product.id,
        priceOriginal: 6605.99,
        priceUnitario: 6605.99,
        stock: true,
        url: '',
        fechaActualizacion: DateTime(2026, 10, 28),
      ),
      discount: DiscountQuote.noDiscount(6605.99),
    );
    final state = AppState(repository: MockRepository())
      ..bestPerProductPlan = MultiStoreComparison(
        items: [line],
        missingProducts: const [],
        totalOriginal: 6605.99,
        totalDiscount: 0,
        totalFinal: 6605.99,
      );
    addTearDown(state.dispose);
    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: const MaterialApp(home: StoreComparisonScreen()),
      ),
    );

    expect(
      tester.getTopLeft(find.text('\$6.605,99')).dy,
      greaterThan(tester.getBottomLeft(find.text('Por producto')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('la opcion parcial aclara cual producto si encontro', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(344, 614));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const missing = Product(
      id: 'test-sweet',
      ean: '7794990184897',
      name: 'Dulce de leche La Paulina 200 gr',
      brand: 'La Paulina',
      presentation: '200 gr',
      unit: 'gr',
      category: 'almacen',
      imageTag: '',
    );
    final line = PricedCartItem(
      product: _product,
      supermarket: _store,
      quantity: 1,
      price: ProductPrice(
        storeId: 'coto',
        productId: _product.id,
        priceOriginal: 6605.99,
        priceUnitario: 6605.99,
        stock: true,
        url: '',
        fechaActualizacion: DateTime(2026, 10, 13),
      ),
      discount: DiscountQuote.noDiscount(6605.99),
    );
    final comparison = StoreComparison(
      supermarket: _store,
      items: [line],
      missingProducts: const [missing],
      totalOriginal: 6605.99,
      totalDiscount: 0,
      totalFinal: 6605.99,
    );
    final state = AppState(repository: MockRepository())
      ..cartComparisons = [comparison];
    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: const MaterialApp(home: StoreComparisonScreen()),
      ),
    );

    expect(
      find.textContaining('Encontrado: Preservativos Tulipan'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Dulce de leche La Paulina 200 gr: no verificado'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    state.dispose();
  });
}
