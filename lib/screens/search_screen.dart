import 'dart:async';

import 'package:flutter/material.dart';

import '../models/price_quote.dart';
import '../services/product_search_service.dart';
import '../services/product_offer_details.dart';
import '../state/app_state.dart';
import '../state/app_scope.dart';
import '../theme/app_theme.dart';
import '../utils/barcode.dart';
import '../utils/money.dart';
import '../widgets/app_card.dart';
import '../widgets/price_block.dart';
import '../widgets/product_art.dart';
import '../widgets/screen_frame.dart';
import '../widgets/store_logo.dart';
import '../widgets/product_comparison_trigger.dart';
import '../widgets/product_skeleton_card.dart';
import 'product_detail_screen.dart';
import 'favorites_screen.dart';
import 'contribution_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
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
    final skeletonCount = state.isSearching
        ? state.searchPendingStoreIds.isNotEmpty
              ? state.searchPendingStoreIds.length.clamp(1, 3)
              : state.searchResults.isEmpty
              ? 1
              : 0
        : 0;
    final bestPrice = state.searchResults.isEmpty
        ? null
        : state.searchResults
              .map((result) => state.discountForResult(result).precioFinal)
              .reduce((a, b) => a < b ? a : b);

    return ScreenFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Volver',
                onPressed: widget.onBack,
                icon: Icon(Icons.chevron_left, color: AppColors.deepBlue),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Resultados',
                      style: TextStyle(
                        color: AppColors.deepBlue,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                    Text(
                      state.searchQuery,
                      style: TextStyle(color: AppColors.deepBlue, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Favoritos',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => const FavoritesScreen(),
                  ),
                ),
                icon: Icon(Icons.favorite_border, color: AppColors.deepBlue),
              ),
              IconButton(
                tooltip: 'Filtros',
                onPressed: () => _showStoreFilters(state),
                icon: Icon(Icons.tune, color: AppColors.deepBlue),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
                icon: Icon(Icons.arrow_forward, color: AppColors.accentBlue),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _SortTabs(value: state.searchSort, onChanged: state.setSearchSort),
          const SizedBox(height: 14),
          if (state.lastError != null) ...[
            _SearchError(
              message: state.lastError!,
              onRetry: () => unawaited(state.retrySearch()),
            ),
            const SizedBox(height: 12),
          ],
          if (state.searchWarning != null) ...[
            _SearchWarning(message: state.searchWarning!),
            const SizedBox(height: 12),
          ],
          if (state.searchNotice != null) ...[
            _SearchNotice(message: state.searchNotice!),
            const SizedBox(height: 12),
          ],
          if (!state.paymentSetupComplete || state.activePaymentMethods.isEmpty)
            const _NoPaymentMethodsHint(),
          Expanded(
            child: state.lastError != null && state.searchResults.isEmpty
                ? const SizedBox.shrink()
                : state.searchResults.isEmpty && !state.isSearching
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _EmptyResults(
                        partial: state.searchWarning != null,
                        barcode: normalizedBarcode(state.searchQuery) != null,
                        identified: state.searchNotice != null,
                      ),
                      if (state.canContribute) ...[
                        const SizedBox(height: 20),
                        _contributionButton(state),
                      ],
                    ],
                  )
                : ListView.separated(
                    itemCount:
                        state.searchResults.length +
                        skeletonCount +
                        (state.canContribute && !state.isSearching ? 1 : 0),
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      if (index >= state.searchResults.length &&
                          index < state.searchResults.length + skeletonCount) {
                        return const ProductSkeletonCard();
                      }
                      if (index >= state.searchResults.length + skeletonCount) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 20),
                          child: _contributionButton(state),
                        );
                      }
                      final result = state.searchResults[index];
                      final discount = state.discountForResult(result);
                      final isBest =
                          bestPrice != null &&
                          (discount.precioFinal - bestPrice).abs() < 0.01;
                      return ProductComparisonTrigger(
                        product: result.product,
                        onDetails: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => AppScope(
                              notifier: state,
                              child: ProductDetailScreen(
                                product: result.product,
                              ),
                            ),
                          ),
                        ),
                        child: _ResultCard(
                          result: result,
                          isBest: isBest,
                          isFavorite: state.isFavorite(result.product.id),
                          canEdit:
                              result.contributorId == state.currentUserId &&
                              result.isCommunityPrice,
                          onEdit: () =>
                              _openContribution(state, existing: result),
                          onToggleFavorite: () =>
                              state.toggleFavorite(result.product),
                          onAdd: () => _addProductToCart(
                            state,
                            result.product.id,
                            result.product.name,
                            result.supermarket.id,
                          ),
                        ),
                      );
                    },
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
  }

  Widget _contributionButton(AppState state) => OutlinedButton.icon(
    onPressed: () => _openContribution(state),
    icon: const Icon(Icons.add_circle_outline),
    label: const Text('Ayuda a agregar productos'),
  );

  Future<void> _openContribution(
    AppState state, {
    SearchResult? existing,
  }) async {
    final presentStores = state.searchResults
        .map((result) => result.supermarket.id)
        .toSet();
    final missingStores = state.selectedStoreIds.difference(presentStores);
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AppScope(
          notifier: state,
          child: ContributionScreen(
            stores: state.enabledSupermarkets,
            initialQuery: state.searchQuery,
            initialStoreId: missingStores.length == 1
                ? missingStores.first
                : null,
            existing: existing,
          ),
        ),
      ),
    );
  }

  Future<void> _showStoreFilters(AppState state) async {
    final selectedStores = Set<String>.of(state.selectedStoreIds);
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Supermercados'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final store in state.enabledSupermarkets)
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    setDialogState(() {
                      _toggleStoreSelection(selectedStores, store.id);
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(child: Text(store.name)),
                        Checkbox(
                          value: selectedStores.contains(store.id),
                          onChanged: (_) => setDialogState(
                            () =>
                                _toggleStoreSelection(selectedStores, store.id),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: selectedStores.isEmpty
                  ? null
                  : () => Navigator.of(dialogContext).pop(selectedStores),
              child: const Text('Aplicar'),
            ),
          ],
        ),
      ),
    );
    if (result != null) await state.setSelectedStores(result);
  }

  void _toggleStoreSelection(Set<String> selectedStores, String storeId) {
    if (!selectedStores.add(storeId)) selectedStores.remove(storeId);
  }

  Future<void> _addProductToCart(
    AppState state,
    String productId,
    String productName,
    String storeId,
  ) async {
    await state.addProductToCart(productId, selectedStoreId: storeId);
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final snackBarWidth = MediaQuery.sizeOf(context).width < 420
        ? MediaQuery.sizeOf(context).width - 32
        : 420.0;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          width: snackBarWidth,
          backgroundColor: AppColors.blue,
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          duration: const Duration(seconds: 3),
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline, color: AppColors.white),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  '$productName agregado al changuito',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      );
  }
}

class _SearchError extends StatelessWidget {
  const _SearchError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorSurface,
        border: Border.all(color: AppColors.warningBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppColors.errorText),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: AppColors.deepBlue, fontSize: 12),
            ),
          ),
          IconButton(
            tooltip: 'Reintentar',
            onPressed: onRetry,
            icon: Icon(Icons.refresh, color: AppColors.deepBlue),
          ),
        ],
      ),
    );
  }
}

class _SearchWarning extends StatelessWidget {
  const _SearchWarning({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warningSurface,
        border: Border.all(color: AppColors.warningBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.warningText),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: AppColors.deepBlue, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchNotice extends StatelessWidget {
  const _SearchNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.softBlue,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        const Icon(Icons.inventory_2_outlined, color: AppColors.blue),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: TextStyle(color: AppColors.deepBlue, fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

class _SortTabs extends StatelessWidget {
  const _SortTabs({required this.value, required this.onChanged});

  final SearchSort value;
  final ValueChanged<SearchSort> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _SortChip(
          label: 'Mejor precio',
          selected: value == SearchSort.bestPrice,
          onTap: () => onChanged(SearchSort.bestPrice),
        ),
        const SizedBox(width: 8),
        _SortChip(
          label: 'Mas barato por L',
          selected: value == SearchSort.unitPrice,
          onTap: () => onChanged(SearchSort.unitPrice),
        ),
        const SizedBox(width: 8),
        _SortChip(
          label: 'A-Z',
          selected: value == SearchSort.alphabetical,
          onTap: () => onChanged(SearchSort.alphabetical),
        ),
      ],
    );
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.blue : AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? AppColors.blue : AppColors.line,
              ),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? AppColors.white : AppColors.deepBlue,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatefulWidget {
  const _ResultCard({
    required this.result,
    required this.isBest,
    required this.isFavorite,
    required this.canEdit,
    required this.onEdit,
    required this.onToggleFavorite,
    required this.onAdd,
  });

  final SearchResult result;
  final bool isBest;
  final bool isFavorite;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onToggleFavorite;
  final VoidCallback onAdd;

  @override
  State<_ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends State<_ResultCard> {
  bool _isAdded = false;

  void _handleAdd() {
    if (_isAdded) return;
    setState(() => _isAdded = true);
    widget.onAdd();
    unawaited(_restoreAddButton());
  }

  Future<void> _restoreAddButton() async {
    await Future<void>.delayed(const Duration(seconds: 3));
    if (mounted) setState(() => _isAdded = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final discount = state.discountForResult(widget.result);
    return AppCard(
      padding: EdgeInsets.zero,
      borderColor: widget.isBest ? AppColors.successBorder : AppColors.line,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ProductArt(product: widget.result.product),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          StoreLogo(
                            supermarket: widget.result.supermarket,
                            size: 28,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              widget.result.supermarket.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.deepBlue,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.result.product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.deepBlue,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      if (!widget.result.isExactMatch) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.warningSurface,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            widget.result.matchType == 'alternative'
                                ? 'Alternativa'
                                : widget.result.matchType == 'review'
                                ? 'Revisar coincidencia'
                                : widget.result.matchType == 'name_match'
                                ? 'Coincidencia por nombre'
                                : 'Producto similar',
                            style: TextStyle(
                              color: AppColors.warningText,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 3),
                      Text(
                        widget.result.product.presentation,
                        style: TextStyle(
                          color: AppColors.deepBlue,
                          fontSize: 13,
                        ),
                      ),
                      if (widget.result.isCommunityPrice) ...[
                        const SizedBox(height: 5),
                        Text(
                          'Aporte de la comunidad',
                          style: TextStyle(
                            color: AppColors.warningText,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      PriceBlock(discount: discount),
                      if (widget.result.isCommunityPrice) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Agregado o editado por ${widget.result.contributorName ?? 'usuario'}'
                          ' · ${_dateLabel(widget.result.contributedAt)}',
                          style: TextStyle(
                            color: AppColors.textGray,
                            fontSize: 10,
                          ),
                        ),
                        if (widget.canEdit)
                          TextButton.icon(
                            onPressed: widget.onEdit,
                            icon: const Icon(Icons.edit_outlined, size: 15),
                            label: const Text('Editar mi aporte'),
                          ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        'Precio por ${widget.result.product.unit}: ${formatMoney(widget.result.price.priceUnitario)}',
                        style: TextStyle(
                          color: AppColors.textGray,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _availabilityLabel(widget.result.price),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: widget.result.price.stock
                              ? AppColors.textGray
                              : AppColors.errorText,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (!widget.result.isCommunityPrice)
                        Text(
                          priceSourceLine(widget.result.price),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textGray,
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  children: [
                    IconButton(
                      tooltip: widget.isFavorite
                          ? 'Quitar de favoritos'
                          : 'Guardar en favoritos',
                      onPressed: widget.onToggleFavorite,
                      icon: Icon(
                        widget.isFavorite
                            ? Icons.favorite
                            : Icons.favorite_border,
                      ),
                      color: AppColors.accentBlue,
                    ),
                    IconButton.filled(
                      tooltip: 'Agregar al changuito',
                      onPressed: _isAdded ? null : _handleAdd,
                      style: IconButton.styleFrom(
                        backgroundColor: _isAdded
                            ? AppColors.green
                            : AppColors.blue,
                        foregroundColor: AppColors.white,
                      ),
                      icon: AnimatedSwitcher(
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 160),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: child,
                          );
                        },
                        child: Icon(
                          _isAdded
                              ? Icons.check_rounded
                              : Icons.add_shopping_cart,
                          key: ValueKey(_isAdded),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (widget.isBest)
            Positioned(
              top: 0,
              left: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.green,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomRight: Radius.circular(8),
                  ),
                ),
                child: const Text(
                  'MEJOR PRECIO',
                  style: TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _availabilityLabel(ProductPrice price) {
    if (price.pricingScope == 'community') {
      return price.stock
          ? 'Disponibilidad informada por un usuario'
          : 'Sin stock informado por un usuario';
    }
    if (!price.stock) {
      return 'Sin stock informado por el supermercado';
    }
    if (price.pricingScope == 'online_sales_channel') {
      return 'Precio online; stock sujeto a disponibilidad';
    }
    return 'Stock sujeto a disponibilidad del supermercado';
  }

  String _dateLabel(DateTime? date) {
    if (date == null) return '';
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }
}

class _NoPaymentMethodsHint extends StatelessWidget {
  const _NoPaymentMethodsHint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        color: AppColors.softBlue,
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: AppColors.blue),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Selecciona tus medios de pago en Descuentos para ver precios finales con promociones.',
                style: TextStyle(color: AppColors.deepBlue, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({
    this.partial = false,
    this.barcode = false,
    this.identified = false,
  });

  final bool partial;
  final bool barcode;
  final bool identified;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        identified
            ? 'No hay ofertas disponibles para comprar en este momento.'
            : partial
            ? 'No encontramos resultados en los supermercados que respondieron.'
            : barcode
            ? 'Codigo valido, pero sin precio publicado en los supermercados seleccionados.'
            : 'No encontramos ese producto en los supermercados seleccionados.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textGray),
      ),
    );
  }
}
