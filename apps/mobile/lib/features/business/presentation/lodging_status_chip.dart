import 'package:alpaso/features/business/domain/lodging.dart';
import 'package:alpaso/features/business/presentation/business_messages.dart';
import 'package:alpaso/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

class LodgingStatusChip extends StatelessWidget {
  const LodgingStatusChip({required this.status, super.key});

  final LodgingStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (status) {
      LodgingStatus.published => (scheme.primary, scheme.onPrimary),
      LodgingStatus.rejected || LodgingStatus.suspended => (
        scheme.errorContainer,
        scheme.onErrorContainer,
      ),
      _ => (scheme.surfaceContainerHighest, scheme.onSurface),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        lodgingStatusLabel(AppLocalizations.of(context), status),
        style: TextStyle(color: foreground, fontWeight: FontWeight.w600),
      ),
    );
  }
}
