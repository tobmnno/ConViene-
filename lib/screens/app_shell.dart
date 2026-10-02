import 'dart:async';

import 'package:flutter/material.dart';

import '../state/app_scope.dart';
import '../theme/app_theme.dart';
import 'cart_screen.dart';
import 'discounts_screen.dart';
import 'home_screen.dart';
import 'search_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final pages = [
      HomeScreen(
        onNavigateToSearch: () => setState(() => _index = 1),
        onNavigateToCart: () => setState(() => _index = 3),
      ),
      SearchScreen(onBack: () => setState(() => _index = 0)),
      const DiscountsScreen(),
      const CartScreen(),
    ];

    return Scaffold(
      body: SafeArea(
        child: state.isBootstrapping
            ? _BootstrappingView(
                error: state.lastError,
                onRetry: state.initialize,
              )
            : AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                reverseDuration: const Duration(milliseconds: 210),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  final offset =
                      Tween<Offset>(
                        begin: const Offset(0.018, 0),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        ),
                      );
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: offset, child: child),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey(_index),
                  child: pages[_index],
                ),
              ),
      ),
      bottomNavigationBar: state.isBootstrapping
          ? null
          : BottomNavigationBar(
              currentIndex: _index,
              onTap: (index) => setState(() => _index = index),
              items: [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home),
                  label: 'Inicio',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.search),
                  activeIcon: Icon(Icons.manage_search),
                  label: 'Buscar',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.local_offer_outlined),
                  activeIcon: Icon(Icons.local_offer),
                  label: 'Descuentos',
                ),
                BottomNavigationBarItem(
                  icon: _CartNavIcon(
                    active: false,
                    quantity: state.cartQuantity,
                  ),
                  activeIcon: _CartNavIcon(
                    active: true,
                    quantity: state.cartQuantity,
                  ),
                  label: 'Changuito',
                ),
              ],
            ),
    );
  }
}

class _CartNavIcon extends StatelessWidget {
  const _CartNavIcon({required this.active, required this.quantity});

  final bool active;
  final int quantity;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 26,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 2,
            bottom: 0,
            child: Icon(
              active ? Icons.shopping_cart : Icons.shopping_cart_outlined,
              color: active ? AppColors.blue : AppColors.deepBlue,
            ),
          ),
          if (quantity > 0)
            Positioned(
              right: -2,
              top: -4,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                transitionBuilder: (child, animation) {
                  return ScaleTransition(scale: animation, child: child);
                },
                child: Container(
                  key: ValueKey(quantity),
                  constraints: const BoxConstraints(
                    minWidth: 17,
                    minHeight: 17,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.green,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    quantity > 9 ? '9+' : '$quantity',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BootstrappingView extends StatefulWidget {
  const _BootstrappingView({this.error, required this.onRetry});

  final String? error;
  final Future<void> Function() onRetry;

  @override
  State<_BootstrappingView> createState() => _BootstrappingViewState();
}

class _BootstrappingViewState extends State<_BootstrappingView> {
  late final Timer _timer;
  var _visible = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 220), () {
      if (mounted) {
        setState(() => _visible = true);
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: _visible ? 1 : 0,
      child: Center(
        child: widget.error == null
            ? const CircularProgressIndicator(color: AppColors.blue)
            : Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_outlined,
                      color: AppColors.deepBlue,
                      size: 38,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      widget.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.deepBlue),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => widget.onRetry(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
