import 'package:conviene/repositories/mock_repository.dart';
import 'package:conviene/screens/home_screen.dart';
import 'package:conviene/state/app_scope.dart';
import 'package:conviene/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('home payment methods route keeps app state', (tester) async {
    final state = AppState(repository: MockRepository());
    state.supermarkets = await MockRepository().getSupermarkets();
    state.selectedStoreIds = {'coto', 'carrefour', 'lagallega'};
    addTearDown(state.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: AppScope(
          notifier: state,
          child: Scaffold(
            body: HomeScreen(
              onNavigateToSearch: () {},
              onNavigateToCart: () {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Ver todos'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Medios de pago'), findsOneWidget);
  });
}
