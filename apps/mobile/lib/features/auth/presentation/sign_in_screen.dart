import 'package:alpaso/app/router/app_router.dart';
import 'package:alpaso/app/theme/app_spacing.dart';
import 'package:alpaso/features/auth/data/auth_providers.dart';
import 'package:alpaso/features/auth/domain/auth_validators.dart';
import 'package:alpaso/features/auth/presentation/auth_form_widgets.dart';
import 'package:alpaso/features/auth/presentation/auth_messages.dart';
import 'package:alpaso/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// C1. Inicio de sesión con correo y contraseña.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final repository = ref.read(authRepositoryProvider);
    if (_busy || repository == null) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await repository.signIn(email: _email.text, password: _password.text);
      if (mounted) context.go(AppRoutes.profile);
    } on Object catch (error) {
      if (!mounted) return;
      setState(
        () => _error = authFailureMessage(AppLocalizations.of(context), error),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.authSignInTitle)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: AutofillGroup(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                TextFormField(
                  key: const Key('auth-email'),
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(labelText: l10n.authEmailLabel),
                  validator: (value) => AuthValidators.isValidEmail(value ?? '')
                      ? null
                      : l10n.authErrorEmailInvalid,
                ),
                const SizedBox(height: AppSpacing.md),
                PasswordField(
                  controller: _password,
                  onSubmitted: _submit,
                  // Al entrar no se exige el largo mínimo: la cuenta pudo
                  // crearse con otra regla. Solo que no esté vacía.
                  validator: (value) => (value ?? '').isEmpty
                      ? l10n.authErrorPasswordRequired
                      : null,
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_error != null) ...[
                  FormErrorBox(message: _error!),
                  const SizedBox(height: AppSpacing.md),
                ],
                SubmitButton(
                  label: l10n.authSignInSubmit,
                  busy: _busy,
                  onPressed: _submit,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => context.pushReplacement(AppRoutes.signUp),
                  child: Text(l10n.authGoToSignUp),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
