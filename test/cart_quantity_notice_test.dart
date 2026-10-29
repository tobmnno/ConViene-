import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:conviene/models/cart_item.dart';
import 'package:conviene/models/discount.dart';
import 'package:conviene/models/payment_method.dart';
import 'package:conviene/models/price_quote.dart';
import 'package:conviene/models/supermarket.dart';
import 'package:conviene/models/shopping_context.dart';
import 'package:conviene/services/cart_quantity_suggestion.dart';
import 'package:conviene/state/app_scope.dart';
import 'package:conviene/state/app_state.dart';
import 'package:conviene/widgets/cart_quantity_notice.dart';
import 'product_comparison_test.dart' show milk, ComparisonRepository;

PricedCartItem line({
  bool expired = false,
  String ean = '7790742448309',
  bool priorOffer = false,
}) {
  final now = DateTime.now();
  return PricedCartItem(
    product: milk,
    supermarket: const Supermarket(
      id: 'coto',
      name: 'Coto',
      shortName: 'COTO',
      enabled: true,
      brandColor: 0,
      websiteUrl: 'https://www.coto.com.ar/',
      logoAsset: '',
    ),
    quantity: 1,
    discount: DiscountQuote.noDiscount(1500),
    price: ProductPrice(
      storeId: 'coto',
      productId: milk.id,
      priceOriginal: 1500,
      priceUnitario: 1500,
      stock: true,
      url: '',
      fechaActualizacion: now,
      branchId: '200',
      hasStoreOffer: priorOffer,
      quantityOffers: [
        Promotion(
          id: '2x1',
          storeId: 'coto',
          tipoMedioPago: PaymentMethodType.card,
          entidad: 'Coto',
          porcentajeDescuento: 0,
          topeReintegro: 0,
          diasSemana: {now.weekday},
          fechaInicio: now.subtract(const Duration(days: 1)),
          fechaFin: now,
          condiciones: '2x1',
          categorias: const ['todos'],
          promotionKind: 'store_product',
          mechanic: 'buy_n_pay_m',
          productEans: {ean},
          branchIds: const {'200'},
          requiredQuantity: 2,
          chargedQuantity: 1,
          sourceType: 'official_api',
          capturedAt: expired ? now.subtract(const Duration(hours: 1)) : now,
          fuenteUrl: 'https://www.cotodigital.com.ar/',
        ),
      ],
    ),
  );
}

AppState cartState() => AppState(repository: ComparisonRepository())
  ..cartItems = [
    const CartItem(productId: 'milk', quantity: 1, selectedStoreId: 'coto'),
  ];

void main() {
  test('2x1 never says same price when a bank benefit makes one cheaper', () {
    final state = cartState();
    final now = DateTime.now();
    state.paymentMethods = [
      const PaymentMethod(
        id: 'visa',
        type: PaymentMethodType.card,
        entity: 'Visa',
        displayName: 'Visa',
        active: true,
      ),
    ];
    state.promotions = [
      Promotion(
        id: 'bank',
        storeId: 'coto',
        tipoMedioPago: PaymentMethodType.card,
        entidad: 'Visa',
        porcentajeDescuento: 20,
        topeReintegro: 0,
        diasSemana: {now.weekday},
        fechaInicio: now,
        fechaFin: now,
        condiciones: 'No acumulable',
        categorias: const ['todos'],
      ),
    ];
    final result = quantitySuggestion(state, line())!;
    expect(result.one.precioFinal, 1200);
    expect(result.two.precioFinal, 1500);
    expect(result.samePrice, isFalse);
    expect(
      quantitySuggestion(state, line(priorOffer: true))!.one.precioFinal,
      1500,
    );
    state.dispose();
  });

  test('only fresh, chosen-store exact EAN 2x1 produces a suggestion', () {
    final state = cartState();
    final suggestion = quantitySuggestion(state, line())!;
    expect(suggestion.samePrice, isTrue);
    expect(suggestion.two.precioFinal, 1500);
    expect(quantitySuggestion(state, line(expired: true)), isNull);
    expect(quantitySuggestion(state, line(ean: 'wrong')), isNull);
    state.shoppingContext = const ShoppingContext(cotoStore: '401');
    expect(quantitySuggestion(state, line()), isNull);
    state.shoppingContext = const ShoppingContext();
    state.isComparing = true;
    expect(quantitySuggestion(state, line()), isNull);
    state.dispose();
  });

  testWidgets('explicit single acceptance, and dismissal survives recreation', (
    tester,
  ) async {
    final state = cartState();
    var count = 0;
    Widget app() => AppScope(
      notifier: state,
      child: MaterialApp(
        home: Scaffold(
          body: CartQuantityNotice(line: line(), onAccept: () => count++),
        ),
      ),
    );
    await tester.pumpWidget(app());
    expect(count, 0);
    await tester.tap(find.text('Llevar 2'));
    await tester.tap(find.text('Llevar 2'));
    await tester.pump();
    expect(count, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app());
    await tester.tap(find.byTooltip('Descartar sugerencia'));
    await tester.pump();
    expect(find.text('Llevar 2'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app());
    expect(find.text('Llevar 2'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });
}
