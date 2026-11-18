import 'package:alpaso/features/auth/domain/auth_failure.dart';
import 'package:alpaso/features/auth/presentation/sign_in_screen.dart';
import 'package:alpaso/features/auth/presentation/sign_up_screen.dart';
import 'package:alpaso/features/profile/presentation/profile_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_account.dart';
import '../../support/pump_app.dart';

Finder tab(String label) => find.widgetWithText(NavigationDestination, label);

Future<void> openProfile(WidgetTester tester, FakeAccountServer server) async {
  await tester.pumpAlPaso(config: demoServerConfig, server: server);
  await tester.tap(tab('Perfil'));
  await tester.pumpAndSettle();
}

Future<void> fillSignUp(
  WidgetTester tester, {
  String name = 'Ana Torres',
  String email = 'ana@correo.pe',
  String password = 'clave-segura',
  bool adult = true,
}) async {
  await tester.enterText(find.byKey(const Key('auth-name')), name);
  await tester.enterText(find.byKey(const Key('auth-email')), email);
  await tester.enterText(find.byKey(const Key('auth-password')), password);
  if (adult) await tester.tap(find.byKey(const Key('auth-adult')));
  await tester.pump();
}

Future<void> submit(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('auth-submit')));
  await tester.tap(find.byKey(const Key('auth-submit')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sin servidor el perfil avisa que no hay cuentas', (
    tester,
  ) async {
    await tester.pumpAlPaso();
    await tester.tap(tab('Perfil'));
    await tester.pumpAndSettle();

    expect(find.text('Cuentas no disponibles'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsNothing);
    expect(find.text('Ir al modo negocio'), findsOneWidget);
  });

  testWidgets('sin sesión ofrece entrar o crear cuenta', (tester) async {
    await openProfile(tester, FakeAccountServer());

    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Crear cuenta'), findsOneWidget);
    expect(find.text('Ir al modo negocio'), findsOneWidget);
    expect(find.text('Entorno: demo · Servidor configurado'), findsOneWidget);
  });

  group('registro', () {
    testWidgets('valida los campos sin llamar al servidor', (tester) async {
      final server = FakeAccountServer();
      await openProfile(tester, server);
      await tester.tap(find.text('Crear cuenta'));
      await tester.pumpAndSettle();
      expect(find.byType(SignUpScreen), findsOneWidget);

      await fillSignUp(
        tester,
        name: ' ',
        email: 'correo-malo',
        password: '123',
        adult: false,
      );
      await submit(tester);

      expect(find.text('Escribe tu nombre (hasta 80 caracteres).'), findsOne);
      expect(find.text('Escribe un correo válido.'), findsOneWidget);
      expect(
        find.text('La contraseña debe tener al menos 8 caracteres.'),
        findsOneWidget,
      );
      expect(
        find.text('Para usar Al Paso debes ser mayor de 18 años.'),
        findsOneWidget,
      );
      expect(server.currentUser, isNull);
    });

    testWidgets('exige declarar la mayoría de edad', (tester) async {
      final server = FakeAccountServer();
      await openProfile(tester, server);
      await tester.tap(find.text('Crear cuenta'));
      await tester.pumpAndSettle();

      await fillSignUp(tester, adult: false);
      await submit(tester);

      expect(
        find.text('Para usar Al Paso debes ser mayor de 18 años.'),
        findsOneWidget,
      );
      expect(server.currentUser, isNull);
    });

    testWidgets('crea la cuenta, confirma la edad y muestra el perfil', (
      tester,
    ) async {
      final server = FakeAccountServer();
      await openProfile(tester, server);
      await tester.tap(find.text('Crear cuenta'));
      await tester.pumpAndSettle();

      await fillSignUp(tester);
      await submit(tester);

      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.text('Ana Torres'), findsOneWidget);
      expect(find.text('ana@correo.pe'), findsOneWidget);
      expect(find.text('Mayoría de edad confirmada'), findsOneWidget);
      expect(find.byKey(const Key('profile-adult-pending')), findsNothing);
      expect(server.profiles[server.currentUser!.id]!.isAdultConfirmed, isTrue);
    });

    testWidgets('si la confirmación de edad falla, el perfil la vuelve a '
        'pedir', (tester) async {
      final server = FakeAccountServer()..failConfirmAdult = true;
      await openProfile(tester, server);
      await tester.tap(find.text('Crear cuenta'));
      await tester.pumpAndSettle();
      await fillSignUp(tester);
      await submit(tester);

      expect(find.byKey(const Key('profile-adult-pending')), findsOneWidget);

      server.failConfirmAdult = false;
      await tester.tap(find.text('Tengo 18 años o más'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('profile-adult-pending')), findsNothing);
      expect(find.text('Mayoría de edad confirmada'), findsOneWidget);
    });

    testWidgets('un correo ya registrado muestra el aviso', (tester) async {
      final server = FakeAccountServer()
        ..seed(email: 'ana@correo.pe', password: 'otra-clave');
      await openProfile(tester, server);
      await tester.tap(find.text('Crear cuenta'));
      await tester.pumpAndSettle();
      await fillSignUp(tester);
      await submit(tester);

      expect(
        find.text('Ya existe una cuenta con ese correo. Inicia sesión.'),
        findsOneWidget,
      );
      expect(find.byType(SignUpScreen), findsOneWidget);
    });

    testWidgets('si el servidor pide confirmar el correo lo explica', (
      tester,
    ) async {
      final server = FakeAccountServer()
        ..nextFailure = AuthFailureReason.emailNotConfirmed;
      await openProfile(tester, server);
      await tester.tap(find.text('Crear cuenta'));
      await tester.pumpAndSettle();
      await fillSignUp(tester);
      await submit(tester);

      expect(find.textContaining('pide confirmar el correo'), findsOneWidget);
    });
  });

  group('inicio de sesión', () {
    testWidgets('con clave equivocada muestra el aviso', (tester) async {
      final server = FakeAccountServer()
        ..seed(email: 'ana@correo.pe', password: 'clave-segura');
      await openProfile(tester, server);
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();
      expect(find.byType(SignInScreen), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('auth-email')),
        'ana@correo.pe',
      );
      await tester.enterText(find.byKey(const Key('auth-password')), 'mala');
      await submit(tester);

      expect(
        find.text('El correo o la contraseña no son correctos.'),
        findsOneWidget,
      );
      expect(server.currentUser, isNull);
    });

    testWidgets('pide la contraseña sin hablar de su largo', (tester) async {
      final server = FakeAccountServer();
      await openProfile(tester, server);
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('auth-email')),
        'ana@correo.pe',
      );
      await submit(tester);

      expect(find.text('Escribe tu contraseña.'), findsOneWidget);
      expect(find.textContaining('8 caracteres'), findsNothing);
    });

    testWidgets('sin conexión lo dice', (tester) async {
      final server = FakeAccountServer()
        ..nextFailure = AuthFailureReason.network;
      await openProfile(tester, server);
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('auth-email')),
        'ana@correo.pe',
      );
      await tester.enterText(find.byKey(const Key('auth-password')), 'x');
      await submit(tester);

      expect(
        find.text('No hay conexión con el servidor. Revisa tu internet.'),
        findsOneWidget,
      );
    });

    testWidgets('entra, cambia el nombre y cierra sesión', (tester) async {
      final server = FakeAccountServer()
        ..seed(
          email: 'ana@correo.pe',
          password: 'clave-segura',
          fullName: 'Ana',
        );
      await openProfile(tester, server);
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('auth-email')),
        'ana@correo.pe',
      );
      await tester.enterText(
        find.byKey(const Key('auth-password')),
        'clave-segura',
      );
      await submit(tester);

      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.text('Ana'), findsOneWidget);

      await tester.tap(find.byTooltip('Cambiar nombre'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('profile-name-field')),
        'Ana María',
      );
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.text('Ana María'), findsOneWidget);
      expect(server.profiles[server.currentUser!.id]!.fullName, 'Ana María');

      await tester.ensureVisible(find.text('Cerrar sesión'));
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();
      expect(find.text('Iniciar sesión'), findsOneWidget);
      expect(server.currentUser, isNull);
    });

    testWidgets('una cuenta sin edad confirmada ve el aviso', (tester) async {
      final server = FakeAccountServer();
      final user = server.seed(
        email: 'ana@correo.pe',
        password: 'clave-segura',
        adult: false,
      );
      server.currentUser = user;
      await openProfile(tester, server);

      expect(find.byKey(const Key('profile-adult-pending')), findsOneWidget);
      expect(find.text('Sin nombre'), findsOneWidget);
    });
  });
}
