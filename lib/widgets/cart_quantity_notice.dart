import 'dart:async';
import 'package:flutter/material.dart';
import '../models/cart_item.dart';
import '../services/cart_quantity_suggestion.dart';
import '../state/app_scope.dart';
import '../utils/money.dart';

class CartQuantityNotice extends StatefulWidget {
  const CartQuantityNotice({
    super.key,
    required this.line,
    required this.onAccept,
  });
  final PricedCartItem line;
  final VoidCallback onAccept;
  @override
  State<CartQuantityNotice> createState() => _CartQuantityNoticeState();
}

class _CartQuantityNoticeState extends State<CartQuantityNotice> {
  bool _accepted = false;
  Timer? _expiry;
  @override
  void initState() {
    super.initState();
    // Re-check short-lived official evidence even if the cart remains open.
    _expiry = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _expiry?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final suggestion = quantitySuggestion(state, widget.line);
    if (suggestion == null || _accepted) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.primaryContainer.withValues(alpha: .35),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_offer_outlined, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '2x1 en ${widget.line.supermarket.name}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Descartar sugerencia',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(
                      () => state.dismissedQuantitySuggestions.add(
                        suggestion.key,
                      ),
                    ),
                  ),
                ],
              ),
              Text(widget.line.product.name),
              if (suggestion.samePrice)
                const Text('Podés llevar dos por el mismo precio estimado.'),
              Text(
                '1 unidad: ${formatMoney(suggestion.one.precioFinal)} · 2 unidades: ${formatMoney(suggestion.two.precioFinal)}',
              ),
              const Text(
                'Sujeto a condiciones y confirmación en caja.',
                style: TextStyle(fontSize: 11),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('Llevar 2'),
                  onPressed: state.isComparing
                      ? null
                      : () {
                          if (_accepted ||
                              quantitySuggestion(state, widget.line) == null)
                            return;
                          setState(() => _accepted = true);
                          widget.onAccept();
                        },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
