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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escanear codigo de barras')),
      body: ScreenFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: MobileScanner(
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
                    color: AppColors.softBlue,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(20),
                    child: const Text(
                      'No se pudo abrir la camara. Podes ingresar el codigo manualmente.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Coloca el codigo de barras dentro del recuadro.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
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
                labelText: 'O ingresa el codigo',
                errorText: _error,
                prefixIcon: const Icon(Icons.numbers),
              ),
            ),
            const SizedBox(height: 12),
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
