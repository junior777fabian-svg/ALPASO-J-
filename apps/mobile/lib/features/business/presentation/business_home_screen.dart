import 'package:alpaso/app/router/app_router.dart';
import 'package:alpaso/design/widgets/empty_state.dart';
import 'package:alpaso/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Entrada al modo negocio. Por ahora solo el marco; los módulos N1 a N7
/// llegan desde la etapa 2.
class BusinessHomeScreen extends StatelessWidget {
  const BusinessHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.businessTitle)),
      body: EmptyState(
        icon: Icons.storefront_outlined,
        title: l10n.businessEmptyTitle,
        body: l10n.businessEmptyBody,
        action: OutlinedButton(
          onPressed: () => context.go(AppRoutes.explore),
          child: Text(l10n.businessBackToClientAction),
        ),
      ),
    );
  }
}
