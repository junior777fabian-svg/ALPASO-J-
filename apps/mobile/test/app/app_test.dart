import 'package:alpaso/design/widgets/demo_banner.dart';
import 'package:alpaso/features/business/presentation/business_home_screen.dart';
import 'package:alpaso/features/explore/presentation/explore_screen.dart';
import 'package:alpaso/features/my_bookings/presentation/my_bookings_screen.dart';
import 'package:alpaso/features/profile/presentation/profile_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../support/pump_app.dart';

Finder tab(String label) => find.widgetWithText(NavigationDestination, label);

void main() {
  group('rótulo DEMO', () {
    testWidgets('se muestra en el entorno demo', (tester) async {
      await tester.pumpAlPaso(config: demoConfig);

      expect(find.byType(DemoBanner), findsOneWidget);
      final banner = tester.widget<Banner>(find.byType(Banner));
      expect(banner.message, 'DEMO');
    });

    testWidgets('sigue visible al cambiar de pantalla y de modo', (
      tester,
    ) async {
      await tester.pumpAlPaso(config: demoConfig);

      await tester.tap(tab('Perfil'));
      await tester.pumpAndSettle();
      expect(find.byType(DemoBanner), findsOneWidget);

      await tester.tap(find.text('Ir al modo negocio'));
      await tester.pumpAndSettle();
      expect(find.byType(BusinessHomeScreen), findsOneWidget);
      expect(find.byType(DemoBanner), findsOneWidget);
    });

    testWidgets('no aparece en producción', (tester) async {
      await tester.pumpAlPaso(config: prodConfig);

      expect(find.byType(DemoBanner), findsNothing);
      expect(find.byType(Banner), findsNothing);
    });

    testWidgets('no tapa la barra de estado del teléfono', (tester) async {
      // Un teléfono cuya barra de estado (hora, señal, batería) mide 40 px.
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 40);
      tester.view.viewPadding = const FakeViewPadding(top: 40);
      addTearDown(tester.view.reset);

      await tester.pumpAlPaso(config: demoConfig);

      expect(tester.getTopLeft(find.byType(Banner)).dy, 40);
    });
  });

  group('navegación del modo cliente', () {
    testWidgets('abre en Explorar con las tres pestañas', (tester) async {
      await tester.pumpAlPaso();

      expect(find.byType(ExploreScreen), findsOneWidget);
      expect(tab('Explorar'), findsOneWidget);
      expect(tab('Reservas'), findsOneWidget);
      expect(tab('Perfil'), findsOneWidget);
    });

    testWidgets('cada pestaña lleva a su pantalla', (tester) async {
      await tester.pumpAlPaso();

      await tester.tap(tab('Reservas'));
      await tester.pumpAndSettle();
      expect(find.byType(MyBookingsScreen), findsOneWidget);
      expect(find.text('Aún no tienes reservas'), findsOneWidget);

      await tester.tap(tab('Perfil'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);

      await tester.tap(tab('Explorar'));
      await tester.pumpAndSettle();
      expect(find.text('Aquí verás los hostales cercanos'), findsOneWidget);
    });
  });

  group('modo negocio', () {
    testWidgets('se entra desde Perfil y se vuelve al modo cliente', (
      tester,
    ) async {
      await tester.pumpAlPaso();

      await tester.tap(tab('Perfil'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ir al modo negocio'));
      await tester.pumpAndSettle();

      expect(find.byType(BusinessHomeScreen), findsOneWidget);
      // El modo negocio no comparte la barra de pestañas del cliente.
      expect(find.byType(NavigationBar), findsNothing);

      await tester.tap(find.text('Volver al modo cliente'));
      await tester.pumpAndSettle();
      expect(find.byType(ExploreScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
    });
  });

  group('perfil', () {
    testWidgets('en demo dice con qué entorno y servidor corre la app', (
      tester,
    ) async {
      await tester.pumpAlPaso(config: demoConfig);
      await tester.tap(tab('Perfil'));
      await tester.pumpAndSettle();

      expect(
        find.text('Entorno: demo · Sin servidor configurado'),
        findsOneWidget,
      );
    });

    testWidgets('en producción no muestra datos de diagnóstico', (
      tester,
    ) async {
      await tester.pumpAlPaso(config: prodConfig);
      await tester.tap(tab('Perfil'));
      await tester.pumpAndSettle();

      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.textContaining('Entorno'), findsNothing);
      expect(find.textContaining('ervidor'), findsNothing);
    });
  });

  group('pantallas pequeñas y letra grande', () {
    testWidgets('no se desborda en un teléfono chico con letra al 200 %', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);

      await tester.pumpAlPaso();
      for (final label in ['Reservas', 'Perfil', 'Explorar']) {
        await tester.tap(tab(label));
        await tester.pumpAndSettle();
      }

      // Un desborde habría quedado registrado como excepción de Flutter.
      expect(tester.takeException(), isNull);
    });
  });
}
