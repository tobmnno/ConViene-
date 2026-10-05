import '../models/discount.dart';
import '../models/payment_method.dart';
import '../models/product.dart';

class DiscountEngine {
  const DiscountEngine();

  DiscountQuote calcularPrecioFinal({
    required Product product,
    required String supermercado,
    required double precioOriginal,
    required DateTime fecha,
    required List<PaymentMethod> mediosPagoUsuario,
    required List<Promotion> promociones,
  }) {
    final activeMethods = mediosPagoUsuario.where((method) => method.active);
    if (activeMethods.isEmpty) {
      return DiscountQuote.noDiscount(precioOriginal);
    }

    final compatiblePromos = promociones.where((promotion) {
      final hasPaymentMethod = promotion.isCompatibleWithAny(activeMethods);
      return promotion.storeId == supermercado &&
          promotion.appliesOn(fecha) &&
          promotion.appliesToCategory(product.category) &&
          precioOriginal >= promotion.compraMinima &&
          hasPaymentMethod;
    });

    Promotion? bestPromotion;
    PaymentMethod? bestMethod;
    var bestRawDiscount = 0.0;
    var bestDiscount = 0.0;

    for (final promotion in compatiblePromos) {
      final rawDiscount = precioOriginal * promotion.porcentajeDescuento / 100;
      final cappedDiscount = promotion.topeReintegro <= 0
          ? rawDiscount
          : rawDiscount.clamp(0, promotion.topeReintegro).toDouble();
      if (cappedDiscount > bestDiscount) {
        bestPromotion = promotion;
        bestRawDiscount = rawDiscount;
        bestDiscount = cappedDiscount;
        bestMethod = activeMethods.firstWhere(promotion.isCompatibleWith);
      }
    }

    if (bestPromotion == null || bestMethod == null) {
      return DiscountQuote.noDiscount(precioOriginal);
    }

    final discount = bestDiscount;
    return DiscountQuote(
      precioOriginal: precioOriginal,
      descuentoAplicado: true,
      porcentaje: bestPromotion.porcentajeDescuento,
      importeDescuento: discount,
      precioFinal: precioOriginal - discount,
      promocionUsada: bestPromotion,
      medioPago: bestMethod,
      rawDiscount: bestRawDiscount,
    );
  }
}
