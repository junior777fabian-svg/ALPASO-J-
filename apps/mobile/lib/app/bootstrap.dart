import 'package:alpaso/app/app.dart';
import 'package:alpaso/app/config_error_app.dart';
import 'package:alpaso/app/env/app_config.dart';
import 'package:alpaso/app/providers.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Arranca la app. Si la configuración es inválida muestra el motivo en vez
/// de abrir a medias.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  final AppConfig config;
  try {
    config = AppConfig.fromEnvironment();
  } on AppConfigException catch (error) {
    runApp(ConfigErrorApp(message: error.message));
    return;
  }

  // Con servidor, la sesión se guarda en el teléfono y se recupera al abrir.
  if (config.hasServer) {
    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.supabasePublishableKey,
    );
  }

  // Las pruebas de navegador necesitan el árbol de accesibilidad desde el
  // primer cuadro para encontrar botones y textos.
  if (const bool.fromEnvironment('FORCE_SEMANTICS')) {
    SemanticsBinding.instance.ensureSemantics();
  }

  runApp(
    ProviderScope(
      overrides: [appConfigProvider.overrideWithValue(config)],
      // Un error se muestra con un botón para reintentar; no se reintenta a
      // escondidas.
      retry: (retryCount, error) => null,
      child: const AlPasoApp(),
    ),
  );
}
