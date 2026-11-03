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
                      child: _StorePriceSummary(state: state, row: row),
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

class _StorePriceSummary extends StatelessWidget {
  const _StorePriceSummary({required this.state, required this.row});

  final AppState state;
  final SearchResult row;

  @override
  Widget build(BuildContext context) {
    final quote = state.discountForResult(row);
    final assessments = [
      for (final promotion in [
        ...state.promotions,
        ...row.price.quantityOffers,
      ])
        (
          promotion: promotion,
          status: assessPromotion(
            promotion: promotion,
            result: row,
            date: state.selectedDate,
            paymentMethods: state.activePaymentMethods,
            quantity: 1,
            usedRefundCaps: state.usedRefundCaps,
            appliedPromotionId: quote.promocionUsada?.id,
          ),
        ),
    ];
    final conditionedStore = assessments
        .where(
          (item) =>
              item.status == PromotionAssessment.conditioned &&
              item.promotion.productEans.isEmpty &&
              item.promotion.promotionKind != 'store_product',
        )
        .length;
    final conditionedProduct = assessments
        .where(
          (item) =>
              item.status == PromotionAssessment.conditioned &&
              (item.promotion.productEans.isNotEmpty ||
                  item.promotion.promotionKind == 'store_product'),
        )
        .length;
    final unverified = assessments
        .where((item) => item.status == PromotionAssessment.unverified)
        .length;
    final applied = quote.promocionUsada;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            StoreLogo(supermarket: row.supermarket, size: 30),
            const SizedBox(width: 8),
            Expanded(child: Text(row.supermarket.name)),
            Text(
              formatMoney(quote.precioFinal),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 38),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Publicado: ${formatMoney(row.price.priceOriginal)}',
                style: const TextStyle(fontSize: 11),
              ),
              if (applied != null)
                Text(
                  '${promotionReach(applied)}: ${applied.nombreVisible}${quote.estimated ? ' · estimado' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
              if (isDeferredRefund(applied))
                Text(
                  'Reintegro estimado: ${formatMoney(quote.importeDescuento)}',
                  style: const TextStyle(fontSize: 11),
                ),
              if (conditionedProduct > 0)
                Text(
                  '$conditionedProduct oferta${conditionedProduct == 1 ? '' : 's'} del producto con condiciones',
                  style: const TextStyle(fontSize: 11),
                ),
              if (conditionedStore > 0)
                Text(
                  '$conditionedStore beneficio${conditionedStore == 1 ? '' : 's'} del supermercado con condiciones',
                  style: const TextStyle(fontSize: 11),
                ),
              if (unverified > 0)
                Text(
                  '$unverified beneficio${unverified == 1 ? '' : 's'} sin verificar',
                  style: const TextStyle(fontSize: 11),
                ),
              Text(
                priceSourceLine(row.price),
                style: const TextStyle(fontSize: 11),
              ),
              if (applied?.capturedAt != null)
                Text(
                  'Promo verificada: ${promotionDate(applied!.capturedAt!)}',
                  style: const TextStyle(fontSize: 11),
                ),
              if (applied != null && applied.fuenteUrl.isNotEmpty)
                Text(
                  'Fuente: ${Uri.tryParse(applied.fuenteUrl)?.host ?? applied.fuenteUrl}',
                  style: const TextStyle(fontSize: 11),
                ),
            ],
          ),
        ),
      ],
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
  'jumbo' => 'Jumbo',
  'lareina' => 'La Reina',
  _ => id,
};
String storeStatusLabel(String status) => switch (status) {
  'error' => 'No se pudo consultar',
  'unavailable' => 'Sin stock publicado',
  _ => 'Producto no verificado',
};
