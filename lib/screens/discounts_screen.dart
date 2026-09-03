import 'package:flutter/material.dart';

import '../models/discount.dart';
import '../models/payment_method.dart';
import '../models/supermarket.dart';
import '../state/app_scope.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';
import '../widgets/app_card.dart';
import '../widgets/screen_frame.dart';
import '../widgets/store_logo.dart';
import 'payment_methods_screen.dart';

enum DiscountFilter { all, cards, banks, wallets }

class DiscountsScreen extends StatefulWidget {
  const DiscountsScreen({super.key});

  @override
  State<DiscountsScreen> createState() => _DiscountsScreenState();
}

class _DiscountsScreenState extends State<DiscountsScreen> {
  var _filter = DiscountFilter.all;
  Set<String> _selectedStoreIds = const {'coto', 'carrefour', 'lagallega'};

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final activeMethods = state.activePaymentMethods;
    final filteredPromotions =
        state.promotions
            .where(_matchesFilter)
            .where((promotion) => _selectedStoreIds.contains(promotion.storeId))
            .where((promotion) => _isCompatible(promotion, activeMethods))
            .toList()
          ..sort((a, b) {
            return b.porcentajeDescuento.compareTo(a.porcentajeDescuento);
          });

    return ScreenFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Center(
                  child: Text(
                    'Descuentos',
                    style: TextStyle(
                      color: AppColors.deepBlue,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Medios de pago',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => const PaymentMethodsScreen(),
                  ),
                ),
                icon: const Icon(Icons.credit_card, color: AppColors.deepBlue),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _DaySelector(selectedDate: state.selectedDate),
          const SizedBox(height: 22),
          Text(
            longDate(state.selectedDate),
            style: const TextStyle(
              color: AppColors.deepBlue,
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Promos compatibles con los medios de pago que seleccionaste.',
            style: TextStyle(color: AppColors.deepBlue, fontSize: 13),
          ),
          const SizedBox(height: 14),
          _DiscountFilterTabs(
            value: _filter,
            onChanged: (value) => setState(() => _filter = value),
          ),
          const SizedBox(height: 10),
          _StoreFilterBar(
            supermarkets: state.enabledSupermarkets,
            selectedIds: _selectedStoreIds,
            onSelectAll: () => setState(
              () => _selectedStoreIds = {
                for (final store in state.enabledSupermarkets) store.id,
              },
            ),
            onToggle: _toggleStoreFilter,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: filteredPromotions.isEmpty
                ? _NoDiscounts(hasPaymentMethods: activeMethods.isNotEmpty)
                : ListView.separated(
                    itemCount: filteredPromotions.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final promotion = filteredPromotions[index];
                      final supermarket = state.supermarkets.firstWhere(
                        (store) => store.id == promotion.storeId,
                      );
                      return _PromotionCard(
                        promotion: promotion,
                        supermarketName: supermarket.name,
                        compatible: true,
                        storeLogo: StoreLogo(
                          supermarket: supermarket,
                          size: 48,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  bool _matchesFilter(Promotion promotion) {
    return switch (_filter) {
      DiscountFilter.all => true,
      DiscountFilter.cards => promotion.appliesToFilter(PaymentMethodType.card),
      DiscountFilter.banks => promotion.appliesToFilter(PaymentMethodType.bank),
      DiscountFilter.wallets => promotion.appliesToFilter(
        PaymentMethodType.wallet,
      ),
    };
  }

  bool _isCompatible(Promotion promotion, List<PaymentMethod> methods) {
    return methods.any(promotion.isCompatibleWith);
  }

  void _toggleStoreFilter(String storeId) {
    setState(() {
      if (_selectedStoreIds.contains(storeId)) {
        if (_selectedStoreIds.length == 1) {
          return;
        }
        _selectedStoreIds = {..._selectedStoreIds}..remove(storeId);
      } else {
        _selectedStoreIds = {..._selectedStoreIds, storeId};
      }
    });
  }
}

class _DaySelector extends StatelessWidget {
  const _DaySelector({required this.selectedDate});

  final DateTime selectedDate;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final days = List.generate(
      5,
      (index) => selectedDate.subtract(Duration(days: 2 - index)),
    );
    return Row(
      children: [
        IconButton(
          tooltip: 'Dias anteriores',
          onPressed: () => state.setSelectedDate(
            selectedDate.subtract(const Duration(days: 1)),
          ),
          icon: const Icon(Icons.chevron_left, color: AppColors.deepBlue),
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final day in days)
                _DayPill(date: day, selected: _isSameDay(day, selectedDate)),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Dias siguientes',
          onPressed: () =>
              state.setSelectedDate(selectedDate.add(const Duration(days: 1))),
          icon: const Icon(Icons.chevron_right, color: AppColors.deepBlue),
        ),
      ],
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _DayPill extends StatelessWidget {
  const _DayPill({required this.date, required this.selected});

  final DateTime date;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return InkWell(
      onTap: () => state.setSelectedDate(date),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 48,
        height: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.blue : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: selected ? null : Border.all(color: AppColors.line),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              weekdayShort(date.weekday),
              style: TextStyle(
                color: selected ? AppColors.white : AppColors.textGray,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${date.day}',
              style: TextStyle(
                color: selected ? AppColors.white : AppColors.deepBlue,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscountFilterTabs extends StatelessWidget {
  const _DiscountFilterTabs({required this.value, required this.onChanged});

  final DiscountFilter value;
  final ValueChanged<DiscountFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _FilterChip(
          label: 'Todos',
          selected: value == DiscountFilter.all,
          onTap: () => onChanged(DiscountFilter.all),
        ),
        _FilterChip(
          label: 'Tarjetas',
          selected: value == DiscountFilter.cards,
          onTap: () => onChanged(DiscountFilter.cards),
        ),
        _FilterChip(
          label: 'Bancos',
          selected: value == DiscountFilter.banks,
          onTap: () => onChanged(DiscountFilter.banks),
        ),
        _FilterChip(
          label: 'Billeteras',
          selected: value == DiscountFilter.wallets,
          onTap: () => onChanged(DiscountFilter.wallets),
        ),
      ],
    );
  }
}

class _StoreFilterBar extends StatelessWidget {
  const _StoreFilterBar({
    required this.supermarkets,
    required this.selectedIds,
    required this.onSelectAll,
    required this.onToggle,
  });

  final List<Supermarket> supermarkets;
  final Set<String> selectedIds;
  final VoidCallback onSelectAll;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final allSelected =
        supermarkets.isNotEmpty &&
        supermarkets.every((store) => selectedIds.contains(store.id));
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _StoreFilterChip(
            label: 'Todos',
            selected: allSelected,
            onTap: onSelectAll,
          ),
          for (final supermarket in supermarkets)
            _StoreFilterChip(
              label: supermarket.shortName,
              selected: selectedIds.contains(supermarket.id),
              onTap: () => onToggle(supermarket.id),
              logo: StoreLogo(supermarket: supermarket, size: 22),
            ),
        ],
      ),
    );
  }
}

class _StoreFilterChip extends StatelessWidget {
  const _StoreFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.logo,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? logo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: selected ? AppColors.deepBlue : AppColors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppColors.deepBlue : AppColors.line,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (logo != null) ...[logo!, const SizedBox(width: 7)],
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.white : AppColors.deepBlue,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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
      child: Padding(
        padding: const EdgeInsets.only(right: 6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.blue : AppColors.white,
              borderRadius: BorderRadius.circular(18),
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
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PromotionCard extends StatelessWidget {
  const _PromotionCard({
    required this.promotion,
    required this.supermarketName,
    required this.compatible,
    required this.storeLogo,
  });

  final Promotion promotion;
  final String supermarketName;
  final bool compatible;
  final Widget storeLogo;

  @override
  Widget build(BuildContext context) {
    final accent = compatible ? AppColors.green : AppColors.deepBlue;
    final cardColor = compatible ? const Color(0xFFEAF8F0) : AppColors.white;
    final borderColor = compatible ? const Color(0xFFB8EBCB) : AppColors.line;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _showPromotionDetails(context),
      child: AppCard(
        color: cardColor,
        borderColor: borderColor,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            storeLogo,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    promotion.nombreVisible,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.deepBlue,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _MethodBadge(label: supermarketName),
                      _MethodBadge(label: promotion.entidad),
                      _MethodBadge(label: promotion.tipoMedioPago.label),
                      _MethodBadge(
                        label: compatible ? 'Compatible' : 'No esta en perfil',
                        highlighted: compatible,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _benefitText(promotion),
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    _capText(promotion),
                    style: const TextStyle(
                      color: AppColors.deepBlue,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    _daysText(promotion),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.deepBlue,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _benefitBadge(promotion),
              textAlign: TextAlign.right,
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w900,
                fontSize: promotion.esBeneficioDePrecio ? 24 : 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPromotionDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      promotion.nombreVisible,
                      style: const TextStyle(
                        color: AppColors.deepBlue,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _DetailLine('Super', supermarketName),
              _DetailLine('Medio', promotion.tipoMedioPago.label),
              _DetailLine('Entidad', promotion.entidad),
              _DetailLine('Beneficio', _benefitText(promotion)),
              _DetailLine('Tope', _capValue(promotion)),
              _DetailLine('Dias', _daysText(promotion)),
              _DetailLine('Vigencia', _dateRange(promotion)),
              if (promotion.canal.isNotEmpty)
                _DetailLine('Canal', promotion.canal),
              _DetailLine('Categorias', promotion.categorias.join(', ')),
              _DetailLine('Condicion', promotion.condiciones),
              if (promotion.fuenteUrl.isNotEmpty)
                _DetailLine('Fuente', promotion.fuenteUrl),
            ],
          ),
        );
      },
    );
  }

  String _benefitText(Promotion promotion) {
    if (promotion.beneficio.isNotEmpty) {
      return promotion.beneficio;
    }
    return '${formatPercent(promotion.porcentajeDescuento)} de descuento';
  }

  String _benefitBadge(Promotion promotion) {
    if (promotion.beneficio.isNotEmpty) {
      return promotion.beneficio.replaceAll(' OFF', '');
    }
    return formatPercent(promotion.porcentajeDescuento);
  }

  String _capText(Promotion promotion) {
    final cap = _capValue(promotion);
    return promotion.esBeneficioDePrecio
        ? 'Tope de reintegro: $cap'
        : 'Financiacion sin descuento directo';
  }

  String _capValue(Promotion promotion) {
    if (!promotion.esBeneficioDePrecio) {
      return 'No aplica';
    }
    if (promotion.topeReintegro <= 0) {
      return 'Sin tope';
    }
    return formatMoney(promotion.topeReintegro);
  }

  String _daysText(Promotion promotion) {
    if (promotion.textoVigencia.isNotEmpty) {
      return promotion.textoVigencia;
    }
    const dayNames = {
      DateTime.monday: 'lunes',
      DateTime.tuesday: 'martes',
      DateTime.wednesday: 'miercoles',
      DateTime.thursday: 'jueves',
      DateTime.friday: 'viernes',
      DateTime.saturday: 'sabados',
      DateTime.sunday: 'domingos',
    };
    if (promotion.diasSemana.length == 7) {
      return 'Todos los dias';
    }
    return [
      for (final weekday in promotion.diasSemana) dayNames[weekday] ?? '',
    ].where((day) => day.isNotEmpty).join(', ');
  }

  String _dateRange(Promotion promotion) {
    return '${_shortDate(promotion.fechaInicio)} al ${_shortDate(promotion.fechaFin)}';
  }

  String _shortDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}

class _MethodBadge extends StatelessWidget {
  const _MethodBadge({required this.label, this.highlighted = false});

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xFFD9F7E6) : AppColors.softBlue,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: highlighted ? AppColors.green : AppColors.blue,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textGray,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.deepBlue,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoDiscounts extends StatelessWidget {
  const _NoDiscounts({required this.hasPaymentMethods});

  final bool hasPaymentMethods;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        hasPaymentMethods
            ? 'No hay promociones para tus medios seleccionados.'
            : 'Selecciona tus tarjetas, bancos o billeteras para ver promos.',
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.textGray),
      ),
    );
  }
}
