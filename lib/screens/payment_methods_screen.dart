import 'dart:async';

import 'package:flutter/material.dart';

import '../models/payment_method.dart';
import '../state/app_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/payment_method_logo.dart';
import '../widgets/screen_frame.dart';

class PaymentMethodsScreen extends StatelessWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.chevron_left),
        ),
        title: const Text('Medios de pago'),
      ),
      body: ScreenFrame(
        child: ListView(
          children: [
            const Text(
              'Con que medios de pago contas?',
              style: TextStyle(
                color: AppColors.deepBlue,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Selecciona las tarjetas, bancos o billeteras que usas para que podamos mostrarte descuentos disponibles.',
              style: TextStyle(
                color: AppColors.deepBlue,
                fontSize: 14,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 22),
            _PaymentSection(
              title: 'Tarjetas de credito y debito',
              type: PaymentMethodType.card,
              methods: state.paymentMethods,
            ),
            const SizedBox(height: 14),
            _PaymentSection(
              title: 'Bancos',
              type: PaymentMethodType.bank,
              methods: state.paymentMethods,
            ),
            const SizedBox(height: 14),
            _PaymentSection(
              title: 'Billeteras y beneficios',
              type: PaymentMethodType.wallet,
              methods: state.paymentMethods,
            ),
            const SizedBox(height: 18),
            const AppCard(
              color: AppColors.softBlue,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline, color: AppColors.blue, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Conviene no guarda numeros de tarjeta, CVV, claves ni datos bancarios sensibles.',
                      style: TextStyle(color: AppColors.deepBlue, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () {
                unawaited(state.savePaymentMethods());
                Navigator.of(context).maybePop();
              },
              child: const Text('Guardar y continuar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentSection extends StatelessWidget {
  const _PaymentSection({
    required this.title,
    required this.type,
    required this.methods,
  });

  final String title;
  final PaymentMethodType type;
  final List<PaymentMethod> methods;

  @override
  Widget build(BuildContext context) {
    final sectionMethods = methods.where((method) => method.type == type);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.deepBlue,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final method in sectionMethods) _PaymentTile(method: method),
            ],
          ),
        ),
      ],
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.method});

  final PaymentMethod method;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return InkWell(
      onTap: () => unawaited(state.togglePaymentMethod(method.id)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: method.active ? AppColors.softBlue : Colors.transparent,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              PaymentMethodLogo(method: method, size: 34),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  method.displayName,
                  style: const TextStyle(
                    color: AppColors.deepBlue,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.elasticOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) {
                  return ScaleTransition(scale: animation, child: child);
                },
                child: Icon(
                  method.active
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                  key: ValueKey(method.active),
                  color: method.active ? AppColors.blue : AppColors.textGray,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
