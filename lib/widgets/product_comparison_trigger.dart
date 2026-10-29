import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/product.dart';
import '../state/app_scope.dart';
import 'product_comparison_panel.dart';

class ProductComparisonTrigger extends StatefulWidget {
  const ProductComparisonTrigger({
    super.key,
    required this.product,
    required this.child,
    this.onDetails,
  });
  final Product product;
  final Widget child;
  final VoidCallback? onDetails;
  @override
  State<ProductComparisonTrigger> createState() =>
      _ProductComparisonTriggerState();
}

class _ProductComparisonTriggerState extends State<ProductComparisonTrigger> {
  static _ProductComparisonTriggerState? _active;
  Timer? _enter;
  Timer? _leave;
  PointerDeviceKind? _pointer;
  bool _sheetOpen = false;
  bool _expanded = false;

  void _close({bool update = true}) {
    _enter?.cancel();
    _leave?.cancel();
    if (_expanded) {
      if (update && mounted) {
        setState(() => _expanded = false);
      } else {
        _expanded = false;
      }
    }
    HardwareKeyboard.instance.removeHandler(_keyboard);
    if (_active == this) _active = null;
  }

  bool _keyboard(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      _close();
      return true;
    }
    return false;
  }

  void _showHover() {
    if (!mounted || _expanded || _sheetOpen) return;
    _active?._close();
    _active = this;
    setState(() => _expanded = true);
    HardwareKeyboard.instance.addHandler(_keyboard);
  }

  void _scheduleClose() {
    _enter?.cancel();
    _leave?.cancel();
    _leave = Timer(const Duration(milliseconds: 180), _close);
  }

  void _tap() {
    _close();
    _active?._close();
    if (_sheetOpen) return;
    if (_pointer == PointerDeviceKind.mouse && widget.onDetails != null) {
      widget.onDetails!();
      return;
    }
    final state = AppScope.of(context);
    _sheetOpen = true;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => AppScope(
        notifier: state,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .8,
          ),
          child: SingleChildScrollView(
            child: ProductComparisonPanel(
              product: widget.product,
              onDetails: widget.onDetails == null
                  ? null
                  : () {
                      Navigator.pop(sheetContext);
                      widget.onDetails!();
                    },
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      _sheetOpen = false;
    });
  }

  @override
  void didUpdateWidget(ProductComparisonTrigger oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product != widget.product) _close();
  }

  @override
  void dispose() {
    _close(update: false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FocusableActionDetector(
    shortcuts: const {
      SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
    },
    actions: {
      ActivateIntent: CallbackAction<ActivateIntent>(
        onInvoke: (_) {
          _tap();
          return null;
        },
      ),
    },
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        _leave?.cancel();
        _enter?.cancel();
        _enter = Timer(const Duration(milliseconds: 350), _showHover);
      },
      onExit: (_) => _scheduleClose(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Listener(
            onPointerDown: (event) => _pointer = event.kind,
            child: Semantics(
              button: true,
              label: 'Comparar ${widget.product.name}',
              child: GestureDetector(onTap: _tap, child: widget.child),
            ),
          ),
          ClipRect(
            child: AnimatedSize(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _expanded
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(8),
                        clipBehavior: Clip.antiAlias,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 300),
                          child: SingleChildScrollView(
                            child: ProductComparisonPanel(
                              product: widget.product,
                              onDetails: widget.onDetails == null
                                  ? null
                                  : () {
                                      _close();
                                      widget.onDetails!();
                                    },
                            ),
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    ),
  );
}
