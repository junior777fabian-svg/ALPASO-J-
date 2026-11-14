import 'package:alpaso/app/app.dart';
import 'package:alpaso/app/config_error_app.dart';
import 'package:alpaso/app/env/app_config.dart';
import 'package:alpaso/app/providers.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Arranca la app. Si la configuración es inválida muestra el motivo en vez
/// de abrir a medias.
void bootstrap() {
  WidgetsFlutterBinding.ensureInitialized();

  final AppConfig config;
  try {
    config = AppConfig.fromEnvironment();
  } on AppConfigException catch (error) {
    runApp(ConfigErrorApp(message: error.message));
    return;
  }

  // Las pruebas de navegador necesitan el árbol de accesibilidad desde el
  // primer cuadro para encontrar botones y textos.
  if (const bool.fromEnvironment('FORCE_SEMANTICS')) {
    SemanticsBinding.instance.ensureSemantics();
  }

  runApp(
    ProviderScope(
      overrides: [appConfigProvider.overrideWithValue(config)],
      child: const AlPasoApp(),
    ),
  );
}
