import 'package:conviene/utils/barcode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts real GTIN and preserves leading zeroes', () {
    expect(normalizedBarcode('7790742448309'), '7790742448309');
    expect(normalizedBarcode('07790742448309'), '07790742448309');
  });

  test('rejects wrong checksum, non-numeric data and unsupported lengths', () {
    expect(normalizedBarcode('7790742448308'), isNull);
    expect(normalizedBarcode('779074244830x'), isNull);
    expect(normalizedBarcode('12345'), isNull);
  });
}
