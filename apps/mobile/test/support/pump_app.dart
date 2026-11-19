import 'package:alpaso/app/app.dart';
import 'package:alpaso/app/env/app_config.dart';
import 'package:alpaso/app/providers.dart';
import 'package:alpaso/features/auth/data/auth_providers.dart';
import 'package:alpaso/features/booking/data/booking_providers.dart';
import 'package:alpaso/features/business/data/business_providers.dart';
import 'package:alpaso/features/explore/data/explore_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_account.dart';
import 'fake_booking.dart';
import 'fake_earnings.dart';
import 'fake_business.dart';
import 'fake_explore.dart';
import 'fake_reception.dart';

const demoConfig = AppConfig(env: AppEnv.demo);

/// Demo con servidor. En las pruebas de pantalla el servidor es falso.
const demoServerConfig = AppConfig(
  env: AppEnv.demo,
  supabaseUrl: 'http://127.0.0.1:54321',
  supabasePublishableKey: 'llave-local',
);

const prodConfig = AppConfig(
  env: AppEnv.prod,
  supabaseUrl: 'https://ejemplo.supabase.co',
  supabasePublishableKey: 'llave',
);

extension PumpApp on WidgetTester {
  /// Abre la app completa con la configuración indicada.
  ///
  /// Ninguna prueba de pantalla habla con un servidor real: si la
  /// configuración tiene servidor y no se pasa [server], se usa uno falso
  /// vacío.
  Future<void> pumpAlPaso({
    AppConfig config = demoConfig,
    FakeAccountServer? server,
    FakeBusinessServer? business,
    FakePhotoPicker? picker,
    FakeExploreServer? explore,
    FakeBookingServer? booking,
    FakeReceptionServer? reception,
    FakeEarningsServer? earnings,
    FakeLocationService? location,
    String? initialLocation,
  }) async {
    if (config.hasServer) server ??= FakeAccountServer();
    if (server != null) business ??= FakeBusinessServer(server);
    await pumpWidget(
      ProviderScope(
        retry: (retryCount, error) => null,
        overrides: [
          appConfigProvider.overrideWithValue(config),
          if (server != null) ...[
            authRepositoryProvider.overrideWithValue(server.auth),
            profileRepositoryProvider.overrideWithValue(
              server.profileRepository,
            ),
            businessRepositoryProvider.overrideWithValue(business),
            exploreRepositoryProvider.overrideWithValue(
              explore ?? FakeExploreServer(),
            ),
            bookingRepositoryProvider.overrideWithValue(
              booking ?? FakeBookingServer(),
            ),
            receptionRepositoryProvider.overrideWithValue(
              reception ?? FakeReceptionServer(),
            ),
            earningsRepositoryProvider.overrideWithValue(
              earnings ?? FakeEarningsServer(),
            ),
          ],
          locationServiceProvider.overrideWithValue(
            location ?? FakeLocationService(),
          ),
          // Martes 19 de noviembre de 2026, 20:00 en Lima.
          clockProvider.overrideWithValue(() => DateTime(2026, 11, 19, 20)),
          mapTilesEnabledProvider.overrideWithValue(false),
          photoPickerProvider.overrideWithValue(picker ?? FakePhotoPicker()),
        ],
        child: const AlPasoApp(),
      ),
    );
    await pumpAndSettle();
    if (initialLocation != null) {
      ProviderScope.containerOf(element(find.byType(AlPasoApp)))
          .read(routerProvider)
          .go(initialLocation);
      await pumpAndSettle();
    }
  }
}
