@Tags(['server'])
library;

import 'package:alpaso/features/auth/data/auth_repository.dart';
import 'package:alpaso/features/auth/domain/auth_failure.dart';
import 'package:alpaso/features/profile/data/profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _url = String.fromEnvironment('SUPABASE_URL');
const _key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

/// Un cliente nuevo por cuenta, como un teléfono distinto.
SupabaseClient _phone() => SupabaseClient(
  _url,
  _key,
  authOptions: const AuthClientOptions(
    autoRefreshToken: false,
    authFlowType: AuthFlowType.implicit,
  ),
);

Matcher _failsWith(AuthFailureReason reason) =>
    throwsA(isA<AuthFailure>().having((f) => f.reason, 'reason', reason));

void main() {
  final run = DateTime.now().microsecondsSinceEpoch;
  String email(String name) => '$name.$run@example.test';
  const password = 'Clave-de-prueba-1';

  group(
    'cuentas contra el servidor',
    skip: _url.isEmpty ? 'sin servidor' : null,
    () {
      late SupabaseClient ana;
      late SupabaseAuthRepository anaAuth;
      late SupabaseProfileRepository anaProfile;

      setUpAll(() async {
        ana = _phone();
        anaAuth = SupabaseAuthRepository(ana.auth);
        anaProfile = SupabaseProfileRepository(ana);
      });

      tearDownAll(() async => ana.dispose());

      test('el registro crea la sesión y el perfil con el nombre', () async {
        final user = await anaAuth.signUp(
          email: email('ana'),
          password: password,
          fullName: '  Ana Torres  ',
        );
        expect(user.email, email('ana'));
        expect(anaAuth.currentUser?.id, user.id);

        final profile = await anaProfile.fetchMine();
        expect(profile.id, user.id);
        expect(profile.fullName, 'Ana Torres');
        expect(profile.isAdultConfirmed, isFalse);
        expect(profile.isBlocked, isFalse);
      });

      test('la mayoría de edad la fecha el servidor y no cambia', () async {
        final first = await anaProfile.confirmAdult();
        final again = await anaProfile.confirmAdult();
        expect(again, first);
        expect(
          first.difference(DateTime.now()).inMinutes.abs(),
          lessThan(5),
          reason: 'la hora la pone el servidor al confirmar',
        );
        expect((await anaProfile.fetchMine()).isAdultConfirmed, isTrue);
      });

      test('la cuenta cambia su nombre', () async {
        final updated = await anaProfile.updateFullName('Ana María');
        expect(updated.fullName, 'Ana María');
        expect((await anaProfile.fetchMine()).fullName, 'Ana María');
      });

      test('un nombre de más de 80 caracteres lo rechaza la base', () async {
        await expectLater(
          anaProfile.updateFullName('x' * 81),
          throwsA(isA<AuthFailure>()),
        );
      });

      test('el mismo correo no se registra dos veces', () async {
        final other = _phone();
        addTearDown(other.dispose);
        await expectLater(
          SupabaseAuthRepository(
            other.auth,
          ).signUp(email: email('ana'), password: password, fullName: 'Otra'),
          _failsWith(AuthFailureReason.emailInUse),
        );
      });

      test('la contraseña corta la rechaza el servidor', () async {
        final other = _phone();
        addTearDown(other.dispose);
        await expectLater(
          SupabaseAuthRepository(
            other.auth,
          ).signUp(email: email('corta'), password: '1234', fullName: 'Corta'),
          _failsWith(AuthFailureReason.weakPassword),
        );
      });

      test(
        'cerrar sesión y volver a entrar recupera el mismo perfil',
        () async {
          final id = anaAuth.currentUser!.id;
          await anaAuth.signOut();
          expect(anaAuth.currentUser, isNull);

          await expectLater(
            anaAuth.signIn(email: email('ana'), password: 'otra-clave'),
            _failsWith(AuthFailureReason.invalidCredentials),
          );

          final user = await anaAuth.signIn(
            email: email('ana'),
            password: password,
          );
          expect(user.id, id);
          final profile = await anaProfile.fetchMine();
          expect(profile.fullName, 'Ana María');
          expect(profile.isAdultConfirmed, isTrue);
        },
      );

      test('otra cuenta no ve ni cambia el perfil de Ana', () async {
        final luis = _phone();
        addTearDown(luis.dispose);
        await SupabaseAuthRepository(luis.auth)
            .signUp(email: email('luis'), password: password, fullName: 'Luis');

        final anaId = anaAuth.currentUser!.id;
        final seen = await luis.from('profiles').select().eq('id', anaId);
        expect(seen, isEmpty);

        final changed = await luis
            .from('profiles')
            .update({'full_name': 'Hackeado'})
            .eq('id', anaId)
            .select();
        expect(changed, isEmpty);
        expect((await anaProfile.fetchMine()).fullName, 'Ana María');
      });

      test(
        'la app no puede marcarse mayor de edad ni desbloquearse a mano',
        () async {
          await expectLater(
            ana
                .from('profiles')
                .update({'adult_confirmed_at': '2000-01-01T00:00:00Z'})
                .eq('id', anaAuth.currentUser!.id),
            throwsA(isA<PostgrestException>()),
          );
          await expectLater(
            ana
                .from('profiles')
                .update({'is_blocked': false})
                .eq('id', anaAuth.currentUser!.id),
            throwsA(isA<PostgrestException>()),
          );
        },
      );

      test('sin sesión no se puede confirmar la mayoría de edad', () async {
        final nobody = _phone();
        addTearDown(nobody.dispose);
        await expectLater(
          SupabaseProfileRepository(nobody).confirmAdult(),
          throwsA(isA<AuthFailure>()),
        );
      });
    },
  );
}
