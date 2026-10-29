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
    int quantity = 1,
    double? purchaseTotal,
    bool hasStoreOffer = false,
    String? branchId,
    Map<String, double> usedRefundCaps = const {},
  }) {
    final activeMethods = mediosPagoUsuario.where((method) => method.active);

    final compatiblePromos = promociones.where((promotion) {
      final hasPaymentMethod = promotion.isCompatibleWithAny(activeMethods);
      return promotion.storeId == supermercado &&
          promotion.canCalculate &&
          promotion.appliesOn(fecha) &&
          promotion.appliesToCategory(product.category) &&
          promotion.appliesToProduct(product) &&
          promotion.appliesToBranch(branchId) &&
          (purchaseTotal ?? precioOriginal) >= promotion.compraMinima &&
          (promotion.promotionKind == 'store_product' ||
              !hasStoreOffer || promotion.allowsStacking) &&
          hasPaymentMethod;
    });

    Promotion? bestPromotion;
    PaymentMethod? bestMethod;
    var bestRawDiscount = 0.0;
    var bestDiscount = 0.0;

    for (final promotion in compatiblePromos) {
      final capKey = promotion.capUsageKey(fecha);
      final used = capKey == null ? 0.0 : (usedRefundCaps[capKey] ?? 0.0);
      final remainingCap = (promotion.topeReintegro - used).clamp(
        0.0,
        double.infinity,
      );
      final rawDiscount = promotion.promotionKind == 'store_product'
          ? _quantityDiscount(promotion, precioOriginal, quantity)
          : precioOriginal * promotion.porcentajeDescuento / 100;
      final cappedDiscount = promotion.topeReintegro <= 0
          ? rawDiscount.clamp(0, precioOriginal).toDouble()
          : rawDiscount
                .clamp(0, remainingCap)
                .clamp(0, precioOriginal)
                .toDouble();
      if (cappedDiscount > bestDiscount) {
        bestPromotion = promotion;
        bestRawDiscount = rawDiscount;
        bestDiscount = cappedDiscount;
        bestMethod = promotion.promotionKind == 'store_product'
            ? null
            : activeMethods.firstWhere(promotion.isCompatibleWith);
      }
    }

    if (bestPromotion == null) {
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
      estimated:
          bestPromotion.calculationStatus == 'estimate' ||
          (bestPromotion.capUsageKey(fecha) != null &&
              !usedRefundCaps.containsKey(bestPromotion.capUsageKey(fecha))),
    );
  }

  double _quantityDiscount(Promotion promotion, double total, int quantity) {
    if (quantity < 1 || total <= 0 || promotion.productEans.isEmpty) return 0;
    final unitPrice = total / quantity;
    switch (promotion.mechanic) {
      case 'buy_n_pay_m':
        final required = promotion.requiredQuantity;
        final charged = promotion.chargedQuantity;
        if (required < 2 || charged < 0 || charged >= required) return 0;
        return (quantity ~/ required) * (required - charged) * unitPrice;
      case 'second_unit_discount':
        if (promotion.secondUnitDiscount <= 0 ||
            promotion.secondUnitDiscount > 100)
          return 0;
        return (quantity ~/ 2) * unitPrice * promotion.secondUnitDiscount / 100;
      case 'fixed_bundle_price':
        final required = promotion.requiredQuantity;
        if (required < 2 || promotion.bundlePrice <= 0) return 0;
        return (quantity ~/ required) *
            (required * unitPrice - promotion.bundlePrice).clamp(0, total);
      case 'percentage':
        return total * promotion.porcentajeDescuento / 100;
      default:
        return 0;
    }
  }
}
