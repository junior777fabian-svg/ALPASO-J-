/// Validaciones de formulario. Solo evitan viajes inútiles al servidor: el
/// servidor vuelve a validar todo por su cuenta.
abstract final class AuthValidators {
  /// Igual que `minimum_password_length` en `supabase/config.toml`.
  static const minPasswordLength = 8;

  /// Igual que el límite de `profiles.full_name` en la base.
  static const maxNameLength = 80;

  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static bool isValidEmail(String value) => _email.hasMatch(value.trim());

  static bool isValidPassword(String value) =>
      value.length >= minPasswordLength;

  static bool isValidName(String value) {
    final name = value.trim();
    return name.isNotEmpty && name.length <= maxNameLength;
  }
}
