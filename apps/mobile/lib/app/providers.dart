import 'package:alpaso/app/env/app_config.dart';
import 'package:alpaso/app/router/app_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Configuración validada. `bootstrap` la entrega al arrancar; las pruebas la
/// reemplazan con la que necesiten.
final appConfigProvider = Provider<AppConfig>(
  (ref) => throw UnimplementedError('appConfigProvider se define al arrancar'),
);

final routerProvider = Provider<GoRouter>((ref) {
  final router = buildRouter();
  ref.onDispose(router.dispose);
  return router;
});
