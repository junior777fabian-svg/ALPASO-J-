import 'package:alpaso/features/auth/domain/auth_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_account.dart';
import '../../support/fake_earnings.dart';
import '../../support/pump_app.dart';

FakeAccountServer signedIn() {
  final accounts = FakeAccountServer();
  accounts.currentUser = accounts.seed(
    email: 'ana@correo.pe',
    password: 'x',
    fullName: 'Ana',
  );
  return accounts;
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: find.byType(Scrollable).hitTestable().first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('ayuda envía el mensaje a soporte', (tester) async {
    final accounts = signedIn();
    await tester.pumpAlPaso(
      config: demoServerConfig,
      server: accounts,
      initialLocation: '/ayuda',
    );
    await tester.enterText(find.byKey(const Key('support-subject')), 'Código');
    await tester.enterText(
      find.byKey(const Key('support-message')),
      'No funcionó el código en recepción.',
    );
    await tapKey(tester, 'auth-submit');
    expect(
      find.text('Recibimos tu mensaje. Te responderemos pronto.'),
      findsOneWidget,
    );
    expect(accounts.supportCases.single, startsWith('Código: No funcionó'));
  });

  testWidgets('eliminar la cuenta exige escribir ELIMINAR y cierra la sesión', (
    tester,
  ) async {
    final accounts = signedIn();
    final id = accounts.currentUser!.id;
    await tester.pumpAlPaso(
      config: demoServerConfig,
      server: accounts,
      initialLocation: '/perfil',
    );
    await tapKey(tester, 'profile-delete-account');

    await tester.enterText(find.byKey(const Key('delete-confirm')), 'borrar');
    await tapKey(tester, 'delete-submit');
    expect(find.text('Escribe ELIMINAR para confirmar'), findsWidgets);
    expect(accounts.deleted, isEmpty);

    await tester.enterText(find.byKey(const Key('delete-confirm')), 'eliminar');
    await tapKey(tester, 'delete-submit');
    expect(accounts.deleted, {id});
    expect(accounts.currentUser, isNull);
    expect(find.text('Tu cuenta fue eliminada.'), findsOneWidget);
  });

  testWidgets('con reservas activas no se elimina y lo explica', (
    tester,
  ) async {
    final accounts = signedIn()
      ..deleteFailure = AuthFailureReason.activeBookings;
    await tester.pumpAlPaso(
      config: demoServerConfig,
      server: accounts,
      initialLocation: '/eliminar-cuenta',
    );
    await tester.enterText(find.byKey(const Key('delete-confirm')), 'ELIMINAR');
    await tapKey(tester, 'delete-submit');
    expect(find.textContaining('Tienes reservas activas'), findsOneWidget);
    expect(accounts.currentUser, isNotNull);
  });

  testWidgets('ingresos: ventas, comisión, liquidaciones y cuenta de destino', (
    tester,
  ) async {
    final earnings = FakeEarningsServer();
    await tester.pumpAlPaso(
      config: demoServerConfig,
      server: signedIn(),
      earnings: earnings,
      initialLocation: '/negocio/hostal/l1/ingresos',
    );
    expect(find.text('Pendiente de liquidar (2 reservas)'), findsOneWidget);
    expect(find.text('S/ 90.00'), findsOneWidget);
    expect(find.text('-S/ 10.00'), findsOneWidget);
    expect(find.textContaining('operación OP-123'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('payout-holder')), 'Ana Pérez');
    await tester.enterText(find.byKey(const Key('payout-bank')), 'BCP');
    await tester.enterText(find.byKey(const Key('payout-cci')), '123');
    await tapKey(tester, 'payout-save');
    expect(find.text('El CCI tiene 20 dígitos.'), findsOneWidget);
    expect(earnings.accounts, isEmpty);

    await tester.enterText(
      find.byKey(const Key('payout-cci')),
      '002-193-001234567890-12',
    );
    await tapKey(tester, 'payout-save');
    expect(earnings.accounts['l1']!.bankName, 'BCP');
  });
}
