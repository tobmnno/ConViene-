import '../models/discount.dart';
import '../models/price_quote.dart';

Uri? officialProductUri(String storeId, String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      (uri.hasPort && uri.port != 443))
    return null;
  final hosts = switch (storeId) {
    'coto' => {
      'www.cotodigital.com.ar',
      'cotodigital.com.ar',
      'www.coto.com.ar',
      'coto.com.ar',
    },
    'carrefour' => {'www.carrefour.com.ar', 'carrefour.com.ar'},
    'lagallega' => {'www.lagallega.com.ar', 'lagallega.com.ar'},
    _ => <String>{},
  };
  if (!hosts.contains(uri.host.toLowerCase())) return null;
  final path = uri.path.toLowerCase();
  final direct = switch (storeId) {
    'coto' =>
      (path.startsWith('/productos/') && path.length > '/productos/'.length) ||
          RegExp(r'^/productos_/r-\d+-\d+-\d+$').hasMatch(path) ||
          (path.startsWith('/sitios/cdigi/producto/') &&
              path.contains('/_/a-')),
    'carrefour' => path.endsWith('/p'),
    'lagallega' =>
      path == '/productosdet.asp' &&
          uri.queryParameters.entries.any(
            (entry) =>
                entry.key.toLowerCase() == 'pr' &&
                RegExp(r'^\d+$').hasMatch(entry.value),
          ),
    _ => false,
  };
  return direct ? uri : null;
}

bool isDeferredRefund(Promotion? promotion) =>
    promotion != null &&
    promotion.promotionKind == 'payment' &&
    '${promotion.beneficio} ${promotion.condiciones}'.toLowerCase().contains(
      'reintegro',
    );

String promotionDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

String priceSourceLine(ProductPrice price) {
  final origin = switch (price.pricingScope) {
    'selected_store' => 'Catálogo de sucursal consultada',
    'online_sales_channel' => 'Catálogo online consultado',
    'catalog_no_branch' => 'Catálogo sin sucursal confirmada',
    'community' => 'Precio aportado por usuario',
    _ => 'Catálogo consultado',
  };
  return '$origin · ${promotionDate(price.fechaActualizacion)}';
}
