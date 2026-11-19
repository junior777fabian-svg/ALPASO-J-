import 'package:alpaso/app/router/app_router.dart';
import 'package:alpaso/app/theme/app_spacing.dart';
import 'package:alpaso/design/widgets/empty_state.dart';
import 'package:alpaso/features/business/data/business_providers.dart';
import 'package:alpaso/features/business/domain/lodging.dart';
import 'package:alpaso/features/business/presentation/business_messages.dart';
import 'package:alpaso/features/business/presentation/lodging_status_chip.dart';
import 'package:alpaso/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Ficha del hostal para su dueño: estado de revisión, datos, cuartos y
/// extras, y el envío a revisión.
class LodgingDetailScreen extends ConsumerStatefulWidget {
  const LodgingDetailScreen({required this.lodgingId, super.key});

  final String lodgingId;

  @override
  ConsumerState<LodgingDetailScreen> createState() =>
      _LodgingDetailScreenState();
}

class _LodgingDetailScreenState extends ConsumerState<LodgingDetailScreen> {
  bool _busy = false;

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(businessRepositoryProvider)!
          .submitLodging(widget.lodgingId);
      ref
        ..invalidate(lodgingProvider(widget.lodgingId))
        ..invalidate(myLodgingsProvider);
      messenger.showSnackBar(SnackBar(content: Text(l10n.lodgingSubmitted)));
    } on Object catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(businessFailureMessage(l10n, error))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lodging = ref.watch(lodgingProvider(widget.lodgingId));

    return Scaffold(
      appBar: AppBar(
        title: Text(lodging.value?.name ?? l10n.businessTitle),
        actions: [
          if (lodging.hasValue)
            IconButton(
              tooltip: l10n.lodgingEditTitle,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () =>
                  context.push(AppRoutes.editLodging(widget.lodgingId)),
            ),
        ],
      ),
      body: switch (lodging) {
        AsyncData(:final value) => RefreshIndicator(
          onRefresh: () =>
              ref.refresh(lodgingProvider(widget.lodgingId).future),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              _StatusCard(lodging: value),
              const SizedBox(height: AppSpacing.md),
              _DataCard(lodging: value),
              ...lodgingSections(widget.lodgingId),
              const SizedBox(height: AppSpacing.lg),
              if (value.status.canSubmit) ...[
                Text(
                  l10n.lodgingSubmitHelp,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                FilledButton(
                  key: const Key('lodging-submit'),
                  onPressed: _busy ? null : _submit,
                  child: Text(l10n.lodgingSubmitAction),
                ),
              ],
            ],
          ),
        ),
        AsyncError(:final error) => EmptyState(
          icon: Icons.error_outline,
          title: l10n.profileLoadErrorTitle,
          body: businessFailureMessage(l10n, error),
          action: FilledButton(
            onPressed: () => ref.invalidate(lodgingProvider(widget.lodgingId)),
            child: Text(l10n.profileRetryAction),
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

/// Secciones de cuartos y extras. Las agrega la parte 2C.
List<Widget> lodgingSections(String lodgingId) => const [];

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.lodging});

  final Lodging lodging;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LodgingStatusChip(status: lodging.status),
            const SizedBox(height: AppSpacing.sm),
            Text(lodgingStatusHelp(l10n, lodging.status)),
            if (lodging.status == LodgingStatus.rejected &&
                lodging.reviewNote.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.lodgingReviewNote(lodging.reviewNote),
                key: const Key('lodging-review-note'),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DataCard extends StatelessWidget {
  const _DataCard({required this.lodging});

  final Lodging lodging;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final d = lodging.draft;
    final services = [
      if (d.hasParking) l10n.lodgingParkingLabel,
      if (d.hasWifi) l10n.lodgingWifiLabel,
    ];
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.place_outlined),
            title: Text(d.address),
            subtitle: Text(
              [
                lodging.districtName,
                d.addressReference,
              ].where((s) => s.isNotEmpty).join(' · '),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: Text(l10n.lodgingCleaningLabel),
            subtitle: Text(l10n.lodgingMinutes(d.cleaningMinutes)),
          ),
          if (services.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.local_parking_outlined),
              title: Text(services.join(' · ')),
            ),
        ],
      ),
    );
  }
}
