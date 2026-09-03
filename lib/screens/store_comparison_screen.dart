import 'package:flutter/material.dart';

import '../models/store_comparison.dart';
import '../state/app_scope.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';
import '../widgets/app_card.dart';
import '../widgets/screen_frame.dart';
import '../widgets/store_logo.dart';

class StoreComparisonScreen extends StatefulWidget {
  const StoreComparisonScreen({super.key});

  @override
  State<StoreComparisonScreen> createState() => _StoreComparisonScreenState();
}

class _StoreComparisonScreenState extends State<StoreComparisonScreen> {
  var _expandAll = false;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final bestPerProduct = state.bestPerProductPlan;
    final hasBestPerProduct =
        bestPerProduct != null && bestPerProduct.items.isNotEmpty;
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
            Text('Elegi donde comprar'),
            Text(
              'Compara en todos los supermercados',
              style: TextStyle(
                color: AppColors.deepBlue,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: ScreenFrame(
        child: state.cartComparisons.isEmpty && !hasBestPerProduct
            ? const _NoStoreOptions()
            : ListView.separated(
                itemCount:
                    state.cartComparisons.length + (hasBestPerProduct ? 3 : 2),
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (index < state.cartComparisons.length) {
                    final comparison = state.cartComparisons[index];
                    return _StoreOptionCard(
                      comparison: comparison,
                      best: index == 0 && comparison.hasAllProducts,
                      expandedByParent: _expandAll,
                    );
                  }
                  if (index == state.cartComparisons.length) {
                    return OutlinedButton(
                      onPressed: () => setState(() => _expandAll = !_expandAll),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _expandAll
                                ? 'Ocultar detalle de cada opcion'
                                : 'Ver detalle de cada opcion',
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _expandAll
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                          ),
                        ],
                      ),
                    );
                  }
                  if (hasBestPerProduct &&
                      index == state.cartComparisons.length + 1) {
                    return _BestPerProductOptionCard(plan: bestPerProduct);
                  }
                  return const AppCard(
                    color: AppColors.softBlue,
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.blue),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Los totales incluyen los descuentos segun tus medios de pago seleccionados.',
                            style: TextStyle(
                              color: AppColors.deepBlue,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _BestPerProductOptionCard extends StatefulWidget {
  const _BestPerProductOptionCard({required this.plan});

  final MultiStoreComparison plan;

  @override
  State<_BestPerProductOptionCard> createState() =>
      _BestPerProductOptionCardState();
}

class _BestPerProductOptionCardState extends State<_BestPerProductOptionCard> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    return AppCard(
      color: const Color(0xFFEAF8F0),
      borderColor: const Color(0xFFC7EFD8),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                const Icon(
                  Icons.route_outlined,
                  color: AppColors.green,
                  size: 42,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Flexible(
                            child: Text(
                              'Por producto',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.deepBlue,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.green.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'MEJOR MIX',
                              style: TextStyle(
                                color: AppColors.green,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        plan.storeCount == 1
                            ? 'Todo queda en 1 supermercado'
                            : 'Reparte la compra en ${plan.storeCount} supermercados',
                        style: const TextStyle(
                          color: AppColors.deepBlue,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatMoney(plan.totalFinal, compactCents: false),
                      style: const TextStyle(
                        color: AppColors.green,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: AppColors.deepBlue,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 12),
            for (final item in plan.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    StoreLogo(supermarket: item.supermarket, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${item.supermarket.name}: ${item.product.name} x ${item.quantity}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.deepBlue,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatMoney(item.discount.precioFinal),
                      style: const TextStyle(
                        color: AppColors.green,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _StoreOptionCard extends StatefulWidget {
  const _StoreOptionCard({
    required this.comparison,
    required this.best,
    required this.expandedByParent,
  });

  final StoreComparison comparison;
  final bool best;
  final bool expandedByParent;

  @override
  State<_StoreOptionCard> createState() => _StoreOptionCardState();
}

class _StoreOptionCardState extends State<_StoreOptionCard> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final comparison = widget.comparison;
    final expanded = _expanded || widget.expandedByParent;
    return AppCard(
      color: widget.best ? const Color(0xFFEAF8F0) : AppColors.white,
      borderColor: widget.best ? const Color(0xFFC7EFD8) : AppColors.line,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                StoreLogo(supermarket: comparison.supermarket, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              comparison.supermarket.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.deepBlue,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (widget.best) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.green.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'MEJOR OPCION',
                                style: TextStyle(
                                  color: AppColors.green,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        comparison.hasAllProducts
                            ? 'Total con descuentos'
                            : 'Subtotal disponible',
                        style: const TextStyle(
                          color: AppColors.deepBlue,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        comparison.hasAllProducts
                            ? 'Tiene todos los productos'
                            : 'Tiene ${comparison.foundProductsCount} de ${comparison.totalProductsCount}',
                        style: const TextStyle(
                          color: AppColors.textGray,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatMoney(comparison.totalFinal, compactCents: false),
                      style: const TextStyle(
                        color: AppColors.deepBlue,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Ahorras ${formatMoney(comparison.totalDiscount)}',
                      style: const TextStyle(
                        color: AppColors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!comparison.hasAllProducts) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFE7B3)),
              ),
              child: const Text(
                'Este supermercado no tiene todos los productos de tu changuito.',
                style: TextStyle(color: AppColors.deepBlue, fontSize: 12),
              ),
            ),
          ],
          if (expanded) ...[
            const SizedBox(height: 12),
            for (final item in comparison.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${item.product.name} x ${item.quantity}',
                        style: const TextStyle(
                          color: AppColors.deepBlue,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      formatMoney(item.discount.precioFinal),
                      style: const TextStyle(
                        color: AppColors.green,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            for (final product in comparison.missingProducts)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        product.name,
                        style: const TextStyle(
                          color: AppColors.textGray,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Text(
                      'No lo tiene',
                      style: TextStyle(
                        color: AppColors.textGray,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _NoStoreOptions extends StatelessWidget {
  const _NoStoreOptions();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: AppCard(
        color: Color(0xFFFFF8E6),
        borderColor: Color(0xFFFFE7B3),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.deepBlue),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'No encontramos ningun supermercado con precios disponibles para este changuito.',
                style: TextStyle(color: AppColors.deepBlue, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
