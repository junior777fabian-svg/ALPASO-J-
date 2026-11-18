import 'dart:async';

import 'package:alpaso/features/auth/domain/app_user.dart';
import 'package:alpaso/features/auth/domain/auth_failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// Registro, inicio y cierre de sesión.
///
/// Las pantallas solo conocen esta interfaz. Las pruebas de pantalla usan una
/// versión falsa; las pruebas contra el servidor usan [SupabaseAuthRepository].
abstract interface class AuthRepository {
  /// La cuenta con sesión ahora mismo, o nulo.
  AppUser? get currentUser;

  /// Emite la cuenta actual al suscribirse y cada vez que cambia.
  Stream<AppUser?> watchUser();

  /// Crea la cuenta. Del registro el servidor solo toma el nombre.
  ///
  /// Lanza [AuthFailure] con `emailNotConfirmed` si la cuenta se creó pero el
  /// servidor exige confirmar el correo antes de iniciar sesión.
  Future<AppUser> signUp({
    required String email,
    required String password,
    required String fullName,
  });

  Future<AppUser> signIn({required String email, required String password});

  Future<void> signOut();
}

/// Implementación sobre el servicio de cuentas de Supabase.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._auth);

  final sb.GoTrueClient _auth;

  @override
  AppUser? get currentUser => _toUser(_auth.currentUser);

  @override
  Stream<AppUser?> watchUser() async* {
    yield currentUser;
    yield* _auth.onAuthStateChange
        .map((state) => _toUser(state.session?.user))
        .distinct();
  }

  @override
  Future<AppUser> signUp({
    required String email,
    required String password,
    required String fullName,
  }) => _guard(() async {
    final response = await _auth.signUp(
      email: email.trim(),
      password: password,
      data: {'full_name': fullName.trim()},
    );
    final user = _toUser(response.session?.user);
    if (user == null) {
      // Sin sesión: el servidor pide confirmar el correo. En demo esto
      // significa que el proyecto quedó mal configurado (ver 1D).
      throw const AuthFailure(AuthFailureReason.emailNotConfirmed);
    }
    return user;
  });

  @override
  Future<AppUser> signIn({required String email, required String password}) =>
      _guard(() async {
        final response = await _auth.signInWithPassword(
          email: email.trim(),
          password: password,
        );
        final user = _toUser(response.session?.user);
        if (user == null) {
          throw const AuthFailure(AuthFailureReason.unknown, 'sin sesión');
        }
        return user;
      });

  @override
  Future<void> signOut() => _guard(_auth.signOut);

  static AppUser? _toUser(sb.User? user) =>
      user == null ? null : AppUser(id: user.id, email: user.email ?? '');

  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AuthFailure {
      rethrow;
    } on sb.AuthException catch (error) {
      throw mapAuthException(error);
    } on TimeoutException catch (error) {
      throw AuthFailure(AuthFailureReason.network, '$error');
    } on Exception catch (error) {
      // Sin red, el cliente HTTP lanza SocketException o ClientException.
      throw AuthFailure(AuthFailureReason.network, '$error');
    }
  }
}

/// Traduce el error del servicio de cuentas a un motivo de la app.
AuthFailure mapAuthException(sb.AuthException error) {
  if (error is sb.AuthRetryableFetchException) {
    return AuthFailure(AuthFailureReason.network, error.message);
  }
  final reason = switch (error.code) {
    'invalid_credentials' => AuthFailureReason.invalidCredentials,
    'user_already_exists' || 'email_exists' => AuthFailureReason.emailInUse,
    'weak_password' => AuthFailureReason.weakPassword,
    'email_address_invalid' ||
    'validation_failed' => AuthFailureReason.invalidEmail,
    'email_not_confirmed' => AuthFailureReason.emailNotConfirmed,
    'over_request_rate_limit' ||
    'over_email_send_rate_limit' => AuthFailureReason.rateLimited,
    'signup_disabled' ||
    'email_provider_disabled' => AuthFailureReason.signupDisabled,
    'user_banned' => AuthFailureReason.blocked,
    _ => AuthFailureReason.unknown,
  };
  return AuthFailure(reason, '${error.code}: ${error.message}');
}
