/// Motivos por los que una operación de cuenta no se completó.
///
/// La pantalla traduce cada motivo a un mensaje en español. Nunca se muestra
/// al usuario el texto técnico del servidor.
enum AuthFailureReason {
  /// Correo o contraseña incorrectos.
  invalidCredentials,

  /// Ya existe una cuenta con ese correo.
  emailInUse,

  /// El servidor rechazó la contraseña por débil.
  weakPassword,

  /// El servidor no aceptó el correo.
  invalidEmail,

  /// La cuenta se creó pero el servidor pide confirmarla por correo.
  emailNotConfirmed,

  /// Demasiados intentos seguidos.
  rateLimited,

  /// El servidor no admite registros nuevos.
  signupDisabled,

  /// No hubo conexión con el servidor.
  network,

  /// La cuenta está bloqueada por la plataforma.
  blocked,

  /// No se elimina la cuenta: tiene reservas activas.
  activeBookings,

  /// No se elimina la cuenta: es dueña de un hostal.
  ownsLodgings,

  /// No es un celular peruano.
  invalidPhone,

  /// Ese celular ya está verificado en otra cuenta.
  phoneInUse,

  /// El código no es el correcto o venció.
  wrongCode,

  /// Cualquier otro error.
  unknown,
}

class AuthFailure implements Exception {
  const AuthFailure(this.reason, [this.debugMessage = '']);

  final AuthFailureReason reason;

  /// Detalle técnico, solo para registros y pruebas.
  final String debugMessage;

  @override
  String toString() => 'AuthFailure(${reason.name}: $debugMessage)';
}
