import 'package:alpaso/app/router/app_router.dart';
import 'package:alpaso/app/theme/app_spacing.dart';
import 'package:alpaso/core/format/money.dart';
import 'package:alpaso/features/business/domain/photo.dart';
import 'package:alpaso/features/business/presentation/business_messages.dart';
import 'package:alpaso/features/explore/data/explore_providers.dart';
import 'package:alpaso/features/lodging/presentation/photo_gallery.dart';
import 'package:alpaso/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// C4. Un tipo de cuarto: galería etiquetada (habitación, baño, jacuzzi),
/// características y tarifas por bloque.
class PublicRoomTypeScreen extends ConsumerWidget {
  const PublicRoomTypeScreen({
    required this.lodgingId,
    required this.roomTypeId,
    super.key,
  });

  final String lodgingId;
  final String roomTypeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final query = ref.watch(searchQueryProvider);
    final type = ref
        .watch(lodgingOfferProvider(lodgingId))
        .value
        ?.where((t) => t.roomTypeId == roomTypeId)
        .firstOrNull;
    final photos =
        ref.watch(roomTypePhotosProvider(roomTypeId)).value ?? const <Photo>[];

    // Habitación primero, luego baño, jacuzzi y otras.
    final ordered = [...photos]
      ..sort((a, b) => (a.kind?.index ?? 9).compareTo(b.kind?.index ?? 9));

    return Scaffold(
      appBar: AppBar(title: Text(type?.name ?? '')),
      body: type == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                PhotoGallery(
                  height: 280,
                  urls: [for (final p in ordered) p.url],
                  labels: [
                    for (final p in ordered)
                      p.kind == null ? '' : photoKindLabel(l10n, p.kind!),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(type.name, style: theme.textTheme.headlineSmall),
                      if (type.description.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(type.description),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        children: [
                          Chip(label: Text(l10n.roomGuests(type.maxGuests))),
                          if (type.hasJacuzzi)
                            Chip(label: Text(l10n.roomTypeJacuzzi)),
                          if (type.hasTv) Chip(label: Text(l10n.roomTypeTv)),
                          if (type.hasAirConditioning)
                            Chip(label: Text(l10n.roomTypeAirConditioning)),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(l10n.ratesTitle, style: theme.textTheme.titleMedium),
                      for (final e
                          in (type.rates.entries.toList()
                            ..sort((a, b) => a.key.compareTo(b.key))))
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(l10n.rateFieldLabel(e.key)),
                          trailing: Text(
                            formatSoles(e.value),
                            style: e.key == query.blockHours
                                ? TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w700,
                                  )
                                : null,
                          ),
                        ),
                      const SizedBox(height: AppSpacing.lg),
                      FilledButton(
                        key: const Key('room-book'),
                        onPressed: type.isBookable
                            ? () => context.push(
                                AppRoutes.book(lodgingId, roomTypeId),
                              )
                            : null,
                        child: Text(
                          type.isBookable ? l10n.bookAction : l10n.offerTaken,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
