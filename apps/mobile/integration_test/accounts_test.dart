// Recorrido de cuentas en un teléfono o emulador, contra un servidor real:
//
//   flutter test integration_test/accounts_test.dart -d <dispositivo> \
//     --dart-define=APP_ENV=demo \
//     --dart-define=SUPABASE_URL=<servidor> \
//     --dart-define=SUPABASE_PUBLISHABLE_KEY=<llave publicable>
//
// Sin servidor se salta. Crea una cuenta nueva con correo @example.test.

import 'package:alpaso/app/app.dart';
import 'package:alpaso/app/env/app_config.dart';
import 'package:alpaso/app/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Finder tab(String label) => find.widgetWithText(NavigationDestination, label);

/// Espera a que aparezca algo que depende del servidor.
Future<void> waitFor(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 100; i++) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  expect(finder, findsWidgets, reason: 'no apareció a los 20 segundos');
}

Future<void> tapSubmit(WidgetTester tester) async {
  final submit = find.byKey(const Key('auth-submit'));
  await tester.ensureVisible(submit);
  await tester.tap(submit);
  await tester.pump();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.fromEnvironment();

  testWidgets(
    'crea una cuenta, cierra sesión y vuelve a entrar',
    skip: !config.hasServer,
    (tester) async {
      await Supabase.initialize(
        url: config.supabaseUrl,
        publishableKey: config.supabasePublishableKey,
      );
      await Supabase.instance.client.auth.signOut();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appConfigProvider.overrideWithValue(config)],
          retry: (retryCount, error) => null,
          child: const AlPasoApp(),
        ),
      );
      await tester.pumpAndSettle();

      final email =
          'telefono.${DateTime.now().millisecondsSinceEpoch}'
          '@example.test';
      const password = 'Clave-del-telefono-1';

      await tester.tap(tab('Perfil'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Crear cuenta'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('auth-name')), 'Teléfono');
      await tester.enterText(find.byKey(const Key('auth-email')), email);
      await tester.enterText(find.byKey(const Key('auth-password')), password);
      await tester.tap(find.byKey(const Key('auth-adult')));
      await tapSubmit(tester);

      await waitFor(tester, find.text('Mayoría de edad confirmada'));
      expect(find.text('Teléfono'), findsOneWidget);
      expect(find.text(email), findsOneWidget);

      await tester.ensureVisible(find.text('Cerrar sesión'));
      await tester.tap(find.text('Cerrar sesión'));
      await waitFor(tester, find.text('Iniciar sesión'));

      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('auth-email')), email);
      await tester.enterText(find.byKey(const Key('auth-password')), password);
      await tapSubmit(tester);

      await waitFor(tester, find.text('Mayoría de edad confirmada'));
      expect(find.text('Teléfono'), findsOneWidget);
    },
  );
}
