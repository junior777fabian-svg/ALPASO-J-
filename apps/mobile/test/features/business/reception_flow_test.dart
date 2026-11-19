import 'package:alpaso/features/business/domain/reception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_account.dart';
import '../../support/fake_business.dart';
import '../../support/fake_reception.dart';
import '../../support/pump_app.dart';

FakeAccountServer signedIn() {
  final accounts = FakeAccountServer();
  accounts.currentUser = accounts.seed(email: 'rosa@correo.pe', password: 'x');
  return accounts;
}

Future<FakeReceptionServer> openReception(WidgetTester tester) async {
  final reception = FakeReceptionServer()..seedDay();
  await tester.pumpAlPaso(
    config: demoServerConfig,
    server: signedIn(),
    reception: reception,
    initialLocation: '/negocio/hostal/l1/hoy',
  );
  return reception;
}

Future<void> reveal(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: find.byType(Scrollable).hitTestable().first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> tapFinder(WidgetTester tester, Finder finder) async {
  await reveal(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('el tablero muestra llegadas, extras y cuartos', (tester) async {
    await openReception(tester);
    expect(find.text('Carla · K7X9QA'), findsOneWidget);
    expect(find.text('2 × Agua'), findsOneWidget);
    await reveal(tester, find.text('En limpieza'));
    expect(find.text('En limpieza'), findsOneWidget);
  });

  testWidgets('el ingreso con el código del QR funciona una sola vez', (
    tester,
  ) async {
    final reception = await openReception(tester);
    await tester.enterText(
      find.byKey(const Key('checkin-code')),
      ' alpaso:k7x9qa ',
    );
    await tester.tap(find.byKey(const Key('checkin-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Ingresó Carla: cuarto 101.'), findsOneWidget);
    expect(reception.inHouse, hasLength(1));

    await tester.enterText(find.byKey(const Key('checkin-code')), 'K7X9QA');
    await tester.tap(find.byKey(const Key('checkin-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Ese código ya se usó.'), findsOneWidget);
  });

  testWidgets('un código de otro hostal no sirve', (tester) async {
    await openReception(tester);
    await tester.enterText(find.byKey(const Key('checkin-code')), 'ZZZZZZ');
    await tester.tap(find.byKey(const Key('checkin-submit')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('no corresponde a una reserva de este hostal'),
      findsOne,
    );
  });

  testWidgets('el extra que falta se reembolsa', (tester) async {
    final reception = await openReception(tester);
    await tapFinder(tester, find.byKey(const Key('item-missing-i1')));
    expect(find.text('Se reembolsaron S/ 6.00 al cliente.'), findsOneWidget);
    expect(reception.calls, contains('item:i1:unavailable'));
    expect(find.text('No disponible (reembolsado)'), findsOneWidget);
  });

  testWidgets('salida, limpieza, cliente directo y liberar', (tester) async {
    final reception = await openReception(tester);
    await tester.enterText(find.byKey(const Key('checkin-code')), 'K7X9QA');
    await tester.tap(find.byKey(const Key('checkin-submit')));
    await tester.pumpAndSettle();

    await tapFinder(tester, find.byKey(const Key('checkout-b1')));
    expect(reception.calls, contains('checkout:b1'));
    expect(reception.rooms['r101']!.state, RoomState.cleaning);

    await tapFinder(
      tester,
      find.descendant(
        of: find.byKey(const Key('room-103')),
        matching: find.text('Marcar limpio'),
      ),
    );
    expect(reception.rooms['r103']!.state, RoomState.free);

    await tapFinder(
      tester,
      find.descendant(
        of: find.byKey(const Key('room-102')),
        matching: find.text('Ocupar'),
      ),
    );
    await tester.tap(find.widgetWithText(ActionChip, '3 h'));
    await tester.pumpAndSettle();
    expect(reception.calls, contains('block:r102:walk_in:180'));

    await tapFinder(
      tester,
      find.descendant(
        of: find.byKey(const Key('room-102')),
        matching: find.text('Liberar'),
      ),
    );
    expect(reception.rooms['r102']!.state, RoomState.free);
  });

  testWidgets('el dueño invita personal y ve el código', (tester) async {
    await tester.pumpAlPaso(
      config: demoServerConfig,
      server: signedIn(),
      initialLocation: '/negocio/hostal/l1/personal',
    );
    expect(find.text('Dueño'), findsOneWidget);
    await tester.tap(find.byKey(const Key('staff-invite')));
    await tester.pumpAndSettle();
    expect(find.text('QWER7934'), findsOneWidget);
  });

  testWidgets('una cuenta se une como recepcionista con el código', (
    tester,
  ) async {
    final accounts = signedIn();
    await tester.pumpAlPaso(
      config: demoServerConfig,
      server: accounts,
      business: FakeBusinessServer(accounts),
      initialLocation: '/negocio',
    );
    await tapFinder(tester, find.byKey(const Key('join-lodging')));
    await tester.enterText(find.byKey(const Key('join-code')), 'abcd2345');
    await tester.tap(find.byKey(const Key('join-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Ya eres recepcionista de Hostal Sol.'), findsOneWidget);

    await tapFinder(tester, find.byKey(const Key('join-lodging')));
    await tester.enterText(find.byKey(const Key('join-code')), 'abcd2345');
    await tester.tap(find.byKey(const Key('join-submit')));
    await tester.pumpAndSettle();
    expect(find.textContaining('no es válido o ya venció'), findsOneWidget);
  });

  testWidgets('el dueño cancela una reserva con motivo', (tester) async {
    final reception = FakeReceptionServer();
    reception.hostBookings.add(
      HostBooking(
        id: 'hb1',
        code: 'K7X9QA',
        status: 'confirmed',
        roomTypeName: 'Suite',
        arrival: DateTime(2026, 11, 20, 18),
        blockHours: 4,
        totalCents: 4500,
      ),
    );
    await tester.pumpAlPaso(
      config: demoServerConfig,
      server: signedIn(),
      reception: reception,
      initialLocation: '/negocio/hostal/l1/reservas',
    );
    await tester.tap(find.byTooltip('Cancelar reserva'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('host-cancel-reason')),
      'Inundación',
    );
    await tester.tap(find.byKey(const Key('host-cancel-confirm')));
    await tester.pumpAndSettle();

    expect(
      find.text('Reserva cancelada. Se reembolsaron S/ 45.00 al cliente.'),
      findsOne,
    );
    expect(reception.calls, contains('cancel:hb1:Inundación'));
  });
}
