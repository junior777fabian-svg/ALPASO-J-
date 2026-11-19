import 'package:alpaso/core/format/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatSoles', () {
    test('muestra siempre dos decimales', () {
      expect(formatSoles(0), 'S/ 0.00');
      expect(formatSoles(5), 'S/ 0.05');
      expect(formatSoles(50), 'S/ 0.50');
      expect(formatSoles(3500), 'S/ 35.00');
      expect(formatSoles(3599), 'S/ 35.99');
    });

    test('separa los miles con coma', () {
      expect(formatSoles(99999), 'S/ 999.99');
      expect(formatSoles(100000), 'S/ 1,000.00');
      expect(formatSoles(123456), 'S/ 1,234.56');
      expect(formatSoles(123456789), 'S/ 1,234,567.89');
    });

    test('un reembolso se muestra con signo', () {
      expect(formatSoles(-3500), '-S/ 35.00');
      expect(formatSoles(-5), '-S/ 0.05');
    });
  });

  group('parseSolesToCents', () {
    test('acepta las formas comunes de escribir soles', () {
      expect(parseSolesToCents('45'), 4500);
      expect(parseSolesToCents('45.5'), 4550);
      expect(parseSolesToCents('45,50'), 4550);
      expect(parseSolesToCents(' S/ 12.05 '), 1205);
      expect(parseSolesToCents('0.5'), 50);
    });

    test('rechaza lo que no es un monto', () {
      expect(parseSolesToCents(''), isNull);
      expect(parseSolesToCents('abc'), isNull);
      expect(parseSolesToCents('1.234'), isNull, reason: 'tres decimales');
      expect(parseSolesToCents('-5'), isNull);
      expect(parseSolesToCents('1,000.50'), isNull);
    });

    test('ida y vuelta con centsToInput', () {
      for (final cents in [50, 100, 4500, 4550, 123405]) {
        expect(parseSolesToCents(centsToInput(cents)), cents);
      }
    });
  });
}
