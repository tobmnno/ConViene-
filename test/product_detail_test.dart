import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:conviene/screens/product_detail_screen.dart';
import 'package:conviene/services/product_offer_details.dart';
import 'package:conviene/state/app_scope.dart';
import 'package:conviene/state/app_state.dart';
import 'package:conviene/models/price_quote.dart';
import 'package:conviene/models/discount.dart';
import 'package:conviene/models/payment_method.dart';
import 'package:conviene/theme/app_theme.dart';
import 'product_comparison_test.dart' show milk, ComparisonRepository;

class DetailState extends AppState {
  DetailState() : super(repository: ComparisonRepository());
  int adds = 0;
  int? addedQuantity;
  String? addedStore;
  @override
  Future<void> addOfferToCart(SearchResult result, {int quantity = 1}) async {
    adds++;
    addedQuantity = quantity;
    addedStore = result.supermarket.id;
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
}

void main() {
  for (final dark in [false, true]) {
    for (final size in [
      const Size(320, 568),
      const Size(390, 844),
      const Size(1280, 800),
    ]) {
      testWidgets('detail fits $size, dark=$dark', (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final state = DetailState();
        await tester.pumpWidget(
          AppScope(
            notifier: state,
            child: MaterialApp(
              theme: buildAppTheme(dark: dark),
              home: const ProductDetailScreen(product: milk),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Sumar unidad'));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(state.cartItems, isEmpty);
        await tester.pumpWidget(const SizedBox());
        state.dispose();
      });
    }
  }
  test('only direct HTTPS official product URLs can be opened', () {
    expect(
      officialProductUri('carrefour', 'https://www.carrefour.com.ar/leche/p'),
      isNotNull,
    );
    expect(
      officialProductUri(
        'coto',
        'https://www.coto.com.ar/productos/leche-entera-1l',
      ),
      isNotNull,
    );
    expect(
      officialProductUri(
        'coto',
        'https://www.coto.com.ar/productos_/R-00527739-00527739-200',
      ),
      isNotNull,
    );
    expect(
      officialProductUri(
        'lagallega',
        'https://www.lagallega.com.ar/productosdet.asp?Pr=1234',
      ),
      isNotNull,
    );
    expect(
      officialProductUri(
        'lagallega',
        'https://www.lagallega.com.ar/Articulos.asp',
      ),
      isNull,
    );
    expect(
      officialProductUri(
        'coto',
        'https://www.cotodigital.com.ar/sitios/cdigi/producto/leche/_/A-1/p/1',
      ),
      isNotNull,
    );
    for (final value in [
      'http://www.carrefour.com.ar/leche/p',
      'https://www.carrefour.com.ar.evil.test/leche/p',
      'https://user@www.carrefour.com.ar/leche/p',
      'javascript:alert(1)',
      'https://www.carrefour.com.ar/',
    ]) {
      expect(officialProductUri('carrefour', value), isNull);
    }
    expect(
      officialProductUri('coto', 'https://www.coto.com.ar/productos_/'),
      isNull,
    );
  });

  testWidgets(
    'detail quantity is independent and add is protected against double tap',
    (tester) async {
      final state = DetailState();
      await tester.pumpWidget(
        AppScope(
          notifier: state,
          child: const MaterialApp(home: ProductDetailScreen(product: milk)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('EAN ${milk.ean}'), findsOneWidget);
      await tester.tap(find.byTooltip('Sumar unidad'));
      await tester.pump();
      expect(state.adds, 0);
      expect(state.cartItems, isEmpty);
      final button = find.byTooltip('Agregar 2 en Coto');
      await tester.scrollUntilVisible(
        button,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pump();
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(state.adds, 1);
      expect(state.addedQuantity, 2);
      expect(state.addedStore, 'coto');
      expect(find.byTooltip('Agregado a tu changuito'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );

  testWidgets('prices and benefits tabs keep the quantity preview separate', (
    tester,
  ) async {
    final state = DetailState();
    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: const MaterialApp(home: ProductDetailScreen(product: milk)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('MENOR COSTO ESTIMADO'), findsOneWidget);
    expect(find.byTooltip('Agregar 1 en Coto'), findsOneWidget);
    expect(find.text('Ver en sitio oficial'), findsOneWidget);
    expect(find.textContaining('Precio publicado por unidad'), findsNothing);
    expect(find.textContaining('A pagar estimado'), findsNothing);

    await tester.tap(find.text('Beneficios'));
    await tester.pumpAndSettle();
    expect(
      find.text('Sin beneficios adicionales verificados.'),
      findsOneWidget,
    );
    expect(find.textContaining('Precio publicado por unidad'), findsNothing);
    expect(find.textContaining('A pagar estimado'), findsNothing);
    expect(find.textContaining('Precio consultado'), findsNothing);
    expect(find.byTooltip('Agregar 1 en Coto'), findsNothing);
    expect(find.text('Ver en sitio oficial'), findsNothing);

    await tester.tap(find.byTooltip('Sumar unidad'));
    await tester.tap(find.text('Precios'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Agregar 2 en Coto'), findsOneWidget);
    expect(state.cartItems, isEmpty);
    expect(state.adds, 0);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });

  testWidgets(
    'benefits show a compact summary with optional verified details',
    (tester) async {
      final state = DetailState()
        ..selectedDate = DateTime(2026, 10, 26)
        ..paymentMethods = [
          const PaymentMethod(
            id: 'visa',
            type: PaymentMethodType.card,
            entity: 'Visa',
            displayName: 'Visa',
            active: true,
          ),
        ]
        ..promotions = [
          Promotion(
            id: 'coto-visa',
            storeId: 'coto',
            tipoMedioPago: PaymentMethodType.card,
            entidad: 'Visa',
            porcentajeDescuento: 25,
            topeReintegro: 30000,
            diasSemana: const {DateTime.monday},
            fechaInicio: DateTime(2026, 10, 1),
            fechaFin: DateTime(2026, 10, 31),
            condiciones: 'En un pago',
            categorias: const ['todos'],
            beneficio: '25% OFF',
            fuenteUrl: 'https://www.coto.com.ar/descuentos',
          ),
          Promotion(
            id: 'coto-mastercard',
            storeId: 'coto',
            tipoMedioPago: PaymentMethodType.card,
            entidad: 'Mastercard',
            porcentajeDescuento: 20,
            topeReintegro: 20000,
            diasSemana: const {DateTime.monday},
            fechaInicio: DateTime(2026, 10, 1),
            fechaFin: DateTime(2026, 10, 31),
            condiciones: 'Con Mastercard',
            categorias: const ['todos'],
            titulo: '20% Mastercard',
          ),
        ];
      await tester.pumpWidget(
        AppScope(
          notifier: state,
          child: const MaterialApp(home: ProductDetailScreen(product: milk)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('25% OFF'), findsNothing);
      expect(find.textContaining('Reintegro estimado'), findsNothing);
      await tester.tap(find.text('Beneficios'));
      await tester.pumpAndSettle();
      expect(find.text('BENEFICIO APLICADO'), findsOneWidget);
      expect(find.text('Visa · 25% OFF'), findsOneWidget);
      expect(find.textContaining('Ahorro estimado'), findsOneWidget);
      expect(find.text('Otros beneficios (1)'), findsOneWidget);
      expect(find.text('20% Mastercard'), findsNothing);
      expect(find.text('En un pago'), findsNothing);
      expect(find.textContaining('Tope:'), findsNothing);
      expect(find.textContaining('Precio publicado por unidad'), findsNothing);
      expect(
        find.textContaining('https://www.coto.com.ar/descuentos'),
        findsNothing,
      );
      await tester.tap(find.text('Visa · 25% OFF'));
      await tester.pumpAndSettle();
      expect(find.text('En un pago'), findsOneWidget);
      expect(find.textContaining('Tope:'), findsOneWidget);
      expect(
        find.textContaining('Precio publicado por unidad'),
        findsOneWidget,
      );
      expect(
        find.textContaining('https://www.coto.com.ar/descuentos'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Otros beneficios (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Otros beneficios (1)'));
      await tester.pumpAndSettle();
      expect(find.text('20% Mastercard'), findsOneWidget);
      expect(state.cartItems, isEmpty);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );

  testWidgets('unselected payment benefit is available but not applied', (
    tester,
  ) async {
    final state = DetailState()
      ..selectedDate = DateTime(2026, 10, 26)
      ..paymentMethods = []
      ..promotions = [
        Promotion(
          id: 'coto-mastercard-only',
          storeId: 'coto',
          tipoMedioPago: PaymentMethodType.card,
          entidad: 'Mastercard',
          porcentajeDescuento: 20,
          topeReintegro: 20000,
          diasSemana: const {DateTime.monday},
          fechaInicio: DateTime(2026, 10, 1),
          fechaFin: DateTime(2026, 10, 31),
          condiciones: 'Con Mastercard',
          categorias: const ['todos'],
          titulo: '20% Mastercard',
        ),
      ];
    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: const MaterialApp(home: ProductDetailScreen(product: milk)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beneficios'));
    await tester.pumpAndSettle();
    expect(
      find.text('No hay beneficios aplicados con tus medios de pago.'),
      findsOneWidget,
    );
    expect(find.text('Otros beneficios (1)'), findsOneWidget);
    expect(find.text('20% Mastercard'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });
}
