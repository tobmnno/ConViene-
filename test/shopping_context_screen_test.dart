import 'package:conviene/repositories/mock_repository.dart';
import 'package:conviene/screens/shopping_context_screen.dart';
import 'package:conviene/state/app_scope.dart';
import 'package:conviene/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('muestra un unico aviso claro ante toques repetidos', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final state = AppState(repository: MockRepository());
    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: const MaterialApp(home: ShoppingContextScreen()),
      ),
    );

    await tester.enterText(find.byType(TextField).first, '123');
    await tester.enterText(find.byType(TextField).last, '200');

    final save = find.text('Guardar configuracion');
    await tester.tap(save);
    await tester.pump();
    await tester.tap(save);
    await tester.tap(save);
    await tester.pump();

    expect(find.text('El codigo postal debe tener 4 digitos.'), findsOneWidget);
    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.behavior, SnackBarBehavior.floating);
    expect(snackBar.dismissDirection, DismissDirection.horizontal);

    await tester.enterText(find.byType(TextField).first, '2000');
    await tester.enterText(find.byType(TextField).last, 'invalido');
    await tester.tap(save);
    await tester.pump();

    expect(find.text('Ingresa un ID de sucursal Coto valido.'), findsOneWidget);
    expect(find.text('El codigo postal debe tener 4 digitos.'), findsNothing);

    state.dispose();
  });
}
