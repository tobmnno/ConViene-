import 'package:conviene/models/cart_item.dart';
import 'package:conviene/models/product.dart';
import 'package:conviene/models/store_comparison.dart';
import 'package:conviene/repositories/mock_repository.dart';
import 'package:conviene/screens/cart_screen.dart';
import 'package:conviene/screens/app_shell.dart';
import 'package:conviene/screens/discounts_screen.dart';
import 'package:conviene/screens/home_screen.dart';
import 'package:conviene/state/app_scope.dart';
import 'package:conviene/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _product = Product(
  id: 'test-product',
  ean: '',
  name: 'Producto de prueba',
  brand: '',
  presentation: '1 u',
  unit: 'u',
  category: '',
  imageTag: '',
);

void main() {
  testWidgets('los tres supermercados comparten la misma columna de nombre', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final state = AppState(repository: MockRepository());
    state.supermarkets = await MockRepository().getSupermarkets();
    state.products = const [_product];
    state.cartItems = const [CartItem(productId: 'test-product', quantity: 1)];
    state.cartComparisons = [
      for (final store in state.supermarkets.take(3))
        StoreComparison(
          supermarket: store,
          items: const [],
          missingProducts: const [_product],
          totalOriginal: 0,
          totalDiscount: 0,
          totalFinal: 0,
        ),
    ];

    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: const MaterialApp(home: Scaffold(body: CartScreen())),
      ),
    );

    final leftEdges = [
      for (final name in ['Coto', 'Carrefour', 'La Gallega'])
        tester.getTopLeft(find.text(name)).dx,
    ];
    expect(leftEdges[1], closeTo(leftEdges[0], 0.1));
    expect(leftEdges[2], closeTo(leftEdges[0], 0.1));
    state.dispose();
  });

  testWidgets('Inicio no ofrece retiro ni configuracion de ubicacion', (
    tester,
  ) async {
    final state = AppState(repository: MockRepository());
    state.supermarkets = await MockRepository().getSupermarkets();
    state.selectedStoreIds = {'coto', 'carrefour', 'lagallega'};

    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: MaterialApp(
          home: Scaffold(
            body: HomeScreen(
              onNavigateToSearch: () {},
              onNavigateToCart: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.byTooltip('Compra y ubicacion'), findsNothing);
    expect(find.textContaining('Retiro en sucursal'), findsNothing);
    expect(find.text('Buscar producto...'), findsOneWidget);
    state.dispose();
  });

  testWidgets('Descuentos no muestra el aviso de datos parciales', (
    tester,
  ) async {
    final state = AppState(repository: MockRepository())
      ..promotionsWarning = '';
    state.supermarkets = await MockRepository().getSupermarkets();

    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: const MaterialApp(home: Scaffold(body: DiscountsScreen())),
      ),
    );

    expect(find.textContaining('Datos parciales'), findsNothing);
    expect(find.text('Descuentos'), findsOneWidget);
    state.dispose();
  });

  testWidgets('el escaner es el acceso central y no esta en la busqueda', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final state = AppState(repository: MockRepository())
      ..isBootstrapping = false;
    state.supermarkets = await MockRepository().getSupermarkets();

    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: MaterialApp(
          home: AppShell(darkMode: false, onToggleDarkMode: () {}),
        ),
      ),
    );

    expect(find.byTooltip('Escanear codigo de barras'), findsOneWidget);
    expect(find.byType(BottomAppBar), findsOneWidget);
    await tester.tap(find.text('Buscar').last);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Escanear codigo de barras'), findsOneWidget);
    expect(tester.takeException(), isNull);
    state.dispose();
  });

  testWidgets('el changuito conserva la posicion al recalcular', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final state = AppState(repository: MockRepository())
      ..products = const [_product]
      ..cartItems = const [CartItem(productId: 'test-product', quantity: 1)];

    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: const MaterialApp(home: Scaffold(body: CartScreen())),
      ),
    );

    final product = find.text('Producto de prueba');
    await tester.ensureVisible(product);
    await tester.pumpAndSettle();
    final initialTop = tester.getTopLeft(product).dy;

    state.isComparing = true;
    state.notifyListeners();
    await tester.pump();
    expect(tester.getTopLeft(product).dy, closeTo(initialTop, 0.1));

    state.isComparing = false;
    state.notifyListeners();
    await tester.pump();
    expect(tester.getTopLeft(product).dy, closeTo(initialTop, 0.1));

    await tester.tap(find.byTooltip('Sumar'));
    await tester.tap(find.byTooltip('Sumar'));
    await tester.pumpAndSettle();
    expect(state.cartQuantity, 3);
    expect(tester.getTopLeft(product).dy, closeTo(initialTop, 0.1));
    state.dispose();
  });
}
