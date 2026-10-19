import 'package:conviene/repositories/mock_repository.dart';
import 'package:conviene/models/price_quote.dart';
import 'package:conviene/screens/search_screen.dart';
import 'package:conviene/state/app_scope.dart';
import 'package:conviene/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('aplica el filtro de supermercados desde resultados', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final state = AppState(repository: MockRepository());
    await tester.runAsync(() => state.initialize());

    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: MaterialApp(
          home: Scaffold(body: SearchScreen(onBack: () {})),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Filtros'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    await tester.tap(find.text('Aplicar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();

    expect(state.selectedStoreIds, {'carrefour', 'lagallega'});

    state.dispose();
  });

  testWidgets(
    'no confunde un error de red con una busqueda sin coincidencias',
    (tester) async {
      final state = AppState(repository: MockRepository())
        ..lastError = 'No pudimos actualizar los resultados.';

      await tester.pumpWidget(
        AppScope(
          notifier: state,
          child: MaterialApp(
            home: Scaffold(body: SearchScreen(onBack: () {})),
          ),
        ),
      );

      expect(
        find.text('No pudimos actualizar los resultados.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'No encontramos ese producto en los supermercados seleccionados.',
        ),
        findsNothing,
      );

      state.dispose();
    },
  );

  testWidgets('muestra resultados parciales sin ocultar los productos sanos', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final state = AppState(repository: MockRepository());
    await tester.runAsync(() => state.initialize());
    expect(state.searchResults, isNotEmpty);
    state.searchWarning = 'No se pudo consultar Carrefour.';

    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: MaterialApp(
          home: Scaffold(body: SearchScreen(onBack: () {})),
        ),
      ),
    );

    expect(find.text('No se pudo consultar Carrefour.'), findsOneWidget);
    expect(state.searchResults, isNotEmpty);
    expect(find.byTooltip('Agregar al changuito'), findsWidgets);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    expect(find.byTooltip('Escanear codigo de barras'), findsNothing);
    state.dispose();
  });

  testWidgets('no afirma ausencia global si la busqueda fue parcial', (
    tester,
  ) async {
    final state = AppState(repository: MockRepository())
      ..searchWarning = 'No se pudo consultar Carrefour.';
    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: MaterialApp(
          home: Scaffold(body: SearchScreen(onBack: () {})),
        ),
      ),
    );
    expect(
      find.text(
        'No encontramos resultados en los supermercados que respondieron.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'No encontramos ese producto en los supermercados seleccionados.',
      ),
      findsNothing,
    );
    state.dispose();
  });

  testWidgets('un EAN valido sin oferta explica que falta precio publicado', (
    tester,
  ) async {
    final state = AppState(repository: MockRepository())
      ..searchQuery = '77980267';
    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: MaterialApp(
          home: Scaffold(body: SearchScreen(onBack: () {})),
        ),
      ),
    );
    expect(
      find.text(
        'Codigo valido, pero sin precio publicado en los supermercados seleccionados.',
      ),
      findsOneWidget,
    );
    state.dispose();
  });

  testWidgets('muestra el producto identificado aunque no este disponible', (
    tester,
  ) async {
    final state = AppState(repository: MockRepository())
      ..searchQuery = '77980267'
      ..searchNotice =
          'Encontramos Guaymallen en Carrefour, pero figura sin stock.';
    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: MaterialApp(
          home: Scaffold(body: SearchScreen(onBack: () {})),
        ),
      ),
    );
    expect(find.textContaining('Guaymallen en Carrefour'), findsOneWidget);
    expect(
      find.text('No hay ofertas disponibles para comprar en este momento.'),
      findsOneWidget,
    );
    state.dispose();
  });

  testWidgets('distingue la coincidencia por nombre del EAN exacto', (
    tester,
  ) async {
    final state = AppState(repository: MockRepository());
    await tester.runAsync(() => state.initialize());
    final original = state.searchResults.first;
    state.searchResults = [
      SearchResult(
        product: original.product,
        price: original.price,
        supermarket: original.supermarket,
        isExactMatch: false,
        matchType: 'name_match',
      ),
    ];
    state.searchNotice = 'Codigo identificado: Leche entera Ilolay 1 L.';
    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: MaterialApp(
          home: Scaffold(body: SearchScreen(onBack: () {})),
        ),
      ),
    );
    expect(find.text('Coincidencia por nombre'), findsOneWidget);
    expect(find.textContaining('Codigo identificado'), findsOneWidget);
    state.dispose();
  });
}
