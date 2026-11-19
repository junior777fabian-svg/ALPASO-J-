import 'package:alpaso/features/business/domain/business_failure.dart';
import 'package:alpaso/features/business/domain/lodging.dart';
import 'package:alpaso/features/business/presentation/business_home_screen.dart';
import 'package:alpaso/features/business/presentation/lodging_detail_screen.dart';
import 'package:alpaso/features/business/presentation/lodging_form_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_account.dart';
import '../../support/fake_business.dart';
import '../../support/pump_app.dart';

/// Cuenta con sesión y mayoría de edad confirmada.
FakeAccountServer signedIn({bool adult = true}) {
  final server = FakeAccountServer();
  server.currentUser = server.seed(
    email: 'ana@correo.pe',
    password: 'clave-segura',
    fullName: 'Ana',
    adult: adult,
  );
  return server;
}

Future<void> tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder.last);
  await tester.tap(finder.last);
  await tester.pumpAndSettle();
}

Future<void> tapSave(WidgetTester tester) async {
  // El formulario es una lista que construye solo lo visible: se desplaza
  // hasta el botón.
  final button = find.byKey(const Key('auth-submit'));
  await tester.scrollUntilVisible(
    button,
    300,
    scrollable: find
        .descendant(
          of: find.byKey(const Key('lodging-form')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> fillLodgingForm(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('lodging-name')), 'Hostal Luna');
  await tester.tap(find.byKey(const Key('lodging-district')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Miraflores').last);
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const Key('lodging-address')),
    'Calle Los Pinos 456',
  );
}

void main() {
  testWidgets('sin servidor el modo negocio lo explica', (tester) async {
    await tester.pumpAlPaso(initialLocation: '/negocio');
    expect(find.byType(BusinessHomeScreen), findsOneWidget);
    expect(find.textContaining('no está conectada a un servidor'), findsOne);
    expect(find.text('Volver al modo cliente'), findsOneWidget);
  });

  testWidgets('sin sesión pide iniciarla', (tester) async {
    await tester.pumpAlPaso(
      config: demoServerConfig,
      initialLocation: '/negocio',
    );
    expect(find.textContaining('Inicia sesión para registrar'), findsOne);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

  testWidgets('registra un hostal y lo ve en borrador', (tester) async {
    final accounts = signedIn();
    final business = FakeBusinessServer(accounts);
    await tester.pumpAlPaso(
      config: demoServerConfig,
      server: accounts,
      business: business,
      initialLocation: '/negocio',
    );

    expect(find.textContaining('Registra tu hostal'), findsOneWidget);
    await tapText(tester, 'Registrar mi hostal');
    expect(find.byType(LodgingFormScreen), findsOneWidget);

    await fillLodgingForm(tester);
    await tapSave(tester);

    expect(find.byType(LodgingDetailScreen), findsOneWidget);
    expect(find.text('Hostal Luna'), findsWidgets);
    expect(find.text('Borrador'), findsOneWidget);
    expect(find.text('Calle Los Pinos 456'), findsOneWidget);
    final created = business.lodgings.values.single;
    expect(created.draft.districtId, 21);
    expect(created.status, LodgingStatus.draft);
  });

  testWidgets('el formulario valida antes de llamar al servidor', (
    tester,
  ) async {
    final accounts = signedIn();
    final business = FakeBusinessServer(accounts);
    await tester.pumpAlPaso(
      config: demoServerConfig,
      server: accounts,
      business: business,
      initialLocation: '/negocio/hostal/nuevo',
    );

    await tester.enterText(find.byKey(const Key('lodging-name')), 'Ho');
    await tapSave(tester);
    // Vuelve arriba para leer los avisos de cada campo.
    await tester.drag(
      find.byKey(const Key('lodging-form')),
      const Offset(0, 3000),
    );
    await tester.pumpAndSettle();

    expect(find.text('Escribe entre 3 y 80 caracteres.'), findsOneWidget);
    expect(find.text('Elige el distrito.'), findsOneWidget);
    expect(find.text('Escribe entre 5 y 200 caracteres.'), findsOneWidget);
    expect(business.lodgings, isEmpty);
  });

  testWidgets('sin mayoría de edad confirmada lo explica', (tester) async {
    final accounts = signedIn(adult: false);
    await tester.pumpAlPaso(
      config: demoServerConfig,
      server: accounts,
      initialLocation: '/negocio/hostal/nuevo',
    );
    await fillLodgingForm(tester);
    await tapSave(tester);

    expect(
      find.textContaining('Confirma en tu perfil que eres mayor de edad'),
      findsOneWidget,
    );
  });

  testWidgets('enviar a revisión un hostal incompleto explica qué falta', (
    tester,
  ) async {
    final accounts = signedIn();
    final business = FakeBusinessServer(accounts);
    final lodging = business.seed(accounts.currentUser!.id);
    await tester.pumpAlPaso(
      config: demoServerConfig,
      server: accounts,
      business: business,
      initialLocation: '/negocio/hostal/${lodging.id}',
    );

    await tapText(tester, 'Enviar a revisión');
    expect(find.textContaining('agrega al menos un tipo de cuarto'), findsOne);
    expect(business.lodgings[lodging.id]!.status, LodgingStatus.draft);
  });

  testWidgets('un hostal completo se envía a revisión', (tester) async {
    final accounts = signedIn();
    final business = FakeBusinessServer(accounts);
    final lodging = business.seed(accounts.currentUser!.id);
    business.complete.add(lodging.id);
    await tester.pumpAlPaso(
      config: demoServerConfig,
      server: accounts,
      business: business,
      initialLocation: '/negocio/hostal/${lodging.id}',
    );

    await tapText(tester, 'Enviar a revisión');
    expect(find.text('En revisión'), findsOneWidget);
    expect(find.byKey(const Key('lodging-submit')), findsNothing);
    expect(business.lodgings[lodging.id]!.status, LodgingStatus.pendingReview);
  });

  testWidgets('un hostal rechazado muestra el motivo y se puede reenviar', (
    tester,
  ) async {
    final accounts = signedIn();
    final business = FakeBusinessServer(accounts);
    final seeded = business.seed(accounts.currentUser!.id);
    business.lodgings[seeded.id] = Lodging(
      id: seeded.id,
      draft: seeded.draft,
      districtName: 'Miraflores',
      status: LodgingStatus.rejected,
      reviewNote: 'Faltan fotos del baño',
    );
    await tester.pumpAlPaso(
      config: demoServerConfig,
      server: accounts,
      business: business,
      initialLocation: '/negocio/hostal/${seeded.id}',
    );

    expect(find.text('Rechazado'), findsOneWidget);
    expect(find.text('Motivo: Faltan fotos del baño'), findsOneWidget);
    expect(find.byKey(const Key('lodging-submit')), findsOneWidget);
  });

  testWidgets('edita los datos del hostal', (tester) async {
    final accounts = signedIn();
    final business = FakeBusinessServer(accounts);
    final lodging = business.seed(accounts.currentUser!.id);
    await tester.pumpAlPaso(
      config: demoServerConfig,
      server: accounts,
      business: business,
      initialLocation: '/negocio/hostal/${lodging.id}',
    );

    await tester.tap(find.byTooltip('Editar datos'));
    await tester.pumpAndSettle();
    expect(find.text('Av. Larco 123'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('lodging-address')),
      'Av. Larco 999',
    );
    await tapText(tester, 'Cochera');
    await tapSave(tester);

    expect(find.byType(LodgingDetailScreen), findsOneWidget);
    expect(find.text('Av. Larco 999'), findsOneWidget);
    expect(business.lodgings[lodging.id]!.draft.hasParking, isTrue);
  });

  testWidgets('la lista muestra los hostales con su estado', (tester) async {
    final accounts = signedIn();
    final business = FakeBusinessServer(accounts)
      ..seed('otra-cuenta', name: 'Hostal Ajeno');
    business.seed(accounts.currentUser!.id, name: 'Hostal Sol');
    business.seed(
      accounts.currentUser!.id,
      name: 'Hostal Mar',
      status: LodgingStatus.published,
    );
    await tester.pumpAlPaso(
      config: demoServerConfig,
      server: accounts,
      business: business,
      initialLocation: '/negocio',
    );

    expect(find.text('Hostal Sol'), findsOneWidget);
    expect(find.text('Hostal Mar'), findsOneWidget);
    expect(find.text('Publicado'), findsOneWidget);
    expect(find.text('Hostal Ajeno'), findsNothing);
  });

  testWidgets('si falla la carga ofrece reintentar', (tester) async {
    final accounts = signedIn();
    final business = FakeBusinessServer(accounts)
      ..nextFailure = BusinessFailureReason.network;
    await tester.pumpAlPaso(
      config: demoServerConfig,
      server: accounts,
      business: business,
      initialLocation: '/negocio',
    );

    expect(find.textContaining('No hay conexión'), findsOneWidget);
    await tapText(tester, 'Reintentar');
    expect(find.textContaining('Registra tu hostal'), findsOneWidget);
  });
}
