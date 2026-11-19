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

/// C1. Registro con nombre, correo, contraseña y declaración de mayoría de
/// edad.
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isAdult = false;
  bool _showAdultError = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = ref.read(authRepositoryProvider);
    final profiles = ref.read(profileRepositoryProvider);
    if (_busy || auth == null || profiles == null) return;

    final fieldsOk = _formKey.currentState!.validate();
    setState(() => _showAdultError = !_isAdult);
    if (!fieldsOk || !_isAdult) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await auth.signUp(
        email: _email.text,
        password: _password.text,
        fullName: _name.text,
      );
      // La declaración la guarda el servidor con su propia hora. Si esta
      // llamada falla, el perfil vuelve a pedirla.
      try {
        await profiles.confirmAdult();
      } on Object {
        // Se reintenta desde el perfil.
      }
      ref.invalidate(myProfileProvider);
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.authSignUpTitle)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: AutofillGroup(
            // No es un ListView: construiría solo lo visible y el formulario
            // validaría solo esos campos.
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    key: const Key('auth-name'),
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const [AutofillHints.name],
                    textInputAction: TextInputAction.next,
                    maxLength: AuthValidators.maxNameLength,
                    decoration: InputDecoration(
                      labelText: l10n.authNameLabel,
                      hintText: l10n.authNameHint,
                      counterText: '',
                    ),
                    validator: (value) =>
                        AuthValidators.isValidName(value ?? '')
                        ? null
                        : l10n.authErrorNameRequired,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    key: const Key('auth-email'),
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(labelText: l10n.authEmailLabel),
                    validator: (value) =>
                        AuthValidators.isValidEmail(value ?? '')
                        ? null
                        : l10n.authErrorEmailInvalid,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PasswordField(
                    controller: _password,
                    showHelp: true,
                    validator: (value) =>
                        AuthValidators.isValidPassword(value ?? '')
                        ? null
                        : l10n.authErrorPasswordShort(
                            AuthValidators.minPasswordLength,
                          ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  CheckboxListTile(
                    key: const Key('auth-adult'),
                    value: _isAdult,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(l10n.authAdultCheckbox),
                    subtitle: _showAdultError
                        ? Text(
                            l10n.authErrorAdultRequired,
                            style: TextStyle(color: theme.colorScheme.error),
                          )
                        : null,
                    onChanged: _busy
                        ? null
                        : (value) => setState(() {
                            _isAdult = value ?? false;
                            if (_isAdult) _showAdultError = false;
                          }),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (_error != null) ...[
                    FormErrorBox(message: _error!),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  SubmitButton(
                    label: l10n.authSignUpSubmit,
                    busy: _busy,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => context.pushReplacement(AppRoutes.signIn),
                    child: Text(l10n.authGoToSignIn),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
