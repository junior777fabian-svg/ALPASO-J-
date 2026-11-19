@Tags(['server'])
library;

import 'package:alpaso/features/auth/data/auth_repository.dart';
import 'package:alpaso/features/auth/domain/auth_failure.dart';
import 'package:alpaso/features/profile/data/profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'server_support.dart';

void main() {
  final run = DateTime.now().microsecondsSinceEpoch;

  group(
    'verificar el celular contra el servidor',
    skip: serverUrl.isEmpty ? 'sin servidor' : null,
    () {
      test('el código demo verifica el celular y queda en el perfil', () async {
        final client = phone();
        addTearDown(client.dispose);
        await SupabaseAuthRepository(client.auth).signUp(
          email: 'cel.$run@example.test',
          password: 'Clave-de-prueba-1',
          fullName: 'Celular',
        );
        final profiles = SupabaseProfileRepository(client);
        final number = testPhone();

        await expectLater(
          profiles.requestPhoneCode('123'),
          throwsA(
            isA<AuthFailure>().having(
              (f) => f.reason,
              'reason',
              AuthFailureReason.invalidPhone,
            ),
          ),
        );
        final code = await profiles.requestPhoneCode(number);
        expect(code, '123456', reason: 'conector demo');
        await expectLater(
          profiles.verifyPhoneCode('000000'),
          throwsA(
            isA<AuthFailure>().having(
              (f) => f.reason,
              'reason',
              AuthFailureReason.wrongCode,
            ),
          ),
        );
        expect(await profiles.verifyPhoneCode(code!), '+51$number');
        final profile = await profiles.fetchMine();
        expect(profile.isPhoneVerified, isTrue);
        expect(profile.phone, '+51$number');
      });
    },
  );
}
