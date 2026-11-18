import 'package:alpaso/features/profile/domain/profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lee la fila de profiles', () {
    final profile = Profile.fromJson({
      'id': 'abc',
      'full_name': 'Ana',
      'adult_confirmed_at': '2026-11-18T10:00:00+00:00',
      'is_blocked': false,
    });
    expect(profile.fullName, 'Ana');
    expect(profile.isAdultConfirmed, isTrue);
    expect(profile.adultConfirmedAt, DateTime.utc(2026, 11, 18, 10));
  });

  test('sin confirmación de mayoría de edad', () {
    final profile = Profile.fromJson({
      'id': 'abc',
      'full_name': '',
      'adult_confirmed_at': null,
      'is_blocked': true,
    });
    expect(profile.isAdultConfirmed, isFalse);
    expect(profile.isBlocked, isTrue);
  });
}
