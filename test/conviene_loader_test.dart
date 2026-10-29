import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:conviene/widgets/conviene_loader.dart';

void main() {
  testWidgets(
    'delayed loader reserves space, stops hidden and respects reduced motion',
    (tester) async {
      Widget app({
        bool active = true,
        bool reduced = false,
        bool ticker = true,
      }) => MaterialApp(
        theme: ThemeData.dark(),
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: TickerMode(
            enabled: ticker,
            child: Scaffold(
              body: ConvieneLoader(
                compact: true,
                active: active,
                message: 'Comparando',
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(app());
      final before = tester.getSize(find.byType(ConvieneLoader));
      expect(find.text('Comparando').hitTestable(), findsNothing);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Comparando').hitTestable(), findsOneWidget);
      expect(tester.getSize(find.byType(ConvieneLoader)), before);
      await tester.pumpWidget(app(reduced: true));
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpWidget(app(ticker: false));
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpWidget(app(active: false));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(ConvieneLoader)), before);
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
}
