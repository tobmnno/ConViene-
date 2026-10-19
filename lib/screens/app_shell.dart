import 'dart:async';

import 'package:flutter/material.dart';

import '../state/app_scope.dart';
import '../theme/app_theme.dart';
import 'barcode_scanner_screen.dart';
import 'cart_screen.dart';
import 'discounts_screen.dart';
import 'home_screen.dart';
import 'search_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.darkMode,
    required this.onToggleDarkMode,
    this.username = 'usuario',
    this.onSignOut,
  });

  final bool darkMode;
  final VoidCallback onToggleDarkMode;
  final String username;
  final Future<void> Function()? onSignOut;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  var _index = 0;
  Timer? _dateRolloverTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleDateRollover();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dateRolloverTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      unawaited(AppScope.of(context).refreshPromotionsForTodayIfNeeded());
    }
  }

  void _scheduleDateRollover() {
    final now = DateTime.now();
    final nextDay = DateTime(now.year, now.month, now.day + 1);
    _dateRolloverTimer = Timer(nextDay.difference(now), () {
      if (!mounted) return;
      unawaited(AppScope.of(context).refreshPromotionsForTodayIfNeeded());
      _scheduleDateRollover();
    });
  }

  Future<void> _openScanner() async {
    final code = await scanBarcode(context);
    if (!mounted || code == null) return;
    setState(() => _index = 1);
    unawaited(AppScope.of(context).searchProducts(code));
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final pages = [
      HomeScreen(
        onNavigateToSearch: () => setState(() => _index = 1),
        onNavigateToCart: () => setState(() => _index = 3),
        darkMode: widget.darkMode,
        onToggleDarkMode: widget.onToggleDarkMode,
        username: widget.username,
        onSignOut: widget.onSignOut,
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
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 170),
                reverseDuration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 130),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                child: KeyedSubtree(
                  key: ValueKey(_index),
                  child: pages[_index],
                ),
              ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: state.isBootstrapping
          ? null
          : SizedBox(
              width: 68,
              height: 68,
              child: FloatingActionButton(
                heroTag: 'scan-barcode',
                tooltip: 'Escanear codigo de barras',
                onPressed: _openScanner,
                backgroundColor: AppColors.blue,
                foregroundColor: Colors.white,
                elevation: 2,
                shape: const CircleBorder(),
                child: const Icon(Icons.qr_code_scanner, size: 31),
              ),
            ),
      bottomNavigationBar: state.isBootstrapping
          ? null
          : BottomAppBar(
              color: AppColors.surface,
              elevation: 3,
              shape: const CircularNotchedRectangle(),
              notchMargin: 7,
              padding: EdgeInsets.zero,
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: 68,
                  child: Row(
                    children: [
                      _NavItem(
                        label: 'Inicio',
                        icon: Icons.home_outlined,
                        activeIcon: Icons.home,
                        selected: _index == 0,
                        onTap: () => setState(() => _index = 0),
                      ),
                      _NavItem(
                        label: 'Buscar',
                        icon: Icons.search,
                        activeIcon: Icons.manage_search,
                        selected: _index == 1,
                        onTap: () => setState(() => _index = 1),
                      ),
                      const SizedBox(width: 76),
                      _NavItem(
                        label: 'Descuentos',
                        icon: Icons.local_offer_outlined,
                        activeIcon: Icons.local_offer,
                        selected: _index == 2,
                        onTap: () {
                          unawaited(state.refreshPromotionsForTodayIfNeeded());
                          setState(() => _index = 2);
                        },
                      ),
                      _NavItem(
                        label: 'Changuito',
                        icon: Icons.shopping_cart_outlined,
                        activeIcon: Icons.shopping_cart,
                        selected: _index == 3,
                        badge: state.cartQuantity,
                        onTap: () => setState(() => _index = 3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final color = selected ? AppColors.accentBlue : AppColors.textGray;
    return Expanded(
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          child: SizedBox.expand(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 32,
                  height: 28,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Center(
                        child: Icon(
                          selected ? activeIcon : icon,
                          color: color,
                          size: 24,
                        ),
                      ),
                      if (badge > 0)
                        Positioned(
                          top: -3,
                          right: -4,
                          child: AnimatedSwitcher(
                            duration: reduceMotion
                                ? Duration.zero
                                : const Duration(milliseconds: 160),
                            child: Container(
                              key: ValueKey(badge),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: AppColors.green,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                badge > 9 ? '9+' : '$badge',
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
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
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
    _timer = Timer(const Duration(milliseconds: 140), () {
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
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedOpacity(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 170),
      opacity: reduceMotion || _visible ? 1 : 0,
      child: Center(
        child: widget.error == null
            ? const CircularProgressIndicator(color: AppColors.blue)
            : Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_off_outlined,
                      color: AppColors.deepBlue,
                      size: 38,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      widget.error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.deepBlue),
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
