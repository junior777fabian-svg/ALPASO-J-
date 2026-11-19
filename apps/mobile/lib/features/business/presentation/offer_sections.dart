import 'package:alpaso/app/router/app_router.dart';
import 'package:alpaso/app/theme/app_spacing.dart';
import 'package:alpaso/core/format/money.dart';
import 'package:alpaso/features/business/data/business_providers.dart';
import 'package:alpaso/features/business/domain/offer.dart';
import 'package:alpaso/features/business/presentation/business_messages.dart';
import 'package:alpaso/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// N2. Tipos de cuarto del hostal, con sus precios y cuartos.
class RoomTypesSection extends ConsumerWidget {
  const RoomTypesSection({required this.lodgingId, super.key});

  final String lodgingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final roomTypes = ref.watch(roomTypesProvider(lodgingId));

    return _Section(
      title: l10n.roomTypesTitle,
      addLabel: l10n.roomTypeAddAction,
      onAdd: () => context.push(AppRoutes.newRoomType(lodgingId)),
      child: switch (roomTypes) {
        AsyncData(value: final List<RoomType> list) when list.isEmpty => Text(
          l10n.roomTypesEmpty,
        ),
        AsyncData(value: final List<RoomType> list) => Column(
          children: [
            for (final type in list)
              ListTile(
                key: Key('room-type-${type.id}'),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  type.draft.isActive
                      ? type.draft.name
                      : l10n.roomTypeInactiveName(type.draft.name),
                ),
                subtitle: Text(
                  [
                    if (type.draft.rates.isEmpty)
                      l10n.roomTypeNoRates
                    else
                      (type.draft.rates.entries.toList()
                            ..sort((a, b) => a.key.compareTo(b.key)))
                          .map(
                            (e) => l10n.rateLabel(e.key, formatSoles(e.value)),
                          )
                          .join(' · '),
                    if (type.draft.rooms.isEmpty)
                      l10n.roomTypeNoRooms
                    else
                      l10n.roomTypeRooms(type.draft.rooms.join(', ')),
                  ].join('\n'),
                ),
                trailing: Icon(
                  type.isReady ? Icons.check_circle : Icons.error_outline,
                  color: type.isReady
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.error,
                  semanticLabel: type.isReady
                      ? l10n.roomTypeReady
                      : l10n.roomTypeNotReady,
                ),
                onTap: () =>
                    context.push(AppRoutes.editRoomType(lodgingId, type.id)),
              ),
          ],
        ),
        AsyncError(:final error) => Text(businessFailureMessage(l10n, error)),
        _ => const LinearProgressIndicator(),
      },
    );
  }
}

/// N3. Carta de extras del hostal.
class ProductsSection extends ConsumerWidget {
  const ProductsSection({required this.lodgingId, super.key});

  final String lodgingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final products = ref.watch(productsProvider(lodgingId));

    return _Section(
      title: l10n.productsTitle,
      addLabel: l10n.productAddAction,
      onAdd: () => context.push(AppRoutes.newProduct(lodgingId)),
      child: switch (products) {
        AsyncData(value: final List<Product> list) when list.isEmpty => Text(
          l10n.productsEmpty,
        ),
        AsyncData(value: final List<Product> list) => Column(
          children: [
            for (final product in list)
              ListTile(
                key: Key('product-${product.id}'),
                contentPadding: EdgeInsets.zero,
                title: Text(product.draft.name),
                subtitle: Text(
                  product.draft.isAvailable
                      ? productCategoryLabel(l10n, product.draft.category)
                      : l10n.productSoldOut,
                ),
                trailing: Text(formatSoles(product.draft.priceCents)),
                onTap: () =>
                    context.push(AppRoutes.editProduct(lodgingId, product.id)),
              ),
          ],
        ),
        AsyncError(:final error) => Text(businessFailureMessage(l10n, error)),
        _ => const LinearProgressIndicator(),
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.addLabel,
    required this.onAdd,
    required this.child,
  });

  final String title;
  final String addLabel;
  final VoidCallback onAdd;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            child,
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: Text(addLabel),
            ),
          ],
        ),
      ),
    );
  }
}
