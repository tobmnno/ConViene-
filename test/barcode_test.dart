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
    expect(normalizedBarcode('779089500829'), isNull);
    expect(normalizedBarcode('00000000'), isNull);
  });

  test('accepts Sprite EAN-13 and Guaymallen EAN-8', () {
    expect(normalizedBarcode('7790895000829'), '7790895000829');
    expect(normalizedBarcode('77980267'), '77980267');
  });
}
