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
    'eliminar la cuenta contra el servidor',
    skip: serverUrl.isEmpty ? 'sin servidor' : null,
    () {
      test('después de eliminarla, ya no se puede entrar', () async {
        final email = 'borrar.$run@example.test';
        final client = await adultAccount(email);
        addTearDown(client.dispose);
        final profiles = SupabaseProfileRepository(client);

        await profiles.createSupportCase(
          'Antes de irme',
          'Quería dejar un comentario.',
        );
        await profiles.deleteMyAccount();
        await SupabaseAuthRepository(client.auth).signOutLocally();
        expect(client.auth.currentUser, isNull);

        final again = phone();
        addTearDown(again.dispose);
        await expectLater(
          SupabaseAuthRepository(again.auth)
              .signIn(email: email, password: 'Clave-de-prueba-1'),
          throwsA(
            isA<AuthFailure>().having(
              (f) => f.reason,
              'reason',
              AuthFailureReason.invalidCredentials,
            ),
          ),
        );
      });

      test('el mismo correo puede volver a registrarse', () async {
        final email = 'reusar.$run@example.test';
        final first = await adultAccount(email);
        await SupabaseProfileRepository(first).deleteMyAccount();
        await first.dispose();

        final second = await adultAccount(email);
        addTearDown(second.dispose);
        expect(second.auth.currentUser?.email, email);
      });
    },
  );
}
