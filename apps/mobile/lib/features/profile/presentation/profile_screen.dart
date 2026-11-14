import 'package:alpaso/app/providers.dart';
import 'package:alpaso/app/router/app_router.dart';
import 'package:alpaso/app/theme/app_spacing.dart';
import 'package:alpaso/design/widgets/empty_state.dart';
import 'package:alpaso/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// C7. Por ahora muestra con qué configuración corre la app y da paso al modo
/// negocio. La cuenta llega en la parte 1B.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final config = ref.watch(appConfigProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileTitle)),
      body: Column(
        children: [
          Expanded(
            child: EmptyState(
              icon: Icons.person_outline,
              title: l10n.profileEmptyTitle,
              body: l10n.profileEmptyBody,
              action: OutlinedButton(
                onPressed: () => context.go(AppRoutes.business),
                child: Text(l10n.profileBusinessModeAction),
              ),
            ),
          ),
          // Dato de diagnóstico para quien prueba la demo. Un cliente real no
          // tiene por qué verlo, así que en producción no se muestra.
          if (config.isDemo)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                [
                  l10n.profileEnvironmentDemo,
                  if (config.hasServer)
                    l10n.profileServerConfigured
                  else
                    l10n.profileServerNotConfigured,
                ].join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}
