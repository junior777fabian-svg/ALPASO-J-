import 'package:alpaso/app/router/app_router.dart';
import 'package:alpaso/app/theme/app_spacing.dart';
import 'package:alpaso/core/format/money.dart';
import 'package:alpaso/design/widgets/empty_state.dart';
import 'package:alpaso/features/explore/data/explore_providers.dart';
import 'package:alpaso/features/explore/domain/search.dart';
import 'package:alpaso/features/explore/presentation/explore_messages.dart';
import 'package:alpaso/features/lodging/presentation/photo_gallery.dart';
import 'package:alpaso/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// C3. Ficha del hostal: fotos, servicios, dirección y tipos de cuarto con
/// su precio para la búsqueda actual.
class PublicLodgingScreen extends ConsumerWidget {
  const PublicLodgingScreen({required this.lodgingId, super.key});

  final String lodgingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final lodging = ref.watch(publicLodgingProvider(lodgingId));

    return Scaffold(
      appBar: AppBar(title: Text(lodging.value?.name ?? '')),
      body: switch (lodging) {
        AsyncData(:final value) => _Body(lodging: value),
        AsyncError(:final error) => EmptyState(
          icon: Icons.error_outline,
          title: l10n.exploreErrorTitle,
          body: exploreFailureMessage(l10n, error),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.lodging});

  final PublicLodging lodging;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final query = ref.watch(searchQueryProvider);
    final offer = ref.watch(lodgingOfferProvider(lodging.id));
    final now = ref.read(clockProvider)();

    return ListView(
      children: [
        PhotoGallery(urls: lodging.photoUrls),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(lodging.name, style: theme.textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.xs),
              Text('${lodging.address} · ${lodging.districtName}'),
              if (lodging.addressReference.isNotEmpty)
                Text(
                  lodging.addressReference,
                  style: theme.textTheme.bodySmall,
                ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  if (lodging.hasParking)
                    Chip(
                      avatar: const Icon(Icons.local_parking, size: 18),
                      label: Text(l10n.lodgingParkingLabel),
                    ),
                  if (lodging.hasWifi)
                    Chip(
                      avatar: const Icon(Icons.wifi, size: 18),
                      label: Text(l10n.lodgingWifiLabel),
                    ),
                ],
              ),
              if (lodging.description.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(lodging.description),
              ],
              const SizedBox(height: AppSpacing.lg),
              Text(l10n.offerTitle, style: theme.textTheme.titleMedium),
              Text(
                l10n.offerFor(
                  query.blockHours,
                  formatArrival(l10n, query.arrival, now),
                ),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              switch (offer) {
                AsyncData(value: final List<OfferRoomType> types) => Column(
                  children: [
                    for (final type in types)
                      Card(
                        key: Key('offer-${type.roomTypeId}'),
                        child: ListTile(
                          title: Text(type.name),
                          subtitle: Text(
                            [
                              l10n.roomGuests(type.maxGuests),
                              if (type.hasJacuzzi) l10n.roomTypeJacuzzi,
                              if (type.hasTv) l10n.roomTypeTv,
                              if (type.hasAirConditioning)
                                l10n.roomTypeAirConditioning,
                            ].join(' · '),
                          ),
                          trailing: Text(
                            type.priceCents == null
                                ? l10n.offerNotSold(query.blockHours)
                                : type.isAvailable
                                ? formatSoles(type.priceCents!)
                                : l10n.offerTaken,
                            style: TextStyle(
                              color: type.isBookable
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onTap: () => context.push(
                            AppRoutes.publicRoomType(
                              lodging.id,
                              type.roomTypeId,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                AsyncError(:final error) => Text(
                  exploreFailureMessage(l10n, error),
                ),
                _ => const LinearProgressIndicator(),
              },
            ],
          ),
        ),
      ],
    );
  }
}
