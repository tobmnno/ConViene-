import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../theme/app_theme.dart';
import '../utils/barcode.dart';
import '../widgets/screen_frame.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final _controller = MobileScannerController(
    formats: [
      BarcodeFormat.ean8,
      BarcodeFormat.ean13,
      BarcodeFormat.upcA,
      BarcodeFormat.itf14,
    ],
  );
  final _manual = TextEditingController();
  String? _error;
  String? _cameraMessage;
  bool _finished = false;

  @override
  void dispose() {
    _controller.dispose();
    _manual.dispose();
    super.dispose();
  }

  void _submit(String? raw) {
    if (_finished) return;
    final code = normalizedBarcode(raw);
    if (code == null) {
      setState(
        () => _error = 'Ingresa un EAN/UPC valido (8, 12, 13 o 14 digitos).',
      );
      return;
    }
    _finished = true;
    Navigator.of(context).pop(code);
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
    } catch (_) {
      if (mounted) setState(() => _cameraMessage = 'Linterna no disponible');
    }
  }

  Future<void> _switchCamera() async {
    try {
      await _controller.switchCamera();
    } catch (_) {
      if (mounted)
        setState(() => _cameraMessage = 'No se pudo cambiar la cámara');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escanear producto')),
      body: ScreenFrame(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Código de barras',
              style: TextStyle(
                color: AppColors.deepBlue,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Apuntá la cámara al código del envase',
              style: TextStyle(color: AppColors.textGray, fontSize: 13),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MobileScanner(
                      controller: _controller,
                      onDetect: (capture) {
                        for (final barcode in capture.barcodes) {
                          if (normalizedBarcode(barcode.rawValue) != null) {
                            _submit(barcode.rawValue);
                            return;
                          }
                        }
                      },
                      errorBuilder: (context, error) => Container(
                        color: const Color(0xFF172233),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(24),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.no_photography_outlined,
                              color: Colors.white70,
                              size: 38,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'No se pudo abrir la cámara. Ingresá el código abajo.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Center(
                      child: IgnorePointer(
                        child: FractionallySizedBox(
                          widthFactor: 0.82,
                          heightFactor: 0.42,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white, width: 2),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x66000000),
                                  blurRadius: 18,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Container(
                                height: 2,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                color: AppColors.green,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 16,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ValueListenableBuilder<MobileScannerState>(
                            valueListenable: _controller,
                            builder: (context, camera, child) =>
                                IconButton.filledTonal(
                                  tooltip: camera.torchState == TorchState.on
                                      ? 'Apagar linterna'
                                      : 'Encender linterna',
                                  onPressed:
                                      camera.torchState ==
                                          TorchState.unavailable
                                      ? null
                                      : () => unawaited(_toggleTorch()),
                                  icon: Icon(
                                    camera.torchState == TorchState.on
                                        ? Icons.flash_on
                                        : Icons.flash_off,
                                  ),
                                ),
                          ),
                          const SizedBox(width: 14),
                          IconButton.filledTonal(
                            tooltip: 'Cambiar cámara',
                            onPressed: () => unawaited(_switchCamera()),
                            icon: const Icon(Icons.cameraswitch_outlined),
                          ),
                        ],
                      ),
                    ),
                    if (_cameraMessage != null)
                      Positioned(
                        top: 14,
                        left: 14,
                        right: 14,
                        child: Text(
                          _cameraMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            TextField(
              controller: _manual,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(14),
              ],
              textInputAction: TextInputAction.search,
              onSubmitted: _submit,
              decoration: InputDecoration(
                labelText: 'Ingresar código manualmente',
                errorText: _error,
                prefixIcon: const Icon(Icons.numbers),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => _submit(_manual.text),
              icon: const Icon(Icons.search),
              label: const Text('Buscar producto'),
            ),
          ],
        ),
      ),
    );
  }
}

Future<String?> scanBarcode(BuildContext context) =>
    Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (context) => const BarcodeScannerScreen()),
    );
