import 'package:flutter/material.dart';

import '../models/price_quote.dart';
import '../models/supermarket.dart';
import '../state/app_scope.dart';
import '../theme/app_theme.dart';
import '../utils/barcode.dart';

class ContributionScreen extends StatefulWidget {
  const ContributionScreen({
    super.key,
    required this.stores,
    required this.initialQuery,
    this.initialStoreId,
    this.existing,
  });

  final List<Supermarket> stores;
  final String initialQuery;
  final String? initialStoreId;
  final SearchResult? existing;

  @override
  State<ContributionScreen> createState() => _ContributionScreenState();
}

class _ContributionScreenState extends State<ContributionScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _brand;
  late final TextEditingController _presentation;
  late final TextEditingController _category;
  late final TextEditingController _ean;
  late final TextEditingController _imageUrl;
  late final TextEditingController _sourceUrl;
  late final TextEditingController _price;
  late final TextEditingController _unitPrice;
  String _unit = 'unidad';
  String? _storeId;
  bool _inStock = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _name = TextEditingController(
      text:
          existing?.product.name ??
          (normalizedBarcode(widget.initialQuery) == null
              ? widget.initialQuery
              : ''),
    );
    _brand = TextEditingController(text: existing?.product.brand ?? '');
    _presentation = TextEditingController(
      text: existing?.product.presentation ?? '',
    );
    _category = TextEditingController(text: existing?.product.category ?? '');
    _ean = TextEditingController(
      text:
          existing?.product.ean ??
          (normalizedBarcode(widget.initialQuery) ?? ''),
    );
    _imageUrl = TextEditingController(text: existing?.product.imageUrl ?? '');
    _sourceUrl = TextEditingController(
      text: existing?.price.url.startsWith('https://') == true
          ? existing!.price.url
          : '',
    );
    _price = TextEditingController(
      text: existing == null
          ? ''
          : existing.price.priceOriginal.toStringAsFixed(2),
    );
    _unitPrice = TextEditingController(
      text: existing == null
          ? ''
          : existing.price.priceUnitario.toStringAsFixed(2),
    );
    _unit = existing?.product.unit ?? 'unidad';
    _storeId =
        existing?.supermarket.id ??
        widget.initialStoreId ??
        (widget.stores.length == 1 ? widget.stores.first.id : null);
    _inStock = existing?.price.stock ?? true;
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _brand,
      _presentation,
      _category,
      _ean,
      _imageUrl,
      _sourceUrl,
      _price,
      _unitPrice,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  double? _number(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));

  String? _required(String? value) =>
      (value?.trim().isEmpty ?? true) ? 'Completa este dato.' : null;

  String? _url(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final uri = Uri.tryParse(value.trim());
    return uri?.scheme == 'https' &&
            uri?.hasAuthority == true &&
            value.length <= 1000
        ? null
        : 'Usa un enlace https valido.';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _storeId == null || _saving) {
      if (_storeId == null) setState(() => _error = 'Elegí un supermercado.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await AppScope.of(context).saveContribution(
        id: widget.existing?.communityPriceId,
        supermarketId: _storeId!,
        name: _name.text,
        brand: _brand.text,
        presentation: _presentation.text,
        unit: _unit,
        category: _category.text,
        ean: _ean.text,
        imageUrl: _imageUrl.text,
        sourceUrl: _sourceUrl.text,
        price: _number(_price.text)!,
        unitPrice: _unitPrice.text.trim().isEmpty
            ? _number(_price.text)!
            : _number(_unitPrice.text)!,
        inStock: _inStock,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted)
        setState(
          () => _error =
              'No se pudo guardar el aporte. Revisa los datos y tu conexion.',
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.existing == null ? 'Agregar producto' : 'Editar aporte',
      ),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                Text(
                  'Precio aportado por la comunidad',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Los precios pueden cambiar. Comprueba el valor antes de comprar.',
                  style: TextStyle(color: AppColors.textGray, fontSize: 12),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: _storeId,
                  decoration: const InputDecoration(labelText: 'Supermercado'),
                  items: [
                    for (final store in widget.stores)
                      DropdownMenuItem(
                        value: store.id,
                        child: Text(store.name),
                      ),
                  ],
                  onChanged: widget.existing == null
                      ? (value) => setState(() => _storeId = value)
                      : null,
                  validator: (value) =>
                      value == null ? 'Elegí un supermercado.' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _name,
                  maxLength: 180,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo del producto',
                  ),
                  validator: (value) => (value?.trim().length ?? 0) >= 3
                      ? null
                      : 'Escribí al menos 3 caracteres.',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _brand,
                  maxLength: 80,
                  decoration: const InputDecoration(labelText: 'Marca'),
                  validator: (value) => null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _presentation,
                  maxLength: 80,
                  decoration: const InputDecoration(
                    labelText: 'Presentacion (ej. 500 ml, pack x 6)',
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _unit,
                  decoration: const InputDecoration(labelText: 'Precio por'),
                  items: const ['unidad', 'kg', 'L', '100 g', '100 ml']
                      .map(
                        (unit) =>
                            DropdownMenuItem(value: unit, child: Text(unit)),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _unit = value ?? 'unidad'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _category,
                  maxLength: 80,
                  decoration: const InputDecoration(
                    labelText: 'Categoria (opcional)',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _ean,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Codigo de barras (opcional)',
                  ),
                  validator: (value) =>
                      (value?.trim().isEmpty ?? true) ||
                          normalizedBarcode(value) != null
                      ? null
                      : 'Codigo de barras invalido.',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _price,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Precio en pesos',
                  ),
                  validator: (value) {
                    final number = _number(value ?? '');
                    return number != null && number > 0 && number <= 9999999999
                        ? null
                        : 'Ingresa un precio mayor que cero.';
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _unitPrice,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Precio por $_unit (opcional)',
                  ),
                  validator: (value) {
                    if (value?.trim().isEmpty ?? true) {
                      return _unit == 'unidad'
                          ? null
                          : 'Indica el precio por $_unit.';
                    }
                    final number = _number(value!);
                    return number != null && number > 0 && number <= 9999999999
                        ? null
                        : 'Ingresa un precio valido.';
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Disponible'),
                  value: _inStock,
                  onChanged: (value) => setState(() => _inStock = value),
                ),
                TextFormField(
                  controller: _imageUrl,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Enlace de imagen https (opcional)',
                  ),
                  validator: _url,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _sourceUrl,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Enlace del producto https (opcional)',
                  ),
                  validator: _url,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: AppColors.errorText)),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    widget.existing == null
                        ? 'Publicar aporte'
                        : 'Guardar cambios',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
