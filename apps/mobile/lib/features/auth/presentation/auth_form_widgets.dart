import 'package:alpaso/app/theme/app_spacing.dart';
import 'package:alpaso/features/auth/domain/auth_validators.dart';
import 'package:alpaso/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Campo de contraseña con botón para mostrarla.
class PasswordField extends StatefulWidget {
  const PasswordField({
    required this.controller,
    this.validator,
    this.showHelp = false,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final FormFieldValidator<String>? validator;
  final bool showHelp;
  final VoidCallback? onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextFormField(
      key: const Key('auth-password'),
      controller: widget.controller,
      obscureText: _obscure,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: const [AutofillHints.password],
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => widget.onSubmitted?.call(),
      validator: widget.validator,
      decoration: InputDecoration(
        labelText: l10n.authPasswordLabel,
        helperText: widget.showHelp
            ? l10n.authPasswordHelp(AuthValidators.minPasswordLength)
            : null,
        suffixIcon: IconButton(
          tooltip: _obscure ? l10n.authShowPassword : l10n.authHidePassword,
          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }
}

/// Recuadro con el error que devolvió el servidor.
class FormErrorBox extends StatelessWidget {
  const FormErrorBox({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('auth-error'),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(message, style: TextStyle(color: scheme.onErrorContainer)),
      ),
    );
  }
}

/// Botón principal que muestra un indicador mientras espera al servidor.
class SubmitButton extends StatelessWidget {
  const SubmitButton({
    required this.label,
    required this.busy,
    required this.onPressed,
    super.key,
  });

  final String label;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      key: const Key('auth-submit'),
      onPressed: busy ? null : onPressed,
      child: busy
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );
  }
}
