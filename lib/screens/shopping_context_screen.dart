import 'package:flutter/material.dart';

import '../models/shopping_context.dart';
import '../services/device_location_service.dart';
import '../state/app_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/screen_frame.dart';

class ShoppingContextScreen extends StatefulWidget {
  const ShoppingContextScreen({super.key});

  @override
  State<ShoppingContextScreen> createState() => _ShoppingContextScreenState();
}

class _ShoppingContextScreenState extends State<ShoppingContextScreen> {
  late final TextEditingController _postalCodeController;
  late final TextEditingController _cotoStoreController;
  late FulfillmentMode _fulfillment;
  var _initialized = false;
  var _locating = false;
  String? _locationMessage;
  DateTime? _lastValidationFeedbackAt;
  String? _lastValidationFeedback;

  @override
  void initState() {
    super.initState();
    _postalCodeController = TextEditingController();
    _cotoStoreController = TextEditingController();
    _fulfillment = FulfillmentMode.pickup;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }
    final shoppingContext = AppScope.of(context).shoppingContext;
    _postalCodeController.text = shoppingContext.postalCode;
    _cotoStoreController.text = shoppingContext.cotoStore;
    _fulfillment = shoppingContext.fulfillment;
    _initialized = true;
  }

  @override
  void dispose() {
    _postalCodeController.dispose();
    _cotoStoreController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compra y ubicacion')),
      body: ScreenFrame(
        child: ListView(
          children: [
            const Text(
              'Usamos esta configuracion para consultar precios y stock del canal seleccionado.',
              style: TextStyle(color: AppColors.textGray, fontSize: 13),
            ),
            const SizedBox(height: 20),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.location_on_outlined, color: AppColors.blue),
                      SizedBox(width: 10),
                      Text(
                        'Zona de compra',
                        style: TextStyle(
                          color: AppColors.deepBlue,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _postalCodeController,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    decoration: const InputDecoration(
                      labelText: 'Codigo postal',
                      hintText: 'Ej. 2000',
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _locating ? null : _useDeviceLocation,
                    icon: _locating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location_outlined),
                    label: Text(
                      _locating ? 'Buscando ubicacion...' : 'Usar mi ubicacion',
                    ),
                  ),
                  if (_locationMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _locationMessage!,
                      style: const TextStyle(
                        color: AppColors.textGray,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  SegmentedButton<FulfillmentMode>(
                    segments: const [
                      ButtonSegment(
                        value: FulfillmentMode.pickup,
                        icon: Icon(Icons.storefront_outlined),
                        label: Text('Retiro'),
                      ),
                      ButtonSegment(
                        value: FulfillmentMode.delivery,
                        icon: Icon(Icons.local_shipping_outlined),
                        label: Text('Envio'),
                      ),
                    ],
                    selected: {_fulfillment},
                    onSelectionChanged: (value) =>
                        setState(() => _fulfillment = value.first),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sucursal Coto',
                    style: TextStyle(
                      color: AppColors.deepBlue,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'El precio y la disponibilidad de Coto se consultan para esta sucursal.',
                    style: TextStyle(color: AppColors.textGray, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _cotoStoreController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'ID de sucursal',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const AppCard(
              color: AppColors.softBlue,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: AppColors.blue),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Carrefour se consulta por canal online. La Gallega todavia no publica stock por sucursal, por eso sus resultados se identifican como catalogo general.',
                      style: TextStyle(color: AppColors.deepBlue, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: const Text('Guardar configuracion'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final postalCode = _postalCodeController.text.trim();
    final cotoStore = _cotoStoreController.text.trim();
    if (postalCode.isNotEmpty && !RegExp(r'^\d{4}$').hasMatch(postalCode)) {
      _showValidationFeedback('El codigo postal debe tener 4 digitos.');
      return;
    }
    if (!RegExp(r'^\d{1,6}$').hasMatch(cotoStore)) {
      _showValidationFeedback('Ingresa un ID de sucursal Coto valido.');
      return;
    }
    await AppScope.of(context).updateShoppingContext(
      ShoppingContext(
        postalCode: postalCode,
        fulfillment: _fulfillment,
        cotoStore: cotoStore,
        latitude: AppScope.of(context).shoppingContext.latitude,
        longitude: AppScope.of(context).shoppingContext.longitude,
        locationAccuracyMeters: AppScope.of(
          context,
        ).shoppingContext.locationAccuracyMeters,
      ),
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _showValidationFeedback(String message) {
    final now = DateTime.now();
    final lastFeedbackAt = _lastValidationFeedbackAt;
    if (lastFeedbackAt != null &&
        message == _lastValidationFeedback &&
        now.difference(lastFeedbackAt) < const Duration(milliseconds: 1200)) {
      return;
    }
    _lastValidationFeedbackAt = now;
    _lastValidationFeedback = message;

    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          elevation: 8,
          backgroundColor: const Color(0xFF8F2D00),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 4),
          dismissDirection: DismissDirection.horizontal,
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: AppColors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  Future<void> _useDeviceLocation() async {
    setState(() {
      _locating = true;
      _locationMessage = null;
    });
    try {
      final location = await const DeviceLocationService().locate();
      if (!mounted) return;
      final suggestion = await AppScope.of(context).updateDeviceLocation(
        latitude: location.latitude,
        longitude: location.longitude,
        accuracyMeters: location.accuracyMeters,
      );
      if (!mounted) return;
      setState(() {
        if (suggestion != null) {
          _cotoStoreController.text = suggestion.storeId;
          _locationMessage =
              'Sugerimos ${suggestion.name} a ${suggestion.distanceKm.toStringAsFixed(1)} km.';
        } else {
          _locationMessage =
              'Ubicacion detectada. Conservamos tu sucursal actual hasta que haya una sucursal configurada para tu zona.';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locationMessage =
            'No pudimos usar tu ubicacion. Revisa el permiso del navegador o ingresa el codigo postal.';
      });
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }
}
