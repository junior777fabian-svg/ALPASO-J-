import 'package:alpaso/features/booking/data/booking_repository.dart';
import 'package:alpaso/features/booking/domain/booking.dart';
import 'package:alpaso/features/booking/domain/booking_failure.dart';
import 'package:alpaso/features/booking/presentation/booking_screen.dart';
import 'package:alpaso/features/booking/presentation/demo_checkout_screen.dart';
import 'package:alpaso/features/my_bookings/presentation/booking_detail_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_account.dart';
import '../../support/fake_booking.dart';
import '../../support/fake_explore.dart';
import '../../support/pump_app.dart';

final now = DateTime(2026, 11, 19, 20);

FakeAccountServer signedIn() {
  final accounts = FakeAccountServer();
  accounts.currentUser = accounts.seed(
    email: 'cli@correo.pe',
    password: 'clave-segura',
  );
  return accounts;
}

Future<FakeBookingServer> openBooking(
  WidgetTester tester, {
  FakeAccountServer? accounts,
  FakeBookingServer? booking,
}) async {
  final server = booking ?? FakeBookingServer();
  server.menus['l1'] = const [
    MenuItem(
      productId: 'gaseosa',
      name: 'Gaseosa',
      priceCents: 400,
      category: 'drinks',
    ),
  ];
  await tester.pumpAlPaso(
    config: demoServerConfig,
    server: accounts ?? signedIn(),
    explore: FakeExploreServer()..seedLodging(priceCents: 4500),
    booking: server,
    initialLocation: '/reservar/l1/l1-suite',
  );
  return server;
}

/// Desplaza la pantalla hasta [finder] si todavía no está construido.
Future<void> reveal(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: find.byType(Scrollable).hitTestable().first,
    );
  }
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await reveal(tester, finder);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sin sesión pide iniciarla antes de reservar', (tester) async {
    await openBooking(tester, accounts: FakeAccountServer());
    expect(find.text('Inicia sesión para reservar'), findsOneWidget);
  });

  testWidgets('desde la ficha del cuarto se llega a reservar', (tester) async {
    await tester.pumpAlPaso(
      config: demoServerConfig,
      server: signedIn(),
      explore: FakeExploreServer()..seedLodging(),
      initialLocation: '/hostal/l1/cuarto/l1-suite',
    );
    await tapKey(tester, 'room-book');
    expect(find.byType(BookingScreen), findsOneWidget);
  });

  testWidgets('reserva con extras, paga en demo y ve su código', (
    tester,
  ) async {
    final server = await openBooking(tester);

    expect(find.text('S/ 45.00'), findsWidgets);
    await tester.tap(find.byTooltip('Agregar Gaseosa'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Agregar Gaseosa'));
    await tester.pumpAndSettle();
    expect(find.text('2 × Gaseosa'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('booking-total')),
        matching: find.text('S/ 53.00'),
      ),
      findsOneWidget,
      reason: 'el total lo da el servidor',
    );

    await tapKey(tester, 'auth-submit');
    expect(find.byType(PaymentScreen), findsOneWidget);
    expect(find.byKey(const Key('demo-gateway-label')), findsOneWidget);
    expect(
      find.text('PASARELA DEMO · No se cobra dinero real'),
      findsOneWidget,
    );
    expect(find.text('S/ 53.00'), findsOneWidget);

    await tapKey(tester, 'demo-approve');
    expect(find.byType(BookingDetailScreen), findsOneWidget);
    expect(find.text('Confirmada'), findsOneWidget);
    expect(find.byKey(const Key('booking-code')), findsOneWidget);
    expect(find.text('K7X9QA'), findsOneWidget);
    expect(server.bookings.values.single.status, BookingStatus.confirmed);
  });

  testWidgets('un pago rechazado se puede reintentar', (tester) async {
    final server = await openBooking(tester);
    await tapKey(tester, 'auth-submit');
    await tapKey(tester, 'demo-reject');

    expect(find.textContaining('El pago fue rechazado'), findsOneWidget);
    expect(find.byKey(const Key('demo-approve')), findsNothing);
    await tester.tap(find.text('Intentar otra vez'));
    await tester.pumpAndSettle();
    await tapKey(tester, 'demo-approve');
    expect(find.text('Confirmada'), findsOneWidget);
    expect(server.payments, hasLength(2), reason: 'un cobro nuevo');
  });

  testWidgets('si el cuarto ya no está libre lo explica', (tester) async {
    final server = FakeBookingServer()
      ..nextFailure = BookingFailureReason.noRoomAvailable;
    await openBooking(tester, booking: server);
    await tapKey(tester, 'auth-submit');

    expect(find.textContaining('ya no está libre a esa hora'), findsOneWidget);
    expect(find.byType(BookingScreen), findsOneWidget);
  });

  testWidgets('reintentar tras un error usa la misma clave', (tester) async {
    final server = FakeBookingServer()
      ..nextFailure = BookingFailureReason.network;
    await openBooking(tester, booking: server);
    await tapKey(tester, 'auth-submit');
    await tapKey(tester, 'auth-submit');

    expect(server.idempotencyKeys, hasLength(1));
    expect(find.byType(PaymentScreen), findsOneWidget);
  });

  testWidgets('mis reservas muestra activas e historial', (tester) async {
    final server = FakeBookingServer()
      ..seed(status: BookingStatus.cancelled, lodgingName: 'Hostal Viejo')
      ..seed(lodgingName: 'Hostal Sol');
    await tester.pumpAlPaso(
      config: demoServerConfig,
      server: signedIn(),
      booking: server,
      initialLocation: '/reservas',
    );

    expect(find.text('Activas'), findsOneWidget);
    expect(find.text('Historial'), findsOneWidget);
    expect(find.text('Hostal Sol'), findsOneWidget);
    expect(find.text('K7X9QA'), findsOneWidget);
    expect(find.text('Hostal Viejo'), findsOneWidget);
  });

  testWidgets('cancelar a tiempo reembolsa todo', (tester) async {
    final server = FakeBookingServer();
    final b = server.seed();
    await tester.pumpAlPaso(
      config: demoServerConfig,
      server: signedIn(),
      booking: server,
      initialLocation: '/reservas/${b.id}',
    );

    await tapKey(tester, 'booking-cancel');
    expect(find.text('Te devolvemos S/ 45.00 completos.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('cancel-confirm')));
    await tester.pumpAndSettle();

    expect(
      find.text('Reserva cancelada. Te devolvimos S/ 45.00.'),
      findsOneWidget,
    );
    expect(find.text('Cancelada'), findsOneWidget);
    expect(server.bookings[b.id]!.status, BookingStatus.cancelled);
  });

  testWidgets('fuera de plazo no ofrece cancelar', (tester) async {
    final server = FakeBookingServer();
    final b = server.seed(
      arrival: now.add(const Duration(minutes: 30)),
      paidAt: now.subtract(const Duration(minutes: 20)),
    );
    await tester.pumpAlPaso(
      config: demoServerConfig,
      server: signedIn(),
      booking: server,
      initialLocation: '/reservas/${b.id}',
    );

    final help = find.textContaining('Ya pasó el plazo para cancelar');
    await reveal(tester, help);
    expect(help, findsOneWidget);
    expect(find.byKey(const Key('booking-cancel')), findsNothing);
  });

  group('reglas de cancelación en la app, iguales al servidor', () {
    Booking booking(DateTime arrival, DateTime? paidAt) => Booking(
      id: 'b',
      code: 'AAAAAA',
      status: BookingStatus.confirmed,
      lodgingId: 'l',
      lodgingName: '',
      address: '',
      location: const LatLng(0, 0),
      roomTypeName: '',
      blockHours: 4,
      arrival: arrival,
      departure: arrival.add(const Duration(hours: 4)),
      totalCents: 100,
      paidAt: paidAt,
    );

    test('hasta 1 hora antes, sí', () {
      expect(
        booking(
          now.add(const Duration(hours: 1)),
          now.subtract(const Duration(days: 1)),
        ).canCancelWithRefund(now),
        isTrue,
      );
    });

    test('a menos de 1 hora, no', () {
      expect(
        booking(
          now.add(const Duration(minutes: 59)),
          now.subtract(const Duration(days: 1)),
        ).canCancelWithRefund(now),
        isFalse,
      );
    });

    test('reserva inmediata: 5 minutos de gracia desde el pago', () {
      final arrival = now.add(const Duration(minutes: 30));
      expect(
        booking(
          arrival,
          now.subtract(const Duration(minutes: 4)),
        ).canCancelWithRefund(now),
        isTrue,
      );
      expect(
        booking(
          arrival,
          now.subtract(const Duration(minutes: 6)),
        ).canCancelWithRefund(now),
        isFalse,
      );
    });
  });

  test('la clave de reintento es un uuid v4', () {
    final key = newIdempotencyKey();
    expect(
      RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      ).hasMatch(key),
      isTrue,
    );
    expect(newIdempotencyKey(), isNot(key));
  });
}
