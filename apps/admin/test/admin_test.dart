import 'package:alpaso_admin/admin_app.dart';
import 'package:alpaso_admin/admin_repository.dart';
import 'package:alpaso_admin/ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class FakeAdmin implements AdminRepository {
  bool admin = true;
  bool signedIn = false;
  final calls = <String>[];
  final pending = <Json>[
    {
      'id': 'l1',
      'name': 'Hostal Sol',
      'address': 'Av. Larco 1',
      'districts': {'name': 'Miraflores'},
    },
  ];

  @override
  Future<void> signIn(String email, String password) async {
    if (password != 'clave') throw const AdminFailure('invalid_credentials');
    signedIn = true;
  }

  @override
  Future<void> signOut() async => signedIn = false;

  @override
  bool get isSignedIn => signedIn;

  @override
  Future<Json> overview() async {
    if (!admin) throw const AdminFailure('not_admin');
    return {'lodgings_pending_review': pending.length, 'support_open': 1};
  }

  @override
  Future<List<Json>> lodgings(String status) async =>
      status == 'pending_review' ? List.of(pending) : [];

  @override
  Future<void> reviewLodging(
    String id, {
    required bool approve,
    String note = '',
  }) async {
    calls.add('review:$id:$approve:$note');
    pending.removeWhere((l) => l['id'] == id);
  }

  @override
  Future<void> setLodgingSuspended(
    String id, {
    required bool suspended,
    required String reason,
  }) async {}

  @override
  Future<List<Json>> findUsers(String query) async => [
    {
      'user_id': 'u1',
      'email': 'carla@example.test',
      'full_name': 'Carla',
      'is_blocked': calls.contains('block:u1'),
      'is_admin': false,
    },
  ];

  @override
  Future<void> setBlocked(
    String userId, {
    required bool blocked,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) throw const AdminFailure('reason_required');
    calls.add('block:$userId');
  }

  @override
  Future<Json> findBooking(String code) async {
    if (code.toUpperCase() != 'K7X9QA') {
      throw const AdminFailure('booking_not_found');
    }
    return {
      'booking_id': 'b1',
      'code': 'K7X9QA',
      'status': 'completed',
      'lodging_name': 'Hostal Sol',
      'customer_name': 'Carla',
      'customer_email': 'carla@example.test',
      'arrival_at': '2026-11-19T20:00:00Z',
      'total_cents': 4500,
      'paid_out': false,
      'refunded_cents': 0,
      'events': <Json>[],
    };
  }

  @override
  Future<int> refundBooking(
    String bookingId,
    int amountCents,
    String reason,
  ) async {
    calls.add('refund:$bookingId:$amountCents:$reason');
    return amountCents;
  }

  @override
  Future<List<Json>> pendingPayouts() async => [
    {
      'lodging_id': 'l1',
      'lodging_name': 'Hostal Sol',
      'bookings_count': 2,
      'gross_cents': 9000,
      'has_payout_account': true,
    },
  ];

  @override
  Future<List<Json>> payouts() async => [];

  @override
  Future<Json> createPayout(String lodgingId) async {
    calls.add('payout:$lodgingId');
    return {'net_cents': 8100};
  }

  @override
  Future<void> markPayoutPaid(String payoutId, String reference) async {}

  @override
  Future<List<Json>> supportCases() async => [
    {
      'id': 's1',
      'subject': 'Código',
      'message': 'No funcionó',
      'status': 'open',
    },
  ];

  @override
  Future<void> resolveSupportCase(String id, String resolution) async =>
      calls.add('resolve:$id');

  @override
  Future<List<Json>> complaints() async => [];

  @override
  Future<void> answerComplaint(String number, String answer) async {}

  @override
  Future<Json> publicSettings() async => {'payments_provider': 'demo'};
}

Future<void> signIn(
  WidgetTester tester,
  FakeAdmin repo, {
  String password = 'clave',
}) async {
  await tester.pumpWidget(AdminApp(repository: repo));
  await tester.enterText(
    find.byKey(const Key('admin-email')),
    'admin@example.test',
  );
  await tester.enterText(find.byKey(const Key('admin-password')), password);
  await tester.tap(find.byKey(const Key('admin-submit')));
  await tester.pumpAndSettle();
}

Future<void> go(WidgetTester tester, String section) async {
  await tester.tap(find.text(section).first);
  await tester.pumpAndSettle();
}

Future<void> answer(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField).last, text);
  await tester.tap(find.byKey(const Key('ask-confirm')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    // Pantalla de escritorio para el panel.
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('una cuenta que no es admin no entra, y se cierra su sesión', (
    tester,
  ) async {
    final repo = FakeAdmin()..admin = false;
    await signIn(tester, repo);
    expect(find.text('Esta cuenta no es administradora.'), findsOneWidget);
    expect(repo.signedIn, isFalse);
  });

  testWidgets('clave equivocada', (tester) async {
    await signIn(tester, FakeAdmin(), password: 'mala');
    expect(find.text('Correo o contraseña incorrectos.'), findsOneWidget);
  });

  testWidgets('el admin ve el resumen y aprueba un hostal', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeAdmin();
    await signIn(tester, repo);
    expect(
      find.byKey(const Key('overview-lodgings_pending_review')),
      findsOneWidget,
    );
    expect(
      find.text('DEMO'),
      findsNothing,
      reason: 'el rótulo es un Banner, no texto',
    );

    await go(tester, 'Hostales');
    expect(find.text('Hostal Sol'), findsOneWidget);
    await tester.tap(find.text('Aprobar'));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('review:l1:true:'));
    expect(find.text('Hostal publicado.'), findsOneWidget);
  });

  testWidgets('bloquea una cuenta con motivo', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeAdmin();
    await signIn(tester, repo);
    await go(tester, 'Cuentas');
    await tester.enterText(find.byKey(const Key('users-query')), 'carla');
    await tester.tap(find.byTooltip('Buscar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bloquear'));
    await tester.pumpAndSettle();
    await answer(tester, 'Fraude');
    expect(repo.calls, contains('block:u1'));
    expect(find.text('Desbloquear'), findsOneWidget);
  });

  testWidgets('busca una reserva y reembolsa una parte', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeAdmin();
    await signIn(tester, repo);
    await go(tester, 'Reservas');
    await tester.enterText(find.byKey(const Key('booking-query')), 'k7x9qa');
    await tester.tap(find.byTooltip('Buscar reserva'));
    await tester.pumpAndSettle();
    expect(find.text('K7X9QA · completed'), findsOneWidget);
    await tester.tap(find.text('Reembolsar'));
    await tester.pumpAndSettle();
    await answer(tester, '10,50');
    await answer(tester, 'Sin agua caliente');
    expect(repo.calls, contains('refund:b1:1050:Sin agua caliente'));
    expect(find.text('Se reembolsaron S/ 10.50.'), findsOneWidget);
  });

  testWidgets('liquida un hostal y resuelve una incidencia', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeAdmin();
    await signIn(tester, repo);
    await go(tester, 'Liquidaciones');
    await tester.tap(find.text('Liquidar'));
    await tester.pumpAndSettle();
    expect(
      find.text('Liquidación creada: S/ 81.00 para el hostal.'),
      findsOneWidget,
    );

    await go(tester, 'Soporte');
    await tester.tap(find.text('Resolver'));
    await tester.pumpAndSettle();
    await answer(tester, 'Se validó a mano.');
    expect(repo.calls, contains('resolve:s1'));
  });

  test('formatos de soles', () {
    expect(soles(123456), 'S/ 1,234.56');
    expect(soles(-500), '-S/ 5.00');
    expect(parseSoles('45,5'), 4550);
    expect(parseSoles('abc'), isNull);
  });
}
