String? normalizedBarcode(String? value) {
  final code = value?.trim() ?? '';
  if (!RegExp(r'^\d{8}$|^\d{12,14}$').hasMatch(code)) return null;
  final digits = code.split('').map(int.parse).toList();
  var sum = 0;
  for (
    var index = digits.length - 2, weight = 3;
    index >= 0;
    index--, weight = 4 - weight
  ) {
    sum += digits[index] * weight;
  }
  return (sum + digits.last) % 10 == 0 ? code : null;
}
