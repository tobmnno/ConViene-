String formatMoney(double value, {bool compactCents = true}) {
  final rounded = (value * 100).round() / 100;
  final hasCents = (rounded - rounded.truncateToDouble()).abs() > 0.001;
  final fixed = rounded.toStringAsFixed(hasCents || !compactCents ? 2 : 0);
  final parts = fixed.split('.');
  final integer = parts.first;
  final cents = parts.length > 1 ? parts.last : '';
  final buffer = StringBuffer();

  for (var i = 0; i < integer.length; i += 1) {
    final fromEnd = integer.length - i;
    buffer.write(integer[i]);
    if (fromEnd > 1 && fromEnd % 3 == 1) {
      buffer.write('.');
    }
  }

  if (cents.isEmpty || (compactCents && cents == '00')) {
    return '\$${buffer.toString()}';
  }
  return '\$${buffer.toString()},$cents';
}

String formatPercent(double value) {
  if (value == value.roundToDouble()) {
    return '${value.round()}%';
  }
  return '${value.toStringAsFixed(1)}%';
}

String weekdayShort(int weekday) {
  return switch (weekday) {
    DateTime.monday => 'LUN',
    DateTime.tuesday => 'MAR',
    DateTime.wednesday => 'MIE',
    DateTime.thursday => 'JUE',
    DateTime.friday => 'VIE',
    DateTime.saturday => 'SAB',
    DateTime.sunday => 'DOM',
    _ => '',
  };
}

String monthName(int month) {
  return switch (month) {
    DateTime.january => 'enero',
    DateTime.february => 'febrero',
    DateTime.march => 'marzo',
    DateTime.april => 'abril',
    DateTime.may => 'mayo',
    DateTime.june => 'junio',
    DateTime.july => 'julio',
    DateTime.august => 'agosto',
    DateTime.september => 'septiembre',
    DateTime.october => 'octubre',
    DateTime.november => 'noviembre',
    DateTime.december => 'diciembre',
    _ => '',
  };
}

String longDate(DateTime date) {
  final dayName = switch (date.weekday) {
    DateTime.monday => 'Lunes',
    DateTime.tuesday => 'Martes',
    DateTime.wednesday => 'Miercoles',
    DateTime.thursday => 'Jueves',
    DateTime.friday => 'Viernes',
    DateTime.saturday => 'Sabado',
    DateTime.sunday => 'Domingo',
    _ => '',
  };
  return '$dayName ${date.day} de ${monthName(date.month)}';
}
