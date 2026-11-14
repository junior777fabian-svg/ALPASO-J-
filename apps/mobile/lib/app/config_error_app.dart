import 'package:alpaso/app/theme/app_spacing.dart';
import 'package:alpaso/app/theme/app_theme.dart';
import 'package:material_ui/material_ui.dart';

/// Pantalla única que se muestra cuando la configuración es inválida.
///
/// No usa los textos traducidos ni las rutas: tiene que poder mostrarse aunque
/// el resto de la app no pueda arrancar.
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Builder(
                builder: (context) {
                  final theme = Theme.of(context);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 56,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'La app no puede iniciar',
                        style: theme.textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        message,
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
