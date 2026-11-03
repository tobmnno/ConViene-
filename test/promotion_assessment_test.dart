import 'package:conviene/models/discount.dart';
import 'package:conviene/models/payment_method.dart';
import 'package:conviene/models/price_quote.dart';
import 'package:conviene/models/product.dart';
import 'package:conviene/repositories/mock_repository.dart';
import 'package:conviene/services/product_offer_details.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime.now();
  const product = Product(
    id: 'milk',
    ean: '7790742448309',
    name: 'Leche entera',
    brand: 'Ilolay',
    presentation: '1 L',
    unit: 'L',
    category: 'lacteos',
    imageTag: 'milk',
  );
  const visa = PaymentMethod(
    id: 'visa',
    type: PaymentMethodType.card,
    entity: 'Visa',
    displayName: 'Visa',
    active: true,
  );

  test('only an exact EAN receives a verified quantity offer', () async {
    final store = (await MockRepository().getSupermarkets()).first;
    final result = SearchResult(
      product: product,
      price: ProductPrice(
        storeId: store.id,
        productId: product.id,
        priceOriginal: 1000,
        priceUnitario: 1000,
        stock: true,
        url: '',
        fechaActualizacion: today,
      ),
      supermarket: store,
    );
    Promotion offer(String ean) => Promotion(
      id: 'offer',
      storeId: store.id,
      tipoMedioPago: PaymentMethodType.card,
      entidad: 'Coto',
      porcentajeDescuento: 0,
      topeReintegro: 0,
      diasSemana: {today.weekday},
      fechaInicio: today,
      fechaFin: today,
      condiciones: 'Llevando 2',
      categorias: const ['todos'],
      promotionKind: 'store_product',
      mechanic: 'buy_n_pay_m',
      productEans: {ean},
      requiredQuantity: 2,
      chargedQuantity: 1,
      applicabilityScope: 'general_confirmed',
      sourceType: 'official_api',
      capturedAt: today,
    );
    expect(
      assessPromotion(
        promotion: offer('7790742448309'),
        result: result,
        date: today,
        paymentMethods: const [],
        quantity: 1,
        usedRefundCaps: const {},
      ),
      PromotionAssessment.conditioned,
    );
    expect(
      assessPromotion(
        promotion: offer('7790742448309'),
        result: result,
        date: today,
        paymentMethods: const [],
        quantity: 2,
        usedRefundCaps: const {},
      ),
      PromotionAssessment.available,
    );
    expect(
      assessPromotion(
        promotion: offer('7790742448316'),
        result: result,
        date: today,
        paymentMethods: const [],
        quantity: 2,
        usedRefundCaps: const {},
      ),
      PromotionAssessment.notApplicable,
    );
  });

  test(
    'general bank benefit is store-wide and capped usage remains conditioned',
    () async {
      final store = (await MockRepository().getSupermarkets()).first;
      final result = SearchResult(
        product: product,
        price: ProductPrice(
          storeId: store.id,
          productId: product.id,
          priceOriginal: 1000,
          priceUnitario: 1000,
          stock: true,
          url: '',
          fechaActualizacion: today,
        ),
        supermarket: store,
      );
      final promo = Promotion(
        id: 'bank',
        storeId: store.id,
        tipoMedioPago: PaymentMethodType.card,
        entidad: 'Visa',
        porcentajeDescuento: 20,
        topeReintegro: 100,
        capFrequency: 'monthly',
        diasSemana: {today.weekday},
        fechaInicio: today,
        fechaFin: today,
        condiciones: '',
        categorias: const ['todos'],
        applicabilityScope: 'general_confirmed',
        sourceType: 'official_api',
        capturedAt: today,
      );
      expect(promotionReach(promo), 'Beneficio del supermercado');
      expect(
        assessPromotion(
          promotion: promo,
          result: result,
          date: today,
          paymentMethods: const [visa],
          quantity: 1,
          usedRefundCaps: const {},
        ),
        PromotionAssessment.conditioned,
      );
      expect(
        assessPromotion(
          promotion: promo,
          result: result,
          date: today,
          paymentMethods: const [visa],
          quantity: 1,
          usedRefundCaps: {promo.capUsageKey(today)!: 0},
        ),
        PromotionAssessment.available,
      );
    },
  );

  test('a payment benefit with EAN scope excludes other products', () {
    final scoped = Promotion(
      id: 'sku-card',
      storeId: 'coto',
      tipoMedioPago: PaymentMethodType.card,
      entidad: 'Visa',
      porcentajeDescuento: 20,
      topeReintegro: 0,
      diasSemana: {today.weekday},
      fechaInicio: today,
      fechaFin: today,
      condiciones: '',
      categorias: const ['todos'],
      productEans: const {'7790742448309'},
      applicabilityScope: 'general_confirmed',
      sourceType: 'official_api',
      capturedAt: today,
    );
    expect(scoped.appliesToProduct(product), isTrue);
    expect(
      scoped.appliesToProduct(
        const Product(
          id: 'other',
          ean: '7790742448316',
          name: 'Leche 2 L',
          brand: 'Ilolay',
          presentation: '2 L',
          unit: 'L',
          category: 'lacteos',
          imageTag: 'milk',
        ),
      ),
      isFalse,
    );
  });
}
