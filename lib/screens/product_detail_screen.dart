import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/product.dart';
import '../models/price_quote.dart';
import '../models/discount.dart';
import '../repositories/product_equivalence_repository.dart';
import '../services/product_offer_details.dart';
import '../state/app_scope.dart';
import '../state/app_state.dart';
import '../utils/money.dart';
import '../widgets/product_art.dart';
import '../widgets/store_logo.dart';
import '../widgets/conviene_loader.dart';
import '../widgets/product_comparison_panel.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.product});
  final Product product;
  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  String? _key;
  Future<EquivalentProductsResult>? _future;
  int _quantity = 1;
  int _section = 0;
  bool _adding = false;
  String? _addedStore;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppScope.of(context);
    final key = state.productComparison.key(
      widget.product,
      state.shoppingContext,
    );
    if (_key != key) {
      _key = key;
      _future = state.productComparison.compare(
        widget.product,
        state.shoppingContext,
      );
    }
  }

  Future<void> _add(AppState state, SearchResult row) async {
    if (_adding) return;
    setState(() {
      _adding = true;
      _addedStore = null;
    });
    try {
      await state.addOfferToCart(row, quantity: _quantity);
      if (mounted) setState(() => _addedStore = row.supermarket.id);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _open(Uri uri) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      /* Show the same recoverable message for unsupported platforms. */
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir el enlace oficial.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Producto')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Center(child: ProductArt(product: widget.product, size: 164)),
              const SizedBox(height: 16),
              if (widget.product.brand.trim().isNotEmpty)
                Text(
                  widget.product.brand.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              const SizedBox(height: 4),
              Text(widget.product.name, style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(widget.product.presentation),
              if (widget.product.ean.isNotEmpty)
                SelectableText(
                  'EAN ${widget.product.ean}',
                  style: theme.textTheme.bodySmall,
                ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(child: Text('Cantidad')),
                  IconButton(
                    tooltip: 'Restar unidad',
                    onPressed: _quantity > 1 && !_adding
                        ? () => setState(() {
                            _quantity--;
                            _addedStore = null;
                          })
                        : null,
                    icon: const Icon(Icons.remove),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text('$_quantity', textAlign: TextAlign.center),
                  ),
                  IconButton(
                    tooltip: 'Sumar unidad',
                    onPressed: _quantity < 99 && !_adding
                        ? () => setState(() {
                            _quantity++;
                            _addedStore = null;
                          })
                        : null,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _sectionTab('Precios', 0),
                  _sectionTab('Beneficios', 1),
                ],
              ),
              const SizedBox(height: 16),
              FutureBuilder<EquivalentProductsResult>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const ConvieneLoader(
                      message: 'Consultando precios y beneficios',
                    );
                  }
                  final data = snapshot.data;
                  if (data == null) return const Text('No se pudo consultar.');
                  final rows = sortedProductOffers(
                    state,
                    data.results,
                    quantity: _quantity,
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (rows.isEmpty)
                        const Text('No hay precios verificados para mostrar.'),
                      if (_section == 0)
                        for (var i = 0; i < rows.length; i++)
                          _priceOffer(state, rows[i], isBest: i == 0)
                      else
                        for (final row in rows) _storeBenefits(state, row),
                      for (final entry in data.storeStatus.entries.where(
                        (e) => e.value != 'found',
                      ))
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(storeName(entry.key)),
                          subtitle: Text(storeStatusLabel(entry.value)),
                        ),
                      if (data.storeStatus.values.contains('error'))
                        TextButton.icon(
                          onPressed: () => setState(() {
                            _future = state.productComparison.compare(
                              widget.product,
                              state.shoppingContext,
                              refresh: true,
                            );
                          }),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reintentar'),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              const Text(
                'Estimación sujeta a stock, vigencia y condiciones. Los reintegros dependen del tope disponible; el importe de caja puede variar.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTab(String label, int index) {
    final theme = Theme.of(context);
    final selected = _section == index;
    return Expanded(
      child: Semantics(
        selected: selected,
        child: InkWell(
          onTap: () => setState(() => _section = index),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              Container(
                height: 2,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.dividerColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _priceOffer(AppState state, SearchResult row, {required bool isBest}) {
    final quote = state.discountForResult(row, quantity: _quantity);
    final uri = officialProductUri(row.supermarket.id, row.price.url);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isBest) ...[const Divider(), const SizedBox(height: 12)],
          if (isBest) ...[
            Text(
              'MENOR COSTO ESTIMADO',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              StoreLogo(supermarket: row.supermarket, size: 34),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  row.supermarket.name,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Text(
                formatMoney(quote.precioFinal),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: isBest ? theme.colorScheme.primary : null,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: _addedStore == row.supermarket.id
                    ? 'Agregado a tu changuito'
                    : 'Agregar $_quantity en ${row.supermarket.name}',
                onPressed: _adding ? null : () => _add(state, row),
                icon: Icon(
                  _addedStore == row.supermarket.id
                      ? Icons.check
                      : Icons.add_shopping_cart,
                ),
              ),
            ],
          ),
          if (uri == null)
            const Text(
              'Enlace directo no disponible',
              style: TextStyle(fontSize: 12),
            )
          else
            TextButton.icon(
              onPressed: () => _open(uri),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Ver en sitio oficial'),
            ),
        ],
      ),
    );
  }

  Widget _storeBenefits(AppState state, SearchResult row) {
    final quote = state.discountForResult(row, quantity: _quantity);
    final promotion = quote.promocionUsada;
    final refund = isDeferredRefund(promotion);
    final available = <String, Promotion>{
      for (final p in [...state.promotions, ...row.price.quantityOffers])
        if (p.storeId == row.supermarket.id &&
            p.id != promotion?.id &&
            p.canCalculate &&
            p.appliesOn(state.selectedDate) &&
            p.appliesToProduct(row.product) &&
            p.appliesToCategory(row.product.category))
          p.id: p,
    };
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              StoreLogo(supermarket: row.supermarket, size: 32),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  row.supermarket.name,
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (promotion != null) ...[
            const Text(
              'BENEFICIO APLICADO',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
            ),
            _benefit(
              promotion,
              subtitle:
                  'Ahorro estimado: ${formatMoney(quote.importeDescuento)}',
              extraDetails: [
                Text(
                  'Precio publicado por unidad: ${formatMoney(row.price.priceOriginal)}',
                ),
                Text(
                  'A pagar estimado: ${formatMoney(refund ? quote.precioOriginal : quote.precioFinal)}',
                ),
                if (refund) ...[
                  Text(
                    'Reintegro estimado: ${formatMoney(quote.importeDescuento)}',
                  ),
                  Text(
                    'Costo tras reintegro: ${formatMoney(quote.precioFinal)}',
                  ),
                ],
                if (quote.estimated ||
                    (promotion.topeReintegro > 0 &&
                        promotion.capUsageKey(state.selectedDate) == null))
                  const Text('Tope disponible y costo final sin confirmar.'),
                Text(
                  'Precio consultado: ${promotionDate(row.price.fechaActualizacion)}',
                ),
                if (row.price.hasStoreOffer)
                  const Text('El precio de oferta publicado ya está incluido.'),
              ],
            ),
          ] else if (row.price.hasStoreOffer)
            const Text('Oferta del supermercado incluida en el precio.')
          else if (available.isNotEmpty)
            const Text('No hay beneficios aplicados con tus medios de pago.')
          else
            const Text('Sin beneficios adicionales verificados.'),
          if (available.isNotEmpty)
            ExpansionTile(
              key: ValueKey('other-${row.supermarket.id}'),
              tilePadding: EdgeInsets.zero,
              title: Text('Otros beneficios (${available.length})'),
              children: [
                for (final p in available.values)
                  _benefit(p, subtitle: _pendingReason(state, row, p)),
              ],
            ),
          const Divider(),
        ],
      ),
    );
  }

  String _pendingReason(AppState state, SearchResult row, Promotion p) {
    if (!p.appliesToBranch(row.price.branchId)) return 'Requiere otra sucursal';
    if (!p.isCompatibleWithAny(state.activePaymentMethods))
      return 'Requiere un medio de pago compatible';
    if (_quantity < p.requiredQuantity)
      return 'Requiere ${p.requiredQuantity} unidades';
    final subtotal = row.price.priceOriginal * _quantity;
    if (subtotal < p.compraMinima)
      return 'Faltan ${formatMoney(p.compraMinima - subtotal)} para la compra mínima';
    if (row.price.hasStoreOffer &&
        p.promotionKind == 'payment' &&
        !p.allowsStacking) {
      return 'No acumulable con el precio de oferta';
    }
    return 'No aplicado: se eligió el beneficio de menor costo sin acumular';
  }

  Widget _benefit(
    Promotion p, {
    required String subtitle,
    List<Widget> extraDetails = const [],
  }) => ExpansionTile(
    key: ValueKey(p.id),
    tilePadding: EdgeInsets.zero,
    childrenPadding: const EdgeInsets.only(bottom: 12),
    title: Text(
      p.titulo.trim().isEmpty && p.beneficio.trim().isNotEmpty
          ? '${p.nombreVisible} · ${p.beneficio}'
          : p.nombreVisible,
      style: const TextStyle(fontWeight: FontWeight.w700),
    ),
    subtitle: Text(subtitle),
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...extraDetails,
            if (p.beneficio.isNotEmpty) Text(p.beneficio),
            if (p.requiredQuantity > 1)
              Text('Unidades requeridas: ${p.requiredQuantity}'),
            if (p.compraMinima > 0)
              Text('Compra mínima: ${formatMoney(p.compraMinima)}'),
            if (p.topeReintegro > 0)
              Text('Tope: ${formatMoney(p.topeReintegro)} · ${p.capFrequency}'),
            Text(
              'Vigencia: ${promotionDate(p.fechaInicio)} al ${promotionDate(p.fechaFin)}',
            ),
            Text(p.condiciones),
            if (p.canal.isNotEmpty) Text('Canal: ${p.canal}'),
            if (p.branchIds.isNotEmpty)
              Text('Sucursales: ${p.branchIds.join(', ')}'),
            Text(
              p.allowsStacking
                  ? 'Acumulación sujeta a condiciones'
                  : 'No acumulable',
            ),
            if (p.capturedAt != null)
              Text('Última verificación: ${promotionDate(p.capturedAt!)}'),
            if (p.fuenteUrl.isNotEmpty)
              SelectableText(
                'Fuente: ${p.fuenteUrl}',
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
      ),
    ],
  );
}
