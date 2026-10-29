import 'package:flutter/material.dart';

import '../models/product.dart';
import '../models/price_quote.dart';
import '../repositories/product_equivalence_repository.dart';
import '../state/app_scope.dart';
import '../state/app_state.dart';
import '../utils/money.dart';
import '../services/product_offer_details.dart';
import 'store_logo.dart';
import 'conviene_loader.dart';

class ProductComparisonPanel extends StatefulWidget {
  const ProductComparisonPanel({
    super.key,
    required this.product,
    this.onDetails,
  });
  final Product product;
  final VoidCallback? onDetails;
  @override
  State<ProductComparisonPanel> createState() => _ProductComparisonPanelState();
}

class _ProductComparisonPanelState extends State<ProductComparisonPanel> {
  String? _key;
  Future<EquivalentProductsResult>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  @override
  void didUpdateWidget(ProductComparisonPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _load();
  }

  void _load({bool refresh = false}) {
    final state = AppScope.of(context);
    final key = state.productComparison.key(
      widget.product,
      state.shoppingContext,
    );
    if (_key == key && !refresh) return;
    _key = key;
    _future = state.productComparison.compare(
      widget.product,
      state.shoppingContext,
      refresh: refresh,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.product.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          FutureBuilder<EquivalentProductsResult>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const ConvieneLoader(
                  message: 'Comparando supermercados',
                );
              }
              final data = snapshot.data;
              if (data == null) return const Text('No se pudo consultar.');
              final rows = sortedProductOffers(state, data.results);
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final row in rows)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          StoreLogo(supermarket: row.supermarket, size: 30),
                          const SizedBox(width: 8),
                          Expanded(child: Text(row.supermarket.name)),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                formatMoney(
                                  state.discountForResult(row).precioFinal,
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (state
                                  .discountForResult(row)
                                  .descuentoAplicado)
                                Text(
                                  'Publicado: ${formatMoney(row.price.priceOriginal)}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              if (state.discountForResult(row).estimated)
                                const Text(
                                  'Estimado',
                                  style: TextStyle(fontSize: 11),
                                ),
                              if (isDeferredRefund(
                                state.discountForResult(row).promocionUsada,
                              ))
                                Text(
                                  'Reintegro est.: ${formatMoney(state.discountForResult(row).importeDescuento)}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  for (final entry in data.storeStatus.entries.where(
                    (e) => e.value != 'found',
                  ))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Expanded(child: Text(storeName(entry.key))),
                          Flexible(
                            child: Text(
                              storeStatusLabel(entry.value),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (data.storeStatus.values.contains('error'))
                    TextButton.icon(
                      onPressed: () => setState(() => _load(refresh: true)),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                ],
              );
            },
          ),
          if (widget.onDetails != null) ...[
            const SizedBox(height: 10),
            FilledButton(
              onPressed: widget.onDetails,
              child: const Text('Ver detalle'),
            ),
          ],
        ],
      ),
    );
  }
}

List<SearchResult> sortedProductOffers(
  AppState state,
  List<SearchResult> rows, {
  int quantity = 1,
}) => [...rows]
  ..sort((a, b) {
    final price = state
        .discountForResult(a, quantity: quantity)
        .precioFinal
        .compareTo(state.discountForResult(b, quantity: quantity).precioFinal);
    return price != 0
        ? price
        : a.supermarket.name.compareTo(b.supermarket.name);
  });

String storeName(String id) => switch (id) {
  'coto' => 'Coto',
  'carrefour' => 'Carrefour',
  'lagallega' => 'La Gallega',
  _ => id,
};
String storeStatusLabel(String status) => switch (status) {
  'error' => 'No se pudo consultar',
  'unavailable' => 'Sin stock publicado',
  _ => 'Producto no verificado',
};
