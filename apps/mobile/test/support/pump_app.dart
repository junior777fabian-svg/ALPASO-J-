import 'package:alpaso/app/app.dart';
import 'package:alpaso/app/env/app_config.dart';
import 'package:alpaso/app/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const demoConfig = AppConfig(env: AppEnv.demo);

const prodConfig = AppConfig(
  env: AppEnv.prod,
  supabaseUrl: 'https://ejemplo.supabase.co',
  supabasePublishableKey: 'llave',
);

extension PumpApp on WidgetTester {
  /// Abre la app completa con la configuración indicada.
  Future<void> pumpAlPaso({AppConfig config = demoConfig}) async {
    await pumpWidget(
      ProviderScope(
        overrides: [appConfigProvider.overrideWithValue(config)],
        child: const AlPasoApp(),
      ),
    );
    await pumpAndSettle();
  }
}
