import 'package:conviene/models/payment_method.dart';
import 'package:conviene/services/payment_method_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = PaymentMethodService();

  test('agrega un medio nuevo activo', () {
    final result = service.addCustom(
      methods: const [],
      type: PaymentMethodType.wallet,
      displayName: 'Personal Pay',
    );

    expect(result.added, isTrue);
    expect(result.methods, hasLength(1));
    expect(result.methods.single.id, 'custom_billetera_personal_pay');
    expect(result.methods.single.entity, 'Personal Pay');
    expect(result.methods.single.active, isTrue);
  });

  test('activa un medio existente sin duplicarlo', () {
    final result = service.addCustom(
      methods: const [
        PaymentMethod(
          id: 'visa',
          type: PaymentMethodType.card,
          entity: 'Visa',
          displayName: 'Visa',
          active: false,
        ),
      ],
      type: PaymentMethodType.card,
      displayName: 'visa',
    );

    expect(result.added, isFalse);
    expect(result.methods, hasLength(1));
    expect(result.methods.single.active, isTrue);
  });
}
