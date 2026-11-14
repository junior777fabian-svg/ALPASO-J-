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
