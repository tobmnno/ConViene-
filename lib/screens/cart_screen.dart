import 'dart:async';

import 'package:flutter/material.dart';

import '../models/cart_item.dart';
import '../models/product.dart';
import '../models/store_comparison.dart';
import '../services/product_offer_details.dart';
import '../state/app_scope.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';
import '../widgets/app_card.dart';
import '../widgets/price_block.dart';
import '../widgets/product_art.dart';
import '../widgets/quantity_stepper.dart';
import '../widgets/screen_frame.dart';
import '../widgets/store_logo.dart';
import '../widgets/conviene_loader.dart';
import '../widgets/cart_quantity_notice.dart';
import 'breakdown_screen.dart';
import 'store_comparison_screen.dart';
import 'cart_share_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _scrollController = ScrollController();
  final _lineKeys = <String, GlobalKey>{};
  String? _anchoredLine;
  double? _anchoredTop;
  bool _adjustmentQueued = false;
  int _quantityGeneration = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _lineId(CartItem item) =>
      '${item.productId}|${item.selectedStoreId ?? ''}';

  GlobalKey _lineKey(CartItem item) =>
      _lineKeys.putIfAbsent(_lineId(item), GlobalKey.new);

  void _restoreLinePosition() {
    final id = _anchoredLine;
    final top = _anchoredTop;
    if (!mounted ||
        id == null ||
        top == null ||
        !_scrollController.hasClients) {
      return;
    }
    final box = _lineKeys[id]?.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final delta = box.localToGlobal(Offset.zero).dy - top;
    if (delta.abs() < 0.5) return;
    final position = _scrollController.position;
    final target = (_scrollController.offset + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((target - _scrollController.offset).abs() > 0.5) {
      _scrollController.jumpTo(target);
    }
  }

  void _queueLineAdjustment() {
    if (_anchoredLine == null || _adjustmentQueued) return;
    _adjustmentQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _adjustmentQueued = false;
      _restoreLinePosition();
    });
  }

  void _updateQuantity(AppState state, CartItem item, int quantity) {
    final generation = ++_quantityGeneration;
    final currentQuantity = state.cartItems
        .where(
          (current) =>
              current.productId == item.productId &&
              current.selectedStoreId == item.selectedStoreId,
        )
        .map((current) => current.quantity)
        .firstOrNull;
    if (currentQuantity == null) return;
    final nextQuantity = currentQuantity + (quantity - item.quantity);
    final id = _lineId(item);
    final box = _lineKeys[id]?.currentContext?.findRenderObject();
    if (box is RenderBox && box.hasSize) {
      _anchoredLine = id;
      _anchoredTop = box.localToGlobal(Offset.zero).dy;
    } else {
      _anchoredLine = null;
      _anchoredTop = null;
    }
    unawaited(
      state
          .updateCartQuantity(
            item.productId,
            nextQuantity,
            selectedStoreId: item.selectedStoreId,
          )
          .whenComplete(() {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (generation != _quantityGeneration) return;
              _restoreLinePosition();
              _anchoredLine = null;
              _anchoredTop = null;
            });
          }),
    );
  }

  Widget _buildCartLine(
    AppState state,
    CartItem item, {
    PricedCartItem? pricedLine,
    Product? missingProduct,
  }) => KeyedSubtree(
    key: _lineKey(item),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CartLine(
          cartItem: item,
          pricedLine: pricedLine,
          missingProduct: missingProduct,
          onQuantityChanged: (quantity) =>
              _updateQuantity(state, item, quantity),
        ),
        if (pricedLine != null)
          CartQuantityNotice(
            key: ValueKey('${_lineId(item)}|${item.quantity}'),
            line: pricedLine,
            onAccept: () => _updateQuantity(state, item, 2),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    _queueLineAdjustment();
    final state = AppScope.of(context);
    final selectedPlan = state.selectedStoresPlan;
    final bestSingleStore = state.bestCompleteComparison;
    final bestPerProduct = state.bestPerProductPlan;
    final completeComparisons = state.cartComparisons
        .where((comparison) => comparison.hasAllProducts)
        .toList();
    final comparisonSaving =
        bestSingleStore != null && completeComparisons.length > 1
        ? completeComparisons.last.totalFinal - bestSingleStore.totalFinal
        : 0.0;

    return ScreenFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mi changuito',
                      style: TextStyle(
                        color: AppColors.deepBlue,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      state.cartQuantity == 1
                          ? '1 producto'
                          : '${state.cartQuantity} productos',
                      style: const TextStyle(
                        color: AppColors.blue,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Compartir imagen del changuito',
                onPressed: state.cartItems.isEmpty
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (context) => const CartShareScreen(),
                        ),
                      ),
                icon: Icon(Icons.ios_share_outlined, color: AppColors.deepBlue),
              ),
              IconButton(
                tooltip: 'Actualizar precios',
                onPressed: state.cartItems.isEmpty || state.isComparing
                    ? null
                    : () => unawaited(
                        state.refreshComparisons(forceRefreshPrices: true),
                      ),
                icon: Icon(Icons.refresh, color: AppColors.deepBlue),
              ),
              IconButton(
                tooltip: 'Vaciar',
                onPressed: state.cartItems.isEmpty
                    ? null
                    : () => _confirmClearCart(context, state),
                icon: Icon(Icons.delete_outline, color: AppColors.deepBlue),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: ConvieneLoader(
              compact: true,
              active: state.isComparing,
              message: 'Comparando precios reales',
            ),
          ),
          if (state.cartItems.isEmpty)
            const Expanded(child: _EmptyCart())
          else ...[
            Expanded(
              child: ListView(
                controller: _scrollController,
                children: [
                  Text(
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
                      _buildCartLine(
                        state,
                        state.cartItems.firstWhere(
                          (cartItem) =>
                              cartItem.productId ==
                                  (item.cartProductId ?? item.product.id) &&
                              cartItem.selectedStoreId == item.supermarket.id,
                          orElse: () => CartItem(
                            productId: item.cartProductId ?? item.product.id,
                            quantity: item.quantity,
                            selectedStoreId: item.supermarket.id,
                          ),
                        ),
                        pricedLine: item,
                      ),
                      const SizedBox(height: 10),
                    ],
                    for (final product in selectedPlan.missingProducts) ...[
                      _buildCartLine(
                        state,
                        state.cartItems.firstWhere(
                          (item) => item.productId == product.id,
                          orElse: () =>
                              CartItem(productId: product.id, quantity: 1),
                        ),
                        missingProduct: product,
                      ),
                      const SizedBox(height: 10),
                    ],
                  ] else ...[
                    for (final item in state.cartItems) ...[
                      _buildCartLine(state, item),
                      const SizedBox(height: 10),
                    ],
                  ],
                  const SizedBox(height: 8),
                  if (selectedPlan != null) ...[
                    _SelectedPlanCard(plan: selectedPlan),
                    const SizedBox(height: 12),
                  ],
                  if (bestSingleStore != null) ...[
                    _BestStoreCard(
                      comparison: bestSingleStore,
                      comparisonSaving: comparisonSaving,
                      hasAlternative: completeComparisons.length > 1,
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                    _NoComparisonHint(
                      isComparing:
                          state.isComparing ||
                          state.isSearching ||
                          state.isLoadingPromotions ||
                          state.isBootstrapping,
                      hasMixedPrices: bestPerProduct?.items.isNotEmpty == true,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (bestPerProduct != null &&
                      bestPerProduct.items.isNotEmpty) ...[
                    _BestPerProductCard(
                      plan: bestPerProduct,
                      comparisonSaving:
                          bestPerProduct.hasAllProducts &&
                              bestSingleStore != null
                          ? bestSingleStore.totalFinal -
                                bestPerProduct.totalFinal
                          : 0,
                    ),
                    const SizedBox(height: 18),
                  ],
                  if (state.cartComparisons.isNotEmpty) ...[
                    _ComparisonCoverageCard(comparisons: state.cartComparisons),
                    const SizedBox(height: 18),
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
                  Flexible(
                    child: Text(
                      'Ver todas las opciones',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

  Future<void> _confirmClearCart(BuildContext context, AppState state) async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vaciar changuito'),
        content: const Text(
          'Se quitaran todos los productos y sus comparaciones actuales.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Vaciar'),
          ),
        ],
      ),
    );
    if (shouldClear == true) {
      await state.clearCart();
    }
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
                Text(
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
                  style: TextStyle(
                    color: AppColors.textGray,
                    fontSize: 12,
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
                formatMoney(plan.totalFinal, compactCents: false),
                style: TextStyle(
                  color: AppColors.deepBlue,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (!plan.hasAllProducts)
                Text(
                  'Subtotal',
                  style: TextStyle(color: AppColors.textGray, fontSize: 10),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BestStoreCard extends StatelessWidget {
  const _BestStoreCard({
    required this.comparison,
    required this.comparisonSaving,
    required this.hasAlternative,
  });

  final StoreComparison comparison;
  final double comparisonSaving;
  final bool hasAlternative;

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
        color: AppColors.successSurface,
        borderColor: AppColors.successBorder,
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
                    hasAlternative && comparisonSaving > 0.01
                        ? 'En ${comparison.supermarket.name} gastas menos'
                        : 'Todos los productos verificados en ${comparison.supermarket.name}',
                    style: TextStyle(
                      color: AppColors.deepBlue,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (comparisonSaving > 0.01) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Hasta ${formatMoney(comparisonSaving)} menos que otra opción completa',
                      style: const TextStyle(
                        color: AppColors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                  if (comparison.totalDiscount > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Descuentos ${formatMoney(comparison.totalDiscount)}',
                      style: const TextStyle(
                        color: AppColors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
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
                Icon(Icons.chevron_right, color: AppColors.deepBlue),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BestPerProductCard extends StatelessWidget {
  const _BestPerProductCard({
    required this.plan,
    required this.comparisonSaving,
  });

  final MultiStoreComparison plan;
  final double comparisonSaving;

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
        color: AppColors.successSurface,
        borderColor: AppColors.successBorder,
        child: Row(
          children: [
            const Icon(Icons.route_outlined, color: AppColors.green, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.hasAllProducts
                        ? 'MEJOR POR PRODUCTO'
                        : 'PRECIOS DISPONIBLES',
                    style: const TextStyle(
                      color: AppColors.green,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    !plan.hasAllProducts
                        ? 'Faltan productos por verificar'
                        : plan.storeCount == 1
                        ? 'Todo conviene en el mismo super'
                        : 'Conviene repartir en ${plan.storeCount} supers',
                    style: TextStyle(
                      color: AppColors.deepBlue,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (comparisonSaving > 0.01) ...[
                    const SizedBox(height: 6),
                    Text(
                      '${formatMoney(comparisonSaving)} menos que en un solo super',
                      style: const TextStyle(
                        color: AppColors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                  if (plan.totalDiscount > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Descuentos ${formatMoney(plan.totalDiscount)}',
                      style: const TextStyle(
                        color: AppColors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
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
                if (!plan.hasAllProducts)
                  Text(
                    'Subtotal',
                    style: TextStyle(color: AppColors.textGray, fontSize: 10),
                  ),
                Icon(Icons.chevron_right, color: AppColors.deepBlue),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ComparisonCoverageCard extends StatelessWidget {
  const _ComparisonCoverageCard({required this.comparisons});

  final List<StoreComparison> comparisons;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => const StoreComparisonScreen(),
        ),
      ),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.storefront_outlined, color: AppColors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Comparacion por supermercado',
                    style: TextStyle(
                      color: AppColors.deepBlue,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: AppColors.deepBlue),
              ],
            ),
            const SizedBox(height: 12),
            for (final comparison in comparisons) ...[
              _ComparisonCoverageRow(comparison: comparison),
              if (comparison != comparisons.last) const Divider(height: 18),
            ],
          ],
        ),
      ),
    );
  }
}

class _ComparisonCoverageRow extends StatelessWidget {
  const _ComparisonCoverageRow({required this.comparison});

  final StoreComparison comparison;

  @override
  Widget build(BuildContext context) {
    final hasProducts = comparison.items.isNotEmpty;
    return Row(
      children: [
        StoreLogo(supermarket: comparison.supermarket, size: 28),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                comparison.supermarket.name,
                style: TextStyle(
                  color: AppColors.deepBlue,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                hasProducts
                    ? comparison.hasAllProducts
                          ? 'Todos los productos comparados'
                          : 'Comparados ${comparison.foundProductsCount} de ${comparison.totalProductsCount}'
                    : comparison.hasSourceError
                    ? 'No se pudo consultar'
                    : 'Sin coincidencias verificadas',
                style: TextStyle(
                  color: hasProducts ? AppColors.textGray : AppColors.textGray,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        if (hasProducts)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatMoney(comparison.totalFinal, compactCents: false),
                style: TextStyle(
                  color: AppColors.deepBlue,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                comparison.hasAllProducts ? 'total' : 'subtotal',
                style: TextStyle(
                  color: AppColors.textGray,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _CartLine extends StatelessWidget {
  const _CartLine({
    required this.cartItem,
    this.pricedLine,
    this.missingProduct,
    this.onQuantityChanged,
  });

  final CartItem cartItem;
  final PricedCartItem? pricedLine;
  final Product? missingProduct;
  final ValueChanged<int>? onQuantityChanged;

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

    final selectedStoreName =
        line?.supermarket.name ??
        state.supermarkets
            .where((store) => store.id == cartItem.selectedStoreId)
            .map((store) => store.name)
            .firstOrNull;

    return AppCard(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProductArt(product: product, size: 66),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.deepBlue,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      product.presentation,
                      style: TextStyle(color: AppColors.deepBlue, fontSize: 12),
                    ),
                    if (selectedStoreName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        selectedStoreName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textGray,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (line != null)
                      Text(
                        priceSourceLine(line.price),
                        maxLines: 2,
                        style: TextStyle(
                          color: AppColors.textGray,
                          fontSize: 10,
                        ),
                      ),
                  ],
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
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              QuantityStepper(
                quantity: cartItem.quantity,
                onChanged:
                    onQuantityChanged ??
                    (value) => unawaited(
                      state.updateCartQuantity(
                        cartItem.productId,
                        value,
                        selectedStoreId: cartItem.selectedStoreId,
                      ),
                    ),
              ),
              const SizedBox(width: 8),
              if (line != null)
                Flexible(
                  child: PriceBlock(discount: line.discount, alignEnd: true),
                )
              else
                Flexible(
                  child: Text(
                    state.isComparing ||
                            state.isSearching ||
                            state.isLoadingPromotions ||
                            state.isBootstrapping
                        ? 'Buscando precio'
                        : 'Sin precio actual',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      color: AppColors.textGray,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
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
    return Center(
      child: Text(
        'Agrega productos desde Buscar para comparar tu compra completa.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textGray),
      ),
    );
  }
}

class _NoComparisonHint extends StatelessWidget {
  const _NoComparisonHint({
    required this.isComparing,
    required this.hasMixedPrices,
  });

  final bool isComparing;
  final bool hasMixedPrices;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.warningSurface,
      borderColor: AppColors.warningBorder,
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.deepBlue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isComparing
                  ? 'Estamos verificando los precios de cada supermercado.'
                  : hasMixedPrices
                  ? 'Ningun supermercado tiene el changuito completo verificado. Mira la combinacion por producto.'
                  : 'Todavia no encontramos precios disponibles para estos productos en los supermercados seleccionados.',
              style: TextStyle(color: AppColors.deepBlue, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
