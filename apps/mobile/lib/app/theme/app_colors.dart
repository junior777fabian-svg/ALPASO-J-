import 'dart:ui';

/// Colores de marca de Al Paso: oro, carbón y perla.
abstract final class AppColors {
  static const gold = Color(0xFFC9A84C);
  static const goldLight = Color(0xFFE8C96B);

  static const pearl = Color(0xFFF5F0E8);

  static const charcoal = Color(0xFF111111);
  static const charcoalLight = Color(0xFF1C1C1C);
  static const charcoalMid = Color(0xFF252525);

  static const border = Color(0xFF2E2E2E);

  /// Texto secundario. Contraste de 7:1 sobre carbón.
  static const muted = Color(0xFFA09F92);

  static const danger = Color(0xFFEF4444);

  /// Fondo del rótulo DEMO. No se usa para nada más.
  static const demo = Color(0xFFD9480F);
}
