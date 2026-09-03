import 'dart:async';

import 'package:flutter/material.dart';

import '../models/cart_item.dart';
import '../models/product.dart';
import '../models/store_comparison.dart';
import '../state/app_scope.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';
import '../widgets/app_card.dart';
import '../widgets/price_block.dart';
import '../widgets/product_art.dart';
import '../widgets/quantity_stepper.dart';
import '../widgets/screen_frame.dart';
import '../widgets/store_logo.dart';
import 'breakdown_screen.dart';
import 'store_comparison_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final selectedPlan = state.selectedStoresPlan;
    final bestSingleStore = state.bestCompleteComparison;
    final bestPerProduct = state.bestPerProductPlan;

    return ScreenFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Spacer(),
              Column(
                children: [
                  const Text(
                    'Mi changuito',
                    style: TextStyle(
                      color: AppColors.deepBlue,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    '${state.cartQuantity} productos',
                    style: const TextStyle(
                      color: AppColors.blue,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Vaciar',
                onPressed: () => unawaited(state.clearCart()),
                icon: const Icon(
                  Icons.delete_outline,
                  color: AppColors.deepBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (state.cartItems.isEmpty)
            const Expanded(child: _EmptyCart())
          else ...[
            Expanded(
              child: ListView(
                children: [
                  if (selectedPlan != null) ...[
                    _SelectedPlanCard(plan: selectedPlan),
                    const SizedBox(height: 12),
                  ],
                  if (bestSingleStore != null) ...[
                    _BestStoreCard(comparison: bestSingleStore),
                    const SizedBox(height: 12),
                  ] else ...[
                    const _NoComparisonHint(),
                    const SizedBox(height: 12),
                  ],
                  if (bestPerProduct != null &&
                      bestPerProduct.items.isNotEmpty) ...[
                    _BestPerProductCard(plan: bestPerProduct),
                    const SizedBox(height: 18),
                  ],
                  const Text(
                    'Productos elegidos',
                    style: TextStyle(
                      color: AppColors.deepBlue,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (selectedPlan != null) ...[
                    for (final item in selectedPlan.items) ...[
                      _CartLine(
                        cartItem: CartItem(
                          productId: item.cartProductId ?? item.product.id,
                          quantity: item.quantity,
                          selectedStoreId: item.supermarket.id,
                        ),
                        pricedLine: item,
                      ),
                      const SizedBox(height: 10),
                    ],
                    for (final product in selectedPlan.missingProducts) ...[
                      _CartLine(
                        cartItem: state.cartItems.firstWhere(
                          (item) => item.productId == product.id,
                          orElse: () =>
                              CartItem(productId: product.id, quantity: 1),
                        ),
                        missingProduct: product,
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: state.cartComparisons.isEmpty
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => const StoreComparisonScreen(),
                      ),
                    ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_checkout),
                  SizedBox(width: 10),
                  Text('Ver todas las opciones'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SelectedPlanCard extends StatelessWidget {
  const _SelectedPlanCard({required this.plan});

  final MultiStoreComparison plan;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.softBlue,
      child: Row(
        children: [
          const Icon(Icons.shopping_bag_outlined, color: AppColors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tu seleccion',
                  style: TextStyle(
                    color: AppColors.deepBlue,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  plan.storeCount == 1
                      ? 'Elegiste productos de 1 supermercado'
                      : 'Elegiste productos de ${plan.storeCount} supermercados',
                  style: const TextStyle(
                    color: AppColors.textGray,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Text(
            formatMoney(plan.totalFinal, compactCents: false),
            style: const TextStyle(
              color: AppColors.deepBlue,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _BestStoreCard extends StatelessWidget {
  const _BestStoreCard({required this.comparison});

  final StoreComparison comparison;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => BreakdownScreen(comparison: comparison),
        ),
      ),
      child: AppCard(
        color: const Color(0xFFEAF8F0),
        borderColor: const Color(0xFFC7EFD8),
        child: Row(
          children: [
            StoreLogo(supermarket: comparison.supermarket, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'MEJOR PARA TODO JUNTO',
                    style: TextStyle(
                      color: AppColors.green,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'En ${comparison.supermarket.name} gastas menos',
                    style: const TextStyle(
                      color: AppColors.deepBlue,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
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
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatMoney(comparison.totalFinal, compactCents: false),
                  style: const TextStyle(
                    color: AppColors.green,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.deepBlue),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BestPerProductCard extends StatelessWidget {
  const _BestPerProductCard({required this.plan});

  final MultiStoreComparison plan;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => MixedBreakdownScreen(plan: plan),
        ),
      ),
      child: AppCard(
        color: const Color(0xFFEAF8F0),
        borderColor: const Color(0xFFC7EFD8),
        child: Row(
          children: [
            const Icon(Icons.route_outlined, color: AppColors.green, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'MEJOR POR PRODUCTO',
                    style: TextStyle(
                      color: AppColors.green,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    plan.storeCount == 1
                        ? 'Todo conviene en el mismo super'
                        : 'Conviene repartir en ${plan.storeCount} supers',
                    style: const TextStyle(
                      color: AppColors.deepBlue,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ahorras ${formatMoney(plan.totalDiscount)}',
                    style: const TextStyle(
                      color: AppColors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
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
                const Icon(Icons.chevron_right, color: AppColors.deepBlue),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CartLine extends StatelessWidget {
  const _CartLine({
    required this.cartItem,
    this.pricedLine,
    this.missingProduct,
  });

  final CartItem cartItem;
  final PricedCartItem? pricedLine;
  final Product? missingProduct;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final line = pricedLine;
    final product =
        missingProduct ??
        line?.product ??
        state.productById(cartItem.productId);
    if (product == null) {
      return const SizedBox.shrink();
    }

    return AppCard(
      child: Row(
        children: [
          ProductArt(product: product, size: 66),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.deepBlue,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  product.presentation,
                  style: const TextStyle(
                    color: AppColors.deepBlue,
                    fontSize: 12,
                  ),
                ),
                if (line != null) ...[
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      StoreLogo(supermarket: line.supermarket, size: 22),
                      const SizedBox(width: 5),
                      Text(
                        line.supermarket.name,
                        style: const TextStyle(
                          color: AppColors.deepBlue,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                QuantityStepper(
                  quantity: cartItem.quantity,
                  onChanged: (value) => unawaited(
                    state.updateCartQuantity(
                      cartItem.productId,
                      value,
                      selectedStoreId: cartItem.selectedStoreId,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (line != null)
                PriceBlock(discount: line.discount, alignEnd: true)
              else
                const SizedBox(
                  width: 86,
                  child: Text(
                    'No disponible',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      color: AppColors.textGray,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              IconButton(
                tooltip: 'Eliminar',
                onPressed: () => unawaited(
                  state.removeCartItem(
                    cartItem.productId,
                    selectedStoreId: cartItem.selectedStoreId,
                  ),
                ),
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Agrega productos desde Buscar para comparar tu compra completa.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textGray),
      ),
    );
  }
}

class _NoComparisonHint extends StatelessWidget {
  const _NoComparisonHint();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      color: Color(0xFFFFF8E6),
      borderColor: Color(0xFFFFE7B3),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.deepBlue),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Todavia no encontramos precios disponibles para estos productos en los supermercados seleccionados.',
              style: TextStyle(color: AppColors.deepBlue, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
