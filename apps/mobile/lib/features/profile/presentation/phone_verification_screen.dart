import 'package:alpaso/app/theme/app_spacing.dart';
import 'package:alpaso/features/auth/data/auth_providers.dart';
import 'package:alpaso/features/auth/presentation/auth_form_widgets.dart';
import 'package:alpaso/features/auth/presentation/auth_messages.dart';
import 'package:alpaso/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// C1. Verificar el celular antes de la primera reserva. Con el conector
/// demo, el código se muestra en pantalla con el rótulo DEMO.
class PhoneVerificationScreen extends ConsumerStatefulWidget {
  const PhoneVerificationScreen({super.key});

  @override
  ConsumerState<PhoneVerificationScreen> createState() =>
      _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState
    extends ConsumerState<PhoneVerificationScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  bool _sent = false;
  String? _demoCode;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on Object catch (error) {
      if (mounted) {
        setState(
          () =>
              _error = authFailureMessage(AppLocalizations.of(context), error),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _send() => _run(() async {
    final demo = await ref
        .read(profileRepositoryProvider)!
        .requestPhoneCode(_phone.text);
    setState(() {
      _sent = true;
      _demoCode = demo;
    });
  });

  void _verify() => _run(() async {
    await ref.read(profileRepositoryProvider)!.verifyPhoneCode(_code.text);
    ref.invalidate(myProfileProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).phoneVerified)),
    );
    context.pop(true);
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.phoneTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.phoneHelp),
              const SizedBox(height: AppSpacing.md),
              TextField(
                key: const Key('phone-number'),
                controller: _phone,
                keyboardType: TextInputType.phone,
                enabled: !_sent,
                decoration: InputDecoration(
                  labelText: l10n.phoneLabel,
                  prefixText: '+51 ',
                  hintText: '987 654 321',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (!_sent)
                FilledButton(
                  key: const Key('phone-send'),
                  onPressed: _busy ? null : _send,
                  child: Text(l10n.phoneSendCode),
                )
              else ...[
                if (_demoCode != null)
                  Container(
                    key: const Key('phone-demo-code'),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: Colors.deepOrange.shade700,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      l10n.phoneDemoCode(_demoCode!),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  key: const Key('phone-code'),
                  controller: _code,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(labelText: l10n.phoneCodeLabel),
                ),
                FilledButton(
                  key: const Key('phone-verify'),
                  onPressed: _busy ? null : _verify,
                  child: Text(l10n.phoneVerifyAction),
                ),
                TextButton(
                  onPressed: _busy ? null : () => setState(() => _sent = false),
                  child: Text(l10n.phoneChangeNumber),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                FormErrorBox(message: _error!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
