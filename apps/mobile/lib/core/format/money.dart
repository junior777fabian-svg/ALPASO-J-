/// Convierte un monto en céntimos a texto en soles.
///
/// Los precios se guardan y viajan como enteros en céntimos para no perder
/// decimales. Solo se convierten a texto al mostrarlos.
///
/// ```dart
/// formatSoles(3500);    // 'S/ 35.00'
/// formatSoles(123456);  // 'S/ 1,234.56'
/// ```
String formatSoles(int cents) {
  final sign = cents < 0 ? '-' : '';
  final absolute = cents.abs();
  final digits = (absolute ~/ 100).toString();
  final fraction = (absolute % 100).toString().padLeft(2, '0');

  final whole = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) whole.write(',');
    whole.write(digits[i]);
  }

  return '${sign}S/ $whole.$fraction';
}

/// Lee un monto escrito en soles ("45", "45.5", "45,50", "S/ 45") y lo
/// devuelve en céntimos. Nulo si no es un monto válido o tiene más de dos
/// decimales.
int? parseSolesToCents(String text) {
  var value = text.trim().replaceAll(RegExp(r'^S/\s*'), '').replaceAll(' ', '');
  if (value.isEmpty) return null;
  value = value.replaceAll(',', '.');
  final match = RegExp(r'^(\d{1,6})(?:\.(\d{1,2}))?$').firstMatch(value);
  if (match == null) return null;
  final whole = int.parse(match.group(1)!);
  final fraction = (match.group(2) ?? '').padRight(2, '0');
  return whole * 100 + int.parse(fraction);
}

/// Céntimos como texto editable: 4550 → "45.50", 4500 → "45".
String centsToInput(int cents) {
  final whole = cents ~/ 100;
  final fraction = cents % 100;
  return fraction == 0
      ? '$whole'
      : '$whole.${fraction.toString().padLeft(2, '0')}';
}
