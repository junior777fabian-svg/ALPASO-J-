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
}
