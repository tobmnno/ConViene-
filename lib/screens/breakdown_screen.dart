import 'package:flutter/material.dart';

import '../models/cart_item.dart';
import '../models/store_comparison.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';
import '../widgets/app_card.dart';
import '../widgets/product_art.dart';
import '../widgets/screen_frame.dart';
import '../widgets/store_logo.dart';

class BreakdownScreen extends StatelessWidget {
  const BreakdownScreen({super.key, required this.comparison});

  final StoreComparison comparison;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.chevron_left),
        ),
        title: Column(
          children: [
            const Text('Desglose de precios'),
            Text(
              '${comparison.supermarket.name} es tu mejor opcion',
              style: const TextStyle(
                color: AppColors.deepBlue,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Cerrar',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: ScreenFrame(
        child: ListView(
          children: [
            AppCard(
              color: const Color(0xFFEAF8F0),
              borderColor: const Color(0xFFC7EFD8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total con descuentos',
                          style: TextStyle(
                            color: AppColors.deepBlue,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          formatMoney(
                            comparison.totalFinal,
                            compactCents: false,
                          ),
                          style: const TextStyle(
                            color: AppColors.green,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'Ahorras ${formatMoney(comparison.totalDiscount)}',
                          style: const TextStyle(
                            color: AppColors.green,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 54,
                    height: 54,
                    decoration: const BoxDecoration(
                      color: AppColors.green,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.percent,
                      color: AppColors.white,
                      size: 30,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _HeaderRow(),
            const SizedBox(height: 8),
            for (final item in comparison.items) ...[
              _BreakdownLine(item: item),
              const SizedBox(height: 10),
            ],
            if (comparison.missingProducts.isNotEmpty) ...[
              _MissingProductsCard(comparison: comparison),
              const SizedBox(height: 10),
            ],
            AppCard(
              color: AppColors.softBlue,
              child: Column(
                children: [
                  _TotalRow(
                    label: 'Total sin descuentos',
                    value: formatMoney(
                      comparison.totalOriginal,
                      compactCents: false,
                    ),
                  ),
                  _TotalRow(
                    label: 'Total descuentos',
                    value: '- ${formatMoney(comparison.totalDiscount)}',
                    green: true,
                  ),
                  const Divider(color: AppColors.line),
                  _TotalRow(
                    label: 'Total con descuentos',
                    value: formatMoney(
                      comparison.totalFinal,
                      compactCents: false,
                    ),
                    green: true,
                    large: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Los descuentos se aplican segun tus medios de pago seleccionados.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.deepBlue, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class MixedBreakdownScreen extends StatelessWidget {
  const MixedBreakdownScreen({super.key, required this.plan});

  final MultiStoreComparison plan;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.chevron_left),
        ),
        title: const Column(
          children: [
            Text('Mejor por producto'),
            Text(
              'Compra cada item donde conviene',
              style: TextStyle(
                color: AppColors.deepBlue,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Cerrar',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: ScreenFrame(
        child: ListView(
          children: [
            AppCard(
              color: const Color(0xFFEAF8F0),
              borderColor: const Color(0xFFC7EFD8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total combinando supers',
                          style: TextStyle(
                            color: AppColors.deepBlue,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          formatMoney(plan.totalFinal, compactCents: false),
                          style: const TextStyle(
                            color: AppColors.green,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          plan.storeCount == 1
                              ? 'Conviene en 1 supermercado'
                              : 'Conviene repartir en ${plan.storeCount} supermercados',
                          style: const TextStyle(
                            color: AppColors.green,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 54,
                    height: 54,
                    decoration: const BoxDecoration(
                      color: AppColors.green,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.route_outlined,
                      color: AppColors.white,
                      size: 30,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            for (final item in plan.items) ...[
              _MixedBreakdownLine(item: item),
              const SizedBox(height: 10),
            ],
            if (plan.missingProducts.isNotEmpty) ...[
              AppCard(
                color: const Color(0xFFFFF8E6),
                borderColor: const Color(0xFFFFE7B3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Productos sin precio',
                      style: TextStyle(
                        color: AppColors.deepBlue,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final product in plan.missingProducts)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          product.name,
                          style: const TextStyle(
                            color: AppColors.textGray,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            AppCard(
              color: AppColors.softBlue,
              child: Column(
                children: [
                  _TotalRow(
                    label: 'Total sin descuentos',
                    value: formatMoney(plan.totalOriginal, compactCents: false),
                  ),
                  _TotalRow(
                    label: 'Total descuentos',
                    value: '- ${formatMoney(plan.totalDiscount)}',
                    green: true,
                  ),
                  const Divider(color: AppColors.line),
                  _TotalRow(
                    label: 'Total combinado',
                    value: formatMoney(plan.totalFinal, compactCents: false),
                    green: true,
                    large: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MixedBreakdownLine extends StatelessWidget {
  const _MixedBreakdownLine({required this.item});

  final PricedCartItem item;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ProductArt(product: item.product, size: 44),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.deepBlue,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    StoreLogo(supermarket: item.supermarket, size: 22),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.supermarket.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.deepBlue,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.product.presentation} x ${item.quantity}',
                  style: const TextStyle(
                    color: AppColors.textGray,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            formatMoney(item.discount.precioFinal, compactCents: false),
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: AppColors.green,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _MissingProductsCard extends StatelessWidget {
  const _MissingProductsCard({required this.comparison});

  final StoreComparison comparison;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: const Color(0xFFFFF8E6),
      borderColor: const Color(0xFFFFE7B3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${comparison.supermarket.name} no tiene',
            style: const TextStyle(
              color: AppColors.deepBlue,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          for (final product in comparison.missingProducts)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                product.name,
                style: const TextStyle(
                  color: AppColors.textGray,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(
            'PRODUCTO',
            style: TextStyle(color: AppColors.textGray, fontSize: 10),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            'DESCUENTO',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textGray, fontSize: 10),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            'FINAL',
            textAlign: TextAlign.end,
            style: TextStyle(color: AppColors.textGray, fontSize: 10),
          ),
        ),
      ],
    );
  }
}

class _BreakdownLine extends StatelessWidget {
  const _BreakdownLine({required this.item});

  final PricedCartItem item;

  @override
  Widget build(BuildContext context) {
    final discount = item.discount;
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ProductArt(product: item.product, size: 44),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.deepBlue,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '${item.product.presentation} x ${item.quantity}',
                  style: const TextStyle(
                    color: AppColors.deepBlue,
                    fontSize: 11,
                  ),
                ),
                Text(
                  formatMoney(discount.precioOriginal),
                  style: const TextStyle(
                    color: AppColors.textGray,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              discount.descuentoAplicado
                  ? '${formatPercent(discount.porcentaje)}\n-${formatMoney(discount.importeDescuento)}'
                  : '-',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: discount.descuentoAplicado
                    ? AppColors.green
                    : AppColors.textGray,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              formatMoney(discount.precioFinal, compactCents: false),
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: AppColors.green,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.green = false,
    this.large = false,
  });

  final String label;
  final String value;
  final bool green;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.deepBlue,
                fontWeight: large ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: green ? AppColors.green : AppColors.deepBlue,
              fontSize: large ? 18 : 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
