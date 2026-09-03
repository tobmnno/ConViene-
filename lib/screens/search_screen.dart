import 'dart:async';

import 'package:flutter/material.dart';

import '../models/price_quote.dart';
import '../services/product_search_service.dart';
import '../state/app_scope.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';
import '../widgets/app_card.dart';
import '../widgets/price_block.dart';
import '../widgets/product_art.dart';
import '../widgets/screen_frame.dart';
import '../widgets/store_logo.dart';

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
                icon: const Icon(Icons.chevron_left, color: AppColors.deepBlue),
              ),
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      'Resultados',
                      style: TextStyle(
                        color: AppColors.deepBlue,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                    Text(
                      state.searchQuery,
                      style: const TextStyle(
                        color: AppColors.deepBlue,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Filtros',
                onPressed: () {},
                icon: const Icon(Icons.tune, color: AppColors.deepBlue),
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
                icon: const Icon(Icons.arrow_forward, color: AppColors.blue),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _SortTabs(value: state.searchSort, onChanged: state.setSearchSort),
          const SizedBox(height: 14),
          if (!state.paymentSetupComplete || state.activePaymentMethods.isEmpty)
            const _NoPaymentMethodsHint(),
          if (state.isSearching)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.blue),
              ),
            )
          else
            Expanded(
              child: state.searchResults.isEmpty
                  ? const _EmptyResults()
                  : ListView.separated(
                      itemCount: state.searchResults.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final result = state.searchResults[index];
                        final discount = state.discountForResult(result);
                        final isBest =
                            bestPrice != null &&
                            (discount.precioFinal - bestPrice).abs() < 0.01;
                        return _ResultCard(
                          result: result,
                          isBest: isBest,
                          onAdd: () => unawaited(
                            state.addProductToCart(
                              result.product.id,
                              selectedStoreId: result.supermarket.id,
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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.blue : AppColors.white,
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
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.result,
    required this.isBest,
    required this.onAdd,
  });

  final SearchResult result;
  final bool isBest;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final discount = state.discountForResult(result);
    return AppCard(
      padding: EdgeInsets.zero,
      borderColor: isBest ? const Color(0xFFC7EFD8) : AppColors.line,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ProductArt(product: result.product),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          StoreLogo(supermarket: result.supermarket, size: 28),
                          const SizedBox(width: 6),
                          Text(
                            result.supermarket.name,
                            style: const TextStyle(
                              color: AppColors.deepBlue,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        result.product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.deepBlue,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        result.product.presentation,
                        style: const TextStyle(
                          color: AppColors.deepBlue,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 10),
                      PriceBlock(discount: discount),
                      const SizedBox(height: 4),
                      Text(
                        'Precio por ${result.product.unit}: ${formatMoney(result.price.priceUnitario)}',
                        style: const TextStyle(
                          color: AppColors.textGray,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  children: [
                    IconButton.filled(
                      tooltip: 'Agregar al changuito',
                      onPressed: onAdd,
                      icon: const Icon(Icons.add_shopping_cart),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.deepBlue),
                  ],
                ),
              ],
            ),
          ),
          if (isBest)
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
}

class _NoPaymentMethodsHint extends StatelessWidget {
  const _NoPaymentMethodsHint();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: AppCard(
        color: AppColors.softBlue,
        child: Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.blue),
            SizedBox(width: 10),
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
  const _EmptyResults();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'No encontramos ese producto en los supermercados seleccionados.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textGray),
      ),
    );
  }
}
