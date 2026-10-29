import 'package:conviene/services/payment_method_service.dart';
import 'package:conviene/repositories/mock_repository.dart';
import 'package:conviene/widgets/conviene_logo.dart';
import 'package:conviene/widgets/payment_method_logo.dart';
import 'package:conviene/widgets/store_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('original brand and payment logos render on both themes', (
    tester,
  ) async {
    final visa = const PaymentMethodService().initialMethods().first;
    expect(
      (await rootBundle.load(
        'assets/brand/conviene_logo_source.png',
      )).lengthInBytes,
      greaterThan(100000),
    );
    expect(
      (await rootBundle.load('assets/brand/conviene_logo.png')).lengthInBytes,
      greaterThan(100000),
    );
    expect(visa.logoAsset, 'assets/logos/payment_visa.png');

    for (final brightness in [Brightness.light, Brightness.dark]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Scaffold(
            body: Column(
              children: [
                const ConvieneLogo(compact: true),
                PaymentMethodLogo(method: visa),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final brandImage = tester.widget<Image>(
        find.descendant(
          of: find.byType(ConvieneLogo),
          matching: find.byType(Image),
        ),
      );
      expect(
        (brandImage.image as AssetImage).assetName,
        brightness == Brightness.dark
            ? 'assets/brand/conviene_logo.png'
            : 'assets/brand/conviene_logo_source.png',
      );
      expect(find.byType(Image), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('every active store and payment logo asset renders', (
    tester,
  ) async {
    final stores = await MockRepository().getSupermarkets();
    final methods = const PaymentMethodService().initialMethods();
    for (final store in stores.where((store) => store.enabled)) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: StoreLogo(supermarket: store)),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: store.name);
    }
    for (final method in methods.where(
      (method) => method.logoAsset.isNotEmpty,
    )) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PaymentMethodLogo(method: method)),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: method.displayName);
    }
  });
}
