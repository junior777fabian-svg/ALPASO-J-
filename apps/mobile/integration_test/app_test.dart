// Recorrido que se ejecuta en un teléfono o emulador real:
//
//   flutter test integration_test -d <id-del-dispositivo>
//
// Comprueba que la app compilada abre y que la navegación responde.

import 'package:alpaso/app/app.dart';
import 'package:alpaso/app/env/app_config.dart';
import 'package:alpaso/app/providers.dart';
import 'package:alpaso/design/widgets/demo_banner.dart';
import 'package:alpaso/features/business/presentation/business_home_screen.dart';
import 'package:alpaso/features/explore/presentation/explore_screen.dart';
import 'package:alpaso/features/my_bookings/presentation/my_bookings_screen.dart';
import 'package:alpaso/features/profile/presentation/profile_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';

Finder tab(String label) => find.widgetWithText(NavigationDestination, label);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('abre en demo y recorre las pestañas y el modo negocio', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(env: AppEnv.demo),
          ),
        ],
        child: const AlPasoApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ExploreScreen), findsOneWidget);
    expect(find.byType(DemoBanner), findsOneWidget);

    await tester.tap(tab('Reservas'));
    await tester.pumpAndSettle();
    expect(find.byType(MyBookingsScreen), findsOneWidget);

    await tester.tap(tab('Perfil'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);

    await tester.tap(find.text('Ir al modo negocio'));
    await tester.pumpAndSettle();
    expect(find.byType(BusinessHomeScreen), findsOneWidget);

    await tester.tap(find.text('Volver al modo cliente'));
    await tester.pumpAndSettle();
    expect(find.byType(ExploreScreen), findsOneWidget);
  });
}
