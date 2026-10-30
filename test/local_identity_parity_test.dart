import 'dart:convert';
import 'dart:io';

import 'package:conviene/models/product.dart';
import 'package:conviene/repositories/mock_repository.dart';
import 'package:conviene/services/discount_engine.dart';
import 'package:conviene/services/price_comparison_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local matcher follows the shared backend identity cases', () {
    final cases = <dynamic>[
      for (final fixture in [
        'product_identity_cases.json',
        'product_identity_verified_cases.json',
      ])
        ...jsonDecode(File('test/fixtures/$fixture').readAsStringSync())
            as List<dynamic>,
    ];
    final service = PriceComparisonService(
      MockRepository(),
      const DiscountEngine(),
    );
    Product makeProduct(Map<String, dynamic> data, String id) => Product(
      id: id,
      ean: data['ean'] as String? ?? '',
      name: data['name'] as String,
      brand: data['brand'] as String,
      presentation: '',
      unit: '',
      category: '',
      imageTag: '',
    );

    for (final raw in cases) {
      final caseData = raw as Map<String, dynamic>;
      final selected = makeProduct(
        caseData['selected'] as Map<String, dynamic>,
        'selected',
      );
      final candidate = makeProduct(
        caseData['candidate'] as Map<String, dynamic>,
        'candidate',
      );
      expect(
        service.matchesLocalProduct(selected, candidate),
        caseData['same_product'],
        reason: caseData['id'] as String,
      );
    }
  });
}
