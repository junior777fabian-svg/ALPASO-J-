import 'package:alpaso/app/providers.dart';
import 'package:alpaso/app/theme/app_theme.dart';
import 'package:alpaso/design/widgets/demo_banner.dart';
import 'package:alpaso/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class AlPasoApp extends ConsumerWidget {
  const AlPasoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      locale: const Locale('es'),
      supportedLocales: AppLocalizations.supportedLocales,
      // Desde Flutter 3.50 los textos de Material en español vienen de
      // material_ui. La lista que genera gen-l10n todavía apunta a las clases
      // anteriores, por eso no se usa AppLocalizations.localizationsDelegates.
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      routerConfig: router,
      builder: (context, child) {
        final content = child ?? const SizedBox.shrink();
        // El rótulo va por encima de todas las pantallas: en demo no hay
        // forma de navegar a un lugar donde no se vea.
        return config.isDemo ? DemoBanner(child: content) : content;
      },
    );
  }
}
