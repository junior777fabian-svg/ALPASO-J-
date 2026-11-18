import 'package:alpaso/features/auth/domain/auth_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('correo', () {
    expect(AuthValidators.isValidEmail('ana@correo.pe'), isTrue);
    expect(AuthValidators.isValidEmail('  ana@correo.pe '), isTrue);
    expect(AuthValidators.isValidEmail('ana@correo'), isFalse);
    expect(AuthValidators.isValidEmail('ana correo.pe'), isFalse);
    expect(AuthValidators.isValidEmail(''), isFalse);
  });

  test('contraseña de al menos 8 caracteres, como el servidor', () {
    expect(AuthValidators.isValidPassword('1234567'), isFalse);
    expect(AuthValidators.isValidPassword('12345678'), isTrue);
  });

  test('nombre entre 1 y 80 caracteres, como la base', () {
    expect(AuthValidators.isValidName('   '), isFalse);
    expect(AuthValidators.isValidName('Ana'), isTrue);
    expect(AuthValidators.isValidName('a' * 80), isTrue);
    expect(AuthValidators.isValidName('a' * 81), isFalse);
  });
}
