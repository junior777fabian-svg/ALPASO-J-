import 'package:alpaso/app/router/app_router.dart';
import 'package:alpaso/app/theme/app_spacing.dart';
import 'package:alpaso/features/auth/data/auth_providers.dart';
import 'package:alpaso/features/auth/presentation/auth_form_widgets.dart';
import 'package:alpaso/features/auth/presentation/auth_messages.dart';
import 'package:alpaso/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Ayuda: escribir a soporte.
class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _message = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(profileRepositoryProvider)!
          .createSupportCase(_subject.text, _message.text);
      messenger.showSnackBar(SnackBar(content: Text(l10n.supportSent)));
      if (mounted) context.pop();
    } on Object catch (error) {
      if (mounted) setState(() => _error = authFailureMessage(l10n, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.supportTitle)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.supportHelp),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  key: const Key('support-subject'),
                  controller: _subject,
                  maxLength: 120,
                  decoration: InputDecoration(labelText: l10n.supportSubject),
                  validator: (v) => (v ?? '').trim().length < 3
                      ? l10n.lodgingErrorLength(3, 120)
                      : null,
                ),
                TextFormField(
                  key: const Key('support-message'),
                  controller: _message,
                  maxLength: 2000,
                  minLines: 4,
                  maxLines: 10,
                  decoration: InputDecoration(labelText: l10n.supportMessage),
                  validator: (v) => (v ?? '').trim().length < 10
                      ? l10n.lodgingErrorLength(10, 2000)
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                if (_error != null) ...[
                  FormErrorBox(message: _error!),
                  const SizedBox(height: AppSpacing.md),
                ],
                SubmitButton(
                  label: l10n.supportSend,
                  busy: _busy,
                  onPressed: _send,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Eliminar la cuenta: se escribe ELIMINAR para confirmar.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    if (_confirm.text.trim().toUpperCase() != l10n.deleteConfirmWord) {
      setState(() => _error = l10n.deleteTypeWord(l10n.deleteConfirmWord));
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(profileRepositoryProvider)!.deleteMyAccount();
      // La cuenta ya no existe: se cierra la sesión del teléfono.
      await ref.read(authRepositoryProvider)!.signOutLocally();
      messenger.showSnackBar(SnackBar(content: Text(l10n.deleteDone)));
      if (mounted) context.go(AppRoutes.explore);
    } on Object catch (error) {
      if (mounted) setState(() => _error = authFailureMessage(l10n, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.deleteTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.deleteBody),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.deleteKeeps, style: theme.textTheme.bodySmall),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                key: const Key('delete-confirm'),
                controller: _confirm,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: l10n.deleteTypeWord(l10n.deleteConfirmWord),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (_error != null) ...[
                FormErrorBox(message: _error!),
                const SizedBox(height: AppSpacing.md),
              ],
              FilledButton(
                key: const Key('delete-submit'),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                ),
                onPressed: _busy ? null : _delete,
                child: Text(l10n.deleteAction),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
