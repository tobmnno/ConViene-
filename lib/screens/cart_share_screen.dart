import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../models/cart_item.dart';
import '../models/product.dart';
import '../services/cart_image_download.dart';
import '../state/app_scope.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';

class CartShareScreen extends StatefulWidget {
  const CartShareScreen({super.key});

  @override
  State<CartShareScreen> createState() => _CartShareScreenState();
}

class _CartShareScreenState extends State<CartShareScreen> {
  final _imageKey = GlobalKey();
  var _exporting = false;

  Future<void> _exportImage() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          _imageKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('No se pudo preparar la imagen.');
      final image = await boundary.toImage(pixelRatio: 2.5);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) throw StateError('No se pudo generar la imagen.');
      final bytes = data.buffer.asUint8List();
      if (kIsWeb) {
        downloadCartImage(bytes);
      } else {
        await _shareNative(bytes);
      }
      if (mounted) _notify('Imagen lista para compartir', success: true);
    } catch (_) {
      if (mounted)
        _notify(
          'No pudimos generar la imagen. Proba de nuevo.',
          success: false,
        );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _shareNative(Uint8List bytes) async {
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            bytes,
            mimeType: 'image/png',
            name: 'conviene-changuito.png',
          ),
        ],
        fileNameOverrides: const ['conviene-changuito.png'],
        subject: 'Mi changuito en Conviene',
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  void _notify(String message, {required bool success}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          width: MediaQuery.sizeOf(context).width < 420
              ? MediaQuery.sizeOf(context).width - 32
              : 400,
          backgroundColor: success ? AppColors.navy : const Color(0xFF9B2C2C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          duration: const Duration(seconds: 3),
          content: Row(
            children: [
              Icon(
                success ? Icons.check_circle_outline : Icons.error_outline,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final selected = state.selectedStoresPlan;
    final pricedById = {
      for (final line in selected?.items ?? <PricedCartItem>[])
        line.cartProductId ?? line.product.id: line,
    };
    final productsById = {
      for (final product in state.products) product.id: product,
    };
    final storesById = {
      for (final store in state.supermarkets) store.id: store.name,
    };
    final allPriced =
        state.cartItems.isNotEmpty &&
        state.cartItems.every((item) => pricedById.containsKey(item.productId));
    final width = (MediaQuery.sizeOf(context).width - 32).clamp(280.0, 420.0);

    return Scaffold(
      appBar: AppBar(title: const Text('Compartir changuito')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Center(
                    child: RepaintBoundary(
                      key: _imageKey,
                      child: Container(
                        width: width,
                        color: AppColors.surface,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(
                                22,
                                18,
                                22,
                                16,
                              ),
                              color: AppColors.navy,
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Image.asset(
                                      'assets/brand/conviene_logo_source.png',
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Mi changuito',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 21,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        Text(
                                          'Conviene',
                                          style: TextStyle(
                                            color: Color(0xFFAFD0FF),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                22,
                                18,
                                22,
                                20,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${state.cartItems.length} ${state.cartItems.length == 1 ? 'producto' : 'productos'}',
                                    style: TextStyle(
                                      color: AppColors.textGray,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  for (final item in state.cartItems) ...[
                                    _ShareLine(
                                      item: item,
                                      product:
                                          productsById[item.productId] ??
                                          pricedById[item.productId]?.product,
                                      priced: pricedById[item.productId],
                                      selectedStoreName:
                                          storesById[item.selectedStoreId],
                                    ),
                                    const SizedBox(height: 10),
                                  ],
                                  Divider(height: 24, color: AppColors.line),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          allPriced
                                              ? 'Total verificado'
                                              : 'Subtotal verificado',
                                          style: TextStyle(
                                            color: AppColors.deepBlue,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        selected == null ||
                                                selected.items.isEmpty
                                            ? 'Sin precios'
                                            : formatMoney(
                                                selected.totalFinal,
                                                compactCents: false,
                                              ),
                                        style: const TextStyle(
                                          color: AppColors.green,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (!allPriced)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        'Faltan precios por verificar. No es un total comparable.',
                                        style: TextStyle(
                                          color: AppColors.textGray,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 18),
                                  Text(
                                    'Precios sujetos a sucursal, stock y momento de consulta.',
                                    style: TextStyle(
                                      color: AppColors.textGray,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton.icon(
                onPressed: _exporting || state.cartItems.isEmpty
                    ? null
                    : _exportImage,
                icon: _exporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        kIsWeb
                            ? Icons.download_outlined
                            : Icons.ios_share_outlined,
                      ),
                label: Text(
                  _exporting
                      ? 'Preparando imagen...'
                      : kIsWeb
                      ? 'Descargar imagen'
                      : 'Compartir imagen',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareLine extends StatelessWidget {
  const _ShareLine({
    required this.item,
    required this.product,
    required this.priced,
    required this.selectedStoreName,
  });

  final CartItem item;
  final Product? product;
  final PricedCartItem? priced;
  final String? selectedStoreName;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.softBlue,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.shopping_bag_outlined,
            color: AppColors.blue,
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product?.name ?? 'Producto',
                maxLines: 3,
                style: TextStyle(
                  color: AppColors.deepBlue,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                priced == null
                    ? '${selectedStoreName ?? 'Super no seleccionado'} · x${item.quantity} · precio no verificado'
                    : '${priced!.supermarket.name} · x${item.quantity}',
                style: TextStyle(color: AppColors.textGray, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          priced == null ? '—' : formatMoney(priced!.discount.precioFinal),
          style: TextStyle(
            color: AppColors.deepBlue,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
