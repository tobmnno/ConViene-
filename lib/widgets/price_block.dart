import 'package:flutter/material.dart';

import '../models/discount.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';

class PriceBlock extends StatelessWidget {
  const PriceBlock({
    super.key,
    required this.discount,
    this.alignEnd = false,
    this.large = false,
  });

  final DiscountQuote discount;
  final bool alignEnd;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final crossAxisAlignment = alignEnd
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    if (!discount.descuentoAplicado) {
      return Column(
        crossAxisAlignment: crossAxisAlignment,
        children: [
          Text(
            formatMoney(discount.precioFinal),
            style: TextStyle(
              color: AppColors.deepBlue,
              fontWeight: FontWeight.w900,
              fontSize: large ? 27 : 20,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Sin descuento',
            style: TextStyle(color: AppColors.textGray, fontSize: 12),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Text(
          formatMoney(discount.precioOriginal),
          style: const TextStyle(
            color: AppColors.textGray,
            decoration: TextDecoration.lineThrough,
            decorationColor: AppColors.textGray,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          formatMoney(discount.precioFinal),
          style: TextStyle(
            color: AppColors.green,
            fontWeight: FontWeight.w900,
            fontSize: large ? 28 : 20,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${formatPercent(discount.porcentaje)} OFF',
          style: const TextStyle(
            color: AppColors.green,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
