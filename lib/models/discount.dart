import 'payment_method.dart';
import 'product.dart';

class Promotion {
  const Promotion({
    required this.id,
    required this.storeId,
    required this.tipoMedioPago,
    required this.entidad,
    required this.porcentajeDescuento,
    required this.topeReintegro,
    required this.diasSemana,
    required this.fechaInicio,
    required this.fechaFin,
    required this.condiciones,
    required this.categorias,
    this.titulo = '',
    this.beneficio = '',
    this.canal = '',
    this.textoVigencia = '',
    this.fuenteUrl = '',
    this.entidadesCompatibles = const {},
    this.entidadesRequeridas = const [],
    this.tiposMedioPagoCompatibles = const {},
    this.cualquierEntidad = false,
    this.compraMinima = 0,
    this.promotionKind = 'payment',
    this.mechanic = 'percentage',
    this.productEans = const {},
    this.branchIds = const {},
    this.requiredQuantity = 1,
    this.chargedQuantity = 1,
    this.secondUnitDiscount = 0,
    this.bundlePrice = 0,
    this.allowsStacking = false,
    this.capFrequency = '',
    this.sourceType = '',
    this.verificationStatus = 'source_reported',
    this.calculationStatus = 'exact',
    this.capturedAt,
  });

  final String id;
  final String storeId;
  final PaymentMethodType tipoMedioPago;
  final String entidad;
  final double porcentajeDescuento;
  final double topeReintegro;
  final Set<int> diasSemana;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final String condiciones;
  final List<String> categorias;
  final String titulo;
  final String beneficio;
  final String canal;
  final String textoVigencia;
  final String fuenteUrl;
  final Set<String> entidadesCompatibles;
  final List<Set<String>> entidadesRequeridas;
  final Set<PaymentMethodType> tiposMedioPagoCompatibles;
  final bool cualquierEntidad;
  final double compraMinima;
  final String promotionKind;
  final String mechanic;
  final Set<String> productEans;
  final Set<String> branchIds;
  final int requiredQuantity;
  final int chargedQuantity;
  final double secondUnitDiscount;
  final double bundlePrice;
  final bool allowsStacking;
  final String capFrequency;
  final String sourceType;
  final String verificationStatus;
  final String calculationStatus;
  final DateTime? capturedAt;

  String get nombreVisible => titulo.isEmpty ? entidad : titulo;

  bool get esBeneficioDePrecio =>
      porcentajeDescuento > 0 ||
      (promotionKind == 'store_product' && mechanic != 'percentage');

  bool get canCalculate =>
      verificationStatus != 'unverified' &&
      (promotionKind != 'store_product' ||
          sourceType != 'official_api' ||
          (capturedAt != null &&
              DateTime.now().difference(capturedAt!).inMinutes < 30)) &&
      (calculationStatus == 'exact' || calculationStatus == 'estimate');

  String? capUsageKey(DateTime date) {
    if (promotionKind != 'payment' || topeReintegro <= 0) return null;
    final day = DateTime(date.year, date.month, date.day);
    final period = switch (capFrequency) {
      'weekly' => day.subtract(Duration(days: day.weekday - 1)),
      'monthly' => DateTime(day.year, day.month),
      'account' => null,
      _ => null,
    };
    if (capFrequency == 'account') {
      return '$id|account|${fechaInicio.toIso8601String()}|${fechaFin.toIso8601String()}';
    }
    if (period == null) return null;
    return '$id|${period.year}-${period.month.toString().padLeft(2, '0')}-${period.day.toString().padLeft(2, '0')}';
  }

  bool appliesToProduct(Product product) =>
      promotionKind != 'store_product' ||
      (product.ean.isNotEmpty && productEans.contains(product.ean));

  bool appliesToBranch(String? branchId) =>
      branchIds.isEmpty || (branchId != null && branchIds.contains(branchId));

  bool appliesOn(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final start = DateTime(
      fechaInicio.year,
      fechaInicio.month,
      fechaInicio.day,
    );
    final end = DateTime(fechaFin.year, fechaFin.month, fechaFin.day);
    return !normalized.isBefore(start) &&
        !normalized.isAfter(end) &&
        diasSemana.contains(date.weekday);
  }

  bool appliesToCategory(String category) {
    return categorias.contains('todos') || categorias.contains(category);
  }

  bool appliesToFilter(PaymentMethodType type) {
    if (promotionKind == 'store_product') return false;
    final compatibleTypes = tiposMedioPagoCompatibles.isEmpty
        ? {tipoMedioPago}
        : tiposMedioPagoCompatibles;
    return compatibleTypes.contains(type);
  }

  bool isCompatibleWith(PaymentMethod method) {
    if (!method.active) {
      return false;
    }
    final compatibleTypes = tiposMedioPagoCompatibles.isEmpty
        ? {tipoMedioPago}
        : tiposMedioPagoCompatibles;
    final typeMatches = compatibleTypes.contains(method.type);
    final compatibleEntities = entidadesCompatibles.isEmpty
        ? {entidad}
        : entidadesCompatibles;
    final methodEntity = _normalizeEntity(method.entity);
    final entityMatches =
        cualquierEntidad ||
        compatibleEntities.any(
          (entity) => _normalizeEntity(entity) == methodEntity,
        );
    return typeMatches && entityMatches;
  }

  bool isCompatibleWithAny(Iterable<PaymentMethod> methods) {
    if (promotionKind == 'store_product') return true;
    final activeMethods = methods.where((method) => method.active).toList();
    if (entidadesRequeridas.isEmpty) {
      return activeMethods.any(isCompatibleWith);
    }
    return entidadesRequeridas.every(
      (group) => activeMethods.any(
        (method) =>
            isCompatibleWith(method) &&
            group.any(
              (entity) =>
                  _normalizeEntity(entity) == _normalizeEntity(method.entity),
            ),
      ),
    );
  }

  String _normalizeEntity(String value) {
    return value
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n')
        .trim();
  }
}

class DiscountQuote {
  const DiscountQuote({
    required this.precioOriginal,
    required this.descuentoAplicado,
    required this.porcentaje,
    required this.importeDescuento,
    required this.precioFinal,
    required this.promocionUsada,
    required this.medioPago,
    required this.rawDiscount,
    this.estimated = false,
  });

  final double precioOriginal;
  final bool descuentoAplicado;
  final double porcentaje;
  final double importeDescuento;
  final double precioFinal;
  final Promotion? promocionUsada;
  final PaymentMethod? medioPago;
  final double rawDiscount;
  final bool estimated;

  DiscountQuote copyWith({double? importeDescuento, double? precioFinal}) {
    return DiscountQuote(
      precioOriginal: precioOriginal,
      descuentoAplicado: descuentoAplicado,
      porcentaje: porcentaje,
      importeDescuento: importeDescuento ?? this.importeDescuento,
      precioFinal: precioFinal ?? this.precioFinal,
      promocionUsada: promocionUsada,
      medioPago: medioPago,
      rawDiscount: rawDiscount,
      estimated: estimated,
    );
  }

  factory DiscountQuote.noDiscount(double precioOriginal) {
    return DiscountQuote(
      precioOriginal: precioOriginal,
      descuentoAplicado: false,
      porcentaje: 0,
      importeDescuento: 0,
      precioFinal: precioOriginal,
      promocionUsada: null,
      medioPago: null,
      rawDiscount: 0,
      estimated: false,
    );
  }
}
