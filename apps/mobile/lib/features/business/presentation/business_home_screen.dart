import 'package:alpaso/app/router/app_router.dart';
import 'package:alpaso/app/theme/app_spacing.dart';
import 'package:alpaso/design/widgets/empty_state.dart';
import 'package:alpaso/design/widgets/text_prompt_dialog.dart';
import 'package:alpaso/features/auth/data/auth_providers.dart';
import 'package:alpaso/features/business/data/business_providers.dart';
import 'package:alpaso/features/business/domain/lodging.dart';
import 'package:alpaso/features/business/presentation/business_messages.dart';
import 'package:alpaso/features/business/presentation/lodging_status_chip.dart';
import 'package:alpaso/features/business/presentation/reception_messages.dart';
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
              const SizedBox(height: AppSpacing.sm),
              const _JoinButton(),
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
                  trailing: lodging.isOwner
                      ? LodgingStatusChip(status: lodging.status)
                      : Text(l10n.staffReceptionist),
                  // El recepcionista va directo a recepción.
                  onTap: () => context.push(
                    lodging.isOwner
                        ? AppRoutes.lodging(lodging.id)
                        : AppRoutes.reception(lodging.id),
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            register,
            const SizedBox(height: AppSpacing.sm),
            const _JoinButton(),
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

/// Unirse como recepcionista con el código que dio el dueño.
class _JoinButton extends ConsumerWidget {
  const _JoinButton();

  Future<void> _join(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final code = await showTextPrompt(
      context,
      title: l10n.joinTitle,
      label: l10n.joinCodeLabel,
      confirmLabel: l10n.joinAction,
      cancelLabel: l10n.profileCancelAction,
      fieldKey: const Key('join-code'),
      confirmKey: const Key('join-submit'),
      maxLength: 8,
      uppercase: true,
    );
    if (code == null || code.trim().isEmpty) return;
    try {
      final name = await ref
          .read(receptionRepositoryProvider)!
          .acceptInvite(code);
      ref.invalidate(myLodgingsProvider);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.joinDone(name))));
    } on Object catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(receptionFailureMessage(l10n, error))),
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton.icon(
      key: const Key('join-lodging'),
      onPressed: () => _join(context, ref),
      icon: const Icon(Icons.vpn_key_outlined),
      label: Text(AppLocalizations.of(context).joinAction),
    );
  }
}
