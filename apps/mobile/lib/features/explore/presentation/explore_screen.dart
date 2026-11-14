import 'package:alpaso/design/widgets/empty_state.dart';
import 'package:alpaso/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// C2. Por ahora solo el marco; el mapa y la lista llegan en la etapa 3.
class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.exploreTitle)),
      body: EmptyState(
        icon: Icons.map_outlined,
        title: l10n.exploreEmptyTitle,
        body: l10n.exploreEmptyBody,
      ),
    );
  }
}
