import 'package:conviene/repositories/mock_repository.dart';
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
}
