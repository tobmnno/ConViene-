import 'dart:async';

import 'package:flutter/material.dart';

import '../models/payment_method.dart';
import '../models/supermarket.dart';
import '../state/app_scope.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';
import '../widgets/app_card.dart';
import '../widgets/conviene_logo.dart';
import '../widgets/payment_method_logo.dart';
import '../widgets/screen_frame.dart';
import '../widgets/store_logo.dart';
import 'payment_methods_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.onNavigateToSearch,
    required this.onNavigateToCart,
  });

  final VoidCallback onNavigateToSearch;
  final VoidCallback onNavigateToCart;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final searchQuery = AppScope.of(context).searchQuery;
    if (!_focusNode.hasFocus && _controller.text != searchQuery) {
      _controller.text = searchQuery;
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final best = state.bestCompleteComparison;
    final savings = best?.totalDiscount ?? 0;
    final activePaymentMethods = state.activePaymentMethods;

    return ScreenFrame(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const ConvieneLogo(compact: true),
                    IconButton(
                      tooltip: 'Notificaciones',
                      onPressed: () {},
                      icon: const Icon(
                        Icons.notifications_none,
                        color: AppColors.deepBlue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                const Text(
                  'Hola, Lucio!',
                  style: TextStyle(
                    color: AppColors.deepBlue,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Que producto queres buscar hoy?',
                  style: TextStyle(color: AppColors.deepBlue, fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _submitSearch,
                  decoration: InputDecoration(
                    hintText: 'Buscar producto...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      tooltip: 'Buscar',
                      onPressed: () => _submitSearch(_controller.text),
                      icon: const Icon(
                        Icons.arrow_forward,
                        color: AppColors.blue,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tus medios de pago',
                      style: TextStyle(
                        color: AppColors.deepBlue,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    TextButton(
                      onPressed: () => _openPaymentMethods(context),
                      child: const Text(
                        'Editar',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 104,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) {
                      if (index == activePaymentMethods.length) {
                        return _AddPaymentMethodHomeCard(
                          onTap: () => _openPaymentMethods(context),
                        );
                      }
                      final method = activePaymentMethods[index];
                      return _PaymentMethodSelectionCard(
                        method: method,
                        onTap: () =>
                            unawaited(state.togglePaymentMethod(method.id)),
                      );
                    },
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 10),
                    itemCount: activePaymentMethods.length + 1,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Supermercados',
                      style: TextStyle(
                        color: AppColors.deepBlue,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: const Text(
                        'Editar',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 112,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  if (index == state.enabledSupermarkets.length) {
                    return const _AddStoreCard();
                  }
                  final store = state.enabledSupermarkets[index];
                  final selected = state.selectedStoreIds.contains(store.id);
                  return _StoreSelectionCard(
                    supermarket: store,
                    selected: selected,
                    onTap: () => unawaited(state.toggleStore(store.id)),
                  );
                },
                separatorBuilder: (context, index) => const SizedBox(width: 10),
                itemCount: state.enabledSupermarkets.length + 1,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 18),
                AppCard(
                  color: const Color(0xFFEAF8F0),
                  borderColor: const Color(0xFFD5F3E1),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Estas ahorrando!',
                              style: TextStyle(
                                color: AppColors.green,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Con Conviene ya encontraste descuentos reales.',
                              style: TextStyle(
                                color: AppColors.deepBlue,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              formatMoney(savings),
                              style: const TextStyle(
                                color: AppColors.green,
                                fontSize: 25,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.trending_up,
                        color: AppColors.green,
                        size: 54,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: widget.onNavigateToCart,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.shopping_cart_outlined),
                      const SizedBox(width: 10),
                      const Text('Ir a mi changuito'),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: const BoxDecoration(
                          color: AppColors.green,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${state.cartQuantity}',
                          style: const TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _submitSearch(String value) {
    final query = value.trim().isEmpty ? 'leche entera' : value.trim();
    _controller.text = query;
    _controller.selection = TextSelection.collapsed(offset: query.length);
    _focusNode.unfocus();
    unawaited(AppScope.of(context).searchProducts(query));
    widget.onNavigateToSearch();
  }

  void _openPaymentMethods(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const PaymentMethodsScreen(),
      ),
    );
  }
}

class _StoreSelectionCard extends StatelessWidget {
  const _StoreSelectionCard({
    required this.supermarket,
    required this.selected,
    required this.onTap,
  });

  final Supermarket supermarket;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 76,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.blue : AppColors.line,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Column(
          children: [
            StoreLogo(supermarket: supermarket, size: 40),
            const Spacer(),
            Text(
              supermarket.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.deepBlue,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selected ? AppColors.blue : AppColors.textGray,
              size: 19,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddStoreCard extends StatelessWidget {
  const _AddStoreCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line, style: BorderStyle.solid),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add, color: AppColors.deepBlue),
          SizedBox(height: 12),
          Text(
            'Agregar',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.deepBlue,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodSelectionCard extends StatelessWidget {
  const _PaymentMethodSelectionCard({
    required this.method,
    required this.onTap,
  });

  final PaymentMethod method;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = switch (method.type) {
      PaymentMethodType.card => AppColors.blue,
      PaymentMethodType.bank => AppColors.deepBlue,
      PaymentMethodType.wallet => AppColors.green,
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 86,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent, width: 1.4),
        ),
        child: Column(
          children: [
            PaymentMethodLogo(method: method, size: 34),
            const Spacer(),
            Text(
              method.displayName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.deepBlue,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 5),
            Icon(Icons.check_circle, color: accent, size: 18),
          ],
        ),
      ),
    );
  }
}

class _AddPaymentMethodHomeCard extends StatelessWidget {
  const _AddPaymentMethodHomeCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 86,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.line),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.tune, color: AppColors.deepBlue),
            SizedBox(height: 12),
            Text(
              'Ver todos',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.deepBlue,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
