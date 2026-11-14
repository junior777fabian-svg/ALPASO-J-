import 'package:alpaso/design/widgets/empty_state.dart';
import 'package:alpaso/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// C6. Por ahora solo el marco; las reservas llegan en la etapa 4.
class MyBookingsScreen extends StatelessWidget {
  const MyBookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.bookingsTitle)),
      body: EmptyState(
        icon: Icons.confirmation_number_outlined,
        title: l10n.bookingsEmptyTitle,
        body: l10n.bookingsEmptyBody,
      ),
    );
  }
}
