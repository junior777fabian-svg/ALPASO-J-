import 'package:alpaso/features/auth/data/auth_repository.dart';
import 'package:alpaso/features/auth/domain/auth_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('los errores del servicio de cuentas se traducen', () {
    final cases = {
      'invalid_credentials': AuthFailureReason.invalidCredentials,
      'user_already_exists': AuthFailureReason.emailInUse,
      'email_exists': AuthFailureReason.emailInUse,
      'weak_password': AuthFailureReason.weakPassword,
      'email_address_invalid': AuthFailureReason.invalidEmail,
      'email_not_confirmed': AuthFailureReason.emailNotConfirmed,
      'over_request_rate_limit': AuthFailureReason.rateLimited,
      'signup_disabled': AuthFailureReason.signupDisabled,
      'user_banned': AuthFailureReason.blocked,
      'algo_nuevo': AuthFailureReason.unknown,
    };
    for (final MapEntry(key: code, value: reason) in cases.entries) {
      test(code, () {
        final failure = mapAuthException(
          AuthException('mensaje', statusCode: '400', code: code),
        );
        expect(failure.reason, reason);
      });
    }

    test('sin conexión', () {
      final failure = mapAuthException(
        AuthRetryableFetchException(message: 'sin red'),
      );
      expect(failure.reason, AuthFailureReason.network);
    });
  });
}
