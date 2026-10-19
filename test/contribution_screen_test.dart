import 'package:conviene/repositories/mock_repository.dart';
import 'package:conviene/screens/contribution_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('an incomplete contribution cannot be published', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final stores = (await MockRepository().getSupermarkets())
        .where((store) => store.enabled)
        .toList();

    await tester.pumpWidget(
      MaterialApp(
        home: ContributionScreen(
          stores: stores,
          initialQuery: 'Dulce de leche La Paulina',
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Publicar aporte'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Publicar aporte'));
    await tester.pump();

    expect(find.text('Elegí un supermercado.'), findsWidgets);
    expect(find.text('Completa este dato.'), findsOneWidget);
    expect(find.text('Ingresa un precio mayor que cero.'), findsOneWidget);
  });
}
