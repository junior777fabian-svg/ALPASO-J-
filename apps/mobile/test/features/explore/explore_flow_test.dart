import 'package:alpaso/features/explore/data/explore_repository.dart';
import 'package:alpaso/features/explore/presentation/explore_messages.dart';
import 'package:alpaso/features/lodging/presentation/public_lodging_screen.dart';
import 'package:alpaso/features/lodging/presentation/public_room_type_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_explore.dart';
import '../../support/pump_app.dart';

Future<FakeExploreServer> openExplore(
  WidgetTester tester, {
  FakeExploreServer? explore,
  FakeLocationService? location,
}) async {
  final server = explore ?? (FakeExploreServer()..seedLodging());
  await tester.pumpAlPaso(
    config: demoServerConfig,
    explore: server,
    location: location,
  );
  return server;
}

void main() {
  testWidgets('sin servidor, Explorar lo explica', (tester) async {
    await tester.pumpAlPaso();
    expect(find.text('Aquí verás los hostales cercanos'), findsOneWidget);
    expect(find.textContaining('no está conectada a un servidor'), findsOne);
  });

  testWidgets('sin cuenta, busca y muestra el hostal con su precio', (
    tester,
  ) async {
    final server = await openExplore(tester);

    expect(find.text('Hostal Sol'), findsOneWidget);
    expect(find.text('Miraflores · 850 m'), findsOneWidget);
    expect(find.text('Desde S/ 30.00 · 4 h'), findsOneWidget);
    expect(server.lastQuery!.blockHours, 4);
    expect(server.lastQuery!.arrival, isNull, reason: 'llegada: ahora');
    expect(find.text('Llegada: Ahora'), findsOneWidget);
  });

  testWidgets('cambiar la duración vuelve a buscar', (tester) async {
    final server = await openExplore(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, '12 h'));
    await tester.pumpAndSettle();

    expect(server.lastQuery!.blockHours, 12);
    expect(find.text('Desde S/ 30.00 · 12 h'), findsOneWidget);
  });

  testWidgets('sin resultados lo dice', (tester) async {
    await openExplore(tester, explore: FakeExploreServer());
    expect(find.text('No hay cuartos libres'), findsOneWidget);
  });

  testWidgets('un error ofrece reintentar', (tester) async {
    final server = FakeExploreServer()
      ..seedLodging()
      ..nextFailure = ExploreFailureReason.network;
    await openExplore(tester, explore: server);

    expect(find.textContaining('No hay conexión'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Hostal Sol'), findsOneWidget);
  });

  testWidgets('los filtros llegan a la búsqueda', (tester) async {
    final server = await openExplore(tester);
    await tester.tap(find.byKey(const Key('explore-filters')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('filter-max-price')), '25');
    await tester.tap(find.text('Jacuzzi').last); // El de la hoja de filtros.
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('filters-apply')));
    await tester.pumpAndSettle();

    expect(server.lastQuery!.maxPriceCents, 2500);
    expect(server.lastQuery!.needsJacuzzi, isTrue);
    expect(find.text('Filtros (2)'), findsOneWidget);
    expect(find.text('No hay cuartos libres'), findsOneWidget);
  });

  testWidgets('cerca de mí usa la ubicación del teléfono', (tester) async {
    final server = await openExplore(
      tester,
      location: FakeLocationService(const LatLng(-12.12, -77.03)),
    );
    await tester.tap(find.byTooltip('Cerca de mí'));
    await tester.pumpAndSettle();

    expect(server.lastQuery!.nearMe, isTrue);
    expect(server.lastQuery!.center, const LatLng(-12.12, -77.03));
    expect(server.lastQuery!.radiusMeters, 5000);
  });

  testWidgets('sin permiso de ubicación lo explica y no cambia la búsqueda', (
    tester,
  ) async {
    final server = await openExplore(tester, location: FakeLocationService());
    final before = server.queries.length;
    await tester.tap(find.byTooltip('Cerca de mí'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No pudimos obtener tu ubicación'), findsOne);
    expect(server.queries.length, before);
  });

  testWidgets('en el mapa, tocar un precio muestra el hostal', (tester) async {
    await openExplore(tester);
    await tester.tap(find.byTooltip('Ver mapa'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pin-l1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('pin-l1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('result-l1')), findsOneWidget);
  });

  testWidgets('la ficha muestra los cuartos con precio y disponibilidad', (
    tester,
  ) async {
    await openExplore(tester);
    await tester.tap(find.text('Hostal Sol'));
    await tester.pumpAndSettle();

    expect(find.byType(PublicLodgingScreen), findsOneWidget);
    expect(find.text('Av. Larco 123 · Miraflores'), findsOneWidget);
    expect(find.text('Cochera'), findsOneWidget);
    expect(find.text('Para 4 horas · Ahora'), findsOneWidget);
    expect(find.text('S/ 30.00'), findsOneWidget);
    expect(find.text('Ocupado a esa hora'), findsOneWidget);
  });

  testWidgets('el cuarto muestra fotos etiquetadas y sus precios', (
    tester,
  ) async {
    await openExplore(tester);
    await tester.tap(find.text('Hostal Sol'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Suite'));
    await tester.pumpAndSettle();

    expect(find.byType(PublicRoomTypeScreen), findsOneWidget);
    expect(
      find.text('Habitación · 1 de 2'),
      findsOneWidget,
      reason: 'primero la habitación',
    );
    expect(find.text('4 horas'), findsOneWidget);
    expect(find.text('S/ 60.00'), findsOneWidget);
    expect(find.text('Reservar'), findsOneWidget);
  });

  group('formatos', () {
    test('distancia', () {
      expect(formatDistance(350), '350 m');
      expect(formatDistance(2450), '2.5 km');
    });
  });
}
