import 'package:alpaso/app/app.dart';
import 'package:alpaso/app/env/app_config.dart';
import 'package:alpaso/app/providers.dart';
import 'package:alpaso/features/auth/data/auth_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_account.dart';

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
  }) async {
    if (config.hasServer) server ??= FakeAccountServer();
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
          ],
        ],
        child: const AlPasoApp(),
      ),
    );
    await pumpAndSettle();
  }
}
