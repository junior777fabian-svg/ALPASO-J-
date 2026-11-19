import 'package:alpaso/app/providers.dart';
import 'package:alpaso/app/router/app_router.dart';
import 'package:alpaso/app/theme/app_spacing.dart';
import 'package:alpaso/design/widgets/empty_state.dart';
import 'package:alpaso/features/auth/data/auth_providers.dart';
import 'package:alpaso/features/auth/domain/app_user.dart';
import 'package:alpaso/features/auth/domain/auth_validators.dart';
import 'package:alpaso/features/auth/presentation/auth_messages.dart';
import 'package:alpaso/features/profile/domain/profile.dart';
import 'package:alpaso/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// C7. La cuenta: entrar o registrarse, ver y cambiar el nombre, confirmar
/// la mayoría de edad, cerrar sesión y pasar al modo negocio.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final config = ref.watch(appConfigProvider);
    final theme = Theme.of(context);
    final user = ref.watch(authUserProvider);

    final Widget content;
    if (!config.hasServer) {
      content = EmptyState(
        icon: Icons.cloud_off_outlined,
        title: l10n.profileNoServerTitle,
        body: l10n.profileNoServerBody,
        action: const _BusinessModeButton(),
      );
    } else {
      content = switch (user) {
        AsyncData(value: final AppUser user) => _SignedIn(user: user),
        AsyncData() => const _SignedOut(),
        AsyncError(:final error) => _ErrorState(
          message: authFailureMessage(l10n, error),
          onRetry: () => ref.invalidate(authUserProvider),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      };
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileTitle)),
      body: Column(
        children: [
          Expanded(child: content),
          // Dato de diagnóstico para quien prueba la demo. Un cliente real no
          // tiene por qué verlo, así que en producción no se muestra.
          if (config.isDemo)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                [
                  l10n.profileEnvironmentDemo,
                  if (config.hasServer)
                    l10n.profileServerConfigured
                  else
                    l10n.profileServerNotConfigured,
                ].join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

class _BusinessModeButton extends StatelessWidget {
  const _BusinessModeButton();

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () => context.go(AppRoutes.business),
      child: Text(AppLocalizations.of(context).profileBusinessModeAction),
    );
  }
}

class _SignedOut extends StatelessWidget {
  const _SignedOut();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return EmptyState(
      icon: Icons.person_outline,
      title: l10n.profileEmptyTitle,
      body: l10n.profileSignedOutBody,
      action: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(
            onPressed: () => context.push(AppRoutes.signIn),
            child: Text(l10n.profileSignInAction),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            onPressed: () => context.push(AppRoutes.signUp),
            child: Text(l10n.profileSignUpAction),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _BusinessModeButton(),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return EmptyState(
      icon: Icons.error_outline,
      title: l10n.profileLoadErrorTitle,
      body: message,
      action: FilledButton(
        onPressed: onRetry,
        child: Text(l10n.profileRetryAction),
      ),
    );
  }
}

class _SignedIn extends ConsumerStatefulWidget {
  const _SignedIn({required this.user});

  final AppUser user;

  @override
  ConsumerState<_SignedIn> createState() => _SignedInState();
}

class _SignedInState extends ConsumerState<_SignedIn> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            authFailureMessage(AppLocalizations.of(context), error),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmAdult() => _run(() async {
    await ref.read(profileRepositoryProvider)!.confirmAdult();
    ref.invalidate(myProfileProvider);
  });

  Future<void> _signOut() => _run(() async {
    await ref.read(authRepositoryProvider)!.signOut();
  });

  Future<void> _editName(String current) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _EditNameDialog(initial: current),
    );
    if (name == null || name.trim() == current) return;
    await _run(() async {
      await ref.read(profileRepositoryProvider)!.updateFullName(name);
      ref.invalidate(myProfileProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profile = ref.watch(myProfileProvider);

    return switch (profile) {
      AsyncData(value: final Profile profile) => _details(l10n, profile),
      AsyncError(:final error) => _ErrorState(
        message: authFailureMessage(l10n, error),
        onRetry: () => ref.invalidate(myProfileProvider),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }

  Widget _details(AppLocalizations l10n, Profile profile) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        if (profile.isBlocked)
          Card(
            color: theme.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                l10n.profileBlockedBody,
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
            ),
          ),
        if (!profile.isAdultConfirmed)
          Card(
            key: const Key('profile-adult-pending'),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.profileAdultPendingTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(l10n.profileAdultPendingBody),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton(
                    onPressed: _busy ? null : _confirmAdult,
                    child: Text(l10n.profileAdultConfirmAction),
                  ),
                ],
              ),
            ),
          ),
        ListTile(
          leading: const Icon(Icons.badge_outlined),
          title: Text(l10n.profileNameLabel),
          subtitle: Text(
            profile.fullName.isEmpty ? l10n.profileNameEmpty : profile.fullName,
            key: const Key('profile-name'),
          ),
          trailing: IconButton(
            tooltip: l10n.profileEditNameAction,
            icon: const Icon(Icons.edit_outlined),
            onPressed: _busy ? null : () => _editName(profile.fullName),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.mail_outline),
          title: Text(l10n.profileEmailLabel),
          subtitle: Text(widget.user.email, key: const Key('profile-email')),
        ),
        if (profile.isAdultConfirmed)
          ListTile(
            leading: Icon(
              Icons.verified_outlined,
              color: theme.colorScheme.primary,
            ),
            title: Text(l10n.profileAdultConfirmedLabel),
          ),
        ListTile(
          leading: const Icon(Icons.help_outline),
          title: Text(l10n.supportTitle),
          onTap: () => context.push(AppRoutes.support),
        ),
        const SizedBox(height: AppSpacing.lg),
        const _BusinessModeButton(),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: _busy ? null : _signOut,
          child: Text(l10n.profileSignOutAction),
        ),
        TextButton(
          key: const Key('profile-delete-account'),
          onPressed: _busy ? null : () => context.push(AppRoutes.deleteAccount),
          child: Text(
            l10n.deleteTitle,
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ),
      ],
    );
  }
}

class _EditNameDialog extends StatefulWidget {
  const _EditNameDialog({required this.initial});

  final String initial;

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  late final _controller = TextEditingController(text: widget.initial);
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop(_controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.profileEditNameTitle),
      content: Form(
        key: _formKey,
        child: TextFormField(
          key: const Key('profile-name-field'),
          controller: _controller,
          autofocus: true,
          maxLength: AuthValidators.maxNameLength,
          textCapitalization: TextCapitalization.words,
          onFieldSubmitted: (_) => _save(),
          validator: (value) => AuthValidators.isValidName(value ?? '')
              ? null
              : l10n.authErrorNameRequired,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.profileCancelAction),
        ),
        FilledButton(onPressed: _save, child: Text(l10n.profileSaveAction)),
      ],
    );
  }
}
