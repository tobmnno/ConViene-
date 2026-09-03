import 'payment_method.dart';

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
    this.tiposMedioPagoCompatibles = const {},
    this.cualquierEntidad = false,
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
  final Set<PaymentMethodType> tiposMedioPagoCompatibles;
  final bool cualquierEntidad;

  String get nombreVisible => titulo.isEmpty ? entidad : titulo;

  bool get esBeneficioDePrecio => porcentajeDescuento > 0;

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
  });

  final double precioOriginal;
  final bool descuentoAplicado;
  final double porcentaje;
  final double importeDescuento;
  final double precioFinal;
  final Promotion? promocionUsada;
  final PaymentMethod? medioPago;
  final double rawDiscount;

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
    );
  }
}
