import 'package:alpaso/app/router/app_router.dart';
import 'package:alpaso/app/theme/app_spacing.dart';
import 'package:alpaso/design/widgets/empty_state.dart';
import 'package:alpaso/features/auth/data/auth_providers.dart';
import 'package:alpaso/features/business/data/business_providers.dart';
import 'package:alpaso/features/business/domain/lodging.dart';
import 'package:alpaso/features/business/presentation/business_messages.dart';
import 'package:alpaso/features/business/presentation/lodging_status_chip.dart';
import 'package:alpaso/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Entrada al modo negocio: los hostales de la cuenta y el registro de uno
/// nuevo (N1).
class BusinessHomeScreen extends ConsumerWidget {
  const BusinessHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final hasServer = ref.watch(businessRepositoryProvider) != null;
    final user = ref.watch(authUserProvider).value;

    final backButton = OutlinedButton(
      onPressed: () => context.go(AppRoutes.explore),
      child: Text(l10n.businessBackToClientAction),
    );

    final Widget body;
    if (!hasServer) {
      body = EmptyState(
        icon: Icons.storefront_outlined,
        title: l10n.businessEmptyTitle,
        body: l10n.businessNoServerBody,
        action: backButton,
      );
    } else if (user == null) {
      body = EmptyState(
        icon: Icons.storefront_outlined,
        title: l10n.businessEmptyTitle,
        body: l10n.businessSignInBody,
        action: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(
              onPressed: () => context.push(AppRoutes.signIn),
              child: Text(l10n.profileSignInAction),
            ),
            const SizedBox(height: AppSpacing.md),
            backButton,
          ],
        ),
      );
    } else {
      body = _LodgingList(backButton: backButton);
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.businessTitle)),
      body: body,
    );
  }
}

class _LodgingList extends ConsumerWidget {
  const _LodgingList({required this.backButton});

  final Widget backButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final lodgings = ref.watch(myLodgingsProvider);

    final register = FilledButton.icon(
      onPressed: () => context.push(AppRoutes.newLodging),
      icon: const Icon(Icons.add_business_outlined),
      label: Text(l10n.businessRegisterAction),
    );

    return switch (lodgings) {
      AsyncData(value: final List<Lodging> list) when list.isEmpty =>
        EmptyState(
          icon: Icons.storefront_outlined,
          title: l10n.businessEmptyTitle,
          body: l10n.businessNoLodgingsBody,
          action: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              register,
              const SizedBox(height: AppSpacing.md),
              backButton,
            ],
          ),
        ),
      AsyncData(value: final List<Lodging> list) => RefreshIndicator(
        onRefresh: () => ref.refresh(myLodgingsProvider.future),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            for (final lodging in list)
              Card(
                child: ListTile(
                  title: Text(lodging.name),
                  subtitle: Text(
                    [
                      lodging.districtName,
                      lodging.draft.address,
                    ].where((s) => s.isNotEmpty).join(' · '),
                  ),
                  trailing: LodgingStatusChip(status: lodging.status),
                  onTap: () => context.push(AppRoutes.lodging(lodging.id)),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            register,
            const SizedBox(height: AppSpacing.sm),
            backButton,
          ],
        ),
      ),
      AsyncError(:final error) => EmptyState(
        icon: Icons.error_outline,
        title: l10n.profileLoadErrorTitle,
        body: businessFailureMessage(l10n, error),
        action: FilledButton(
          onPressed: () => ref.invalidate(myLodgingsProvider),
          child: Text(l10n.profileRetryAction),
        ),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}
