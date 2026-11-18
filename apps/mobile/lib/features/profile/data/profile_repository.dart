import 'package:alpaso/features/auth/domain/auth_failure.dart';
import 'package:alpaso/features/profile/domain/profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// Lectura y cambios del perfil de la cuenta en sesión.
abstract interface class ProfileRepository {
  /// El perfil de la cuenta en sesión. Lo crea el servidor al registrarse.
  Future<Profile> fetchMine();

  /// Cambia el nombre. Es lo único del perfil que la app puede escribir.
  Future<Profile> updateFullName(String fullName);

  /// La cuenta declara ser mayor de 18. El servidor guarda la fecha; repetir
  /// la llamada no la cambia.
  Future<DateTime> confirmAdult();
}

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);

  final sb.SupabaseClient _client;

  static const _columns = 'id, full_name, adult_confirmed_at, is_blocked';

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw const AuthFailure(AuthFailureReason.unknown, 'sin sesión');
    }
    return id;
  }

  @override
  Future<Profile> fetchMine() => _guard(() async {
    final row = await _client
        .from('profiles')
        .select(_columns)
        .eq('id', _userId)
        .single();
    return Profile.fromJson(row);
  });

  @override
  Future<Profile> updateFullName(String fullName) => _guard(() async {
    final row = await _client
        .from('profiles')
        .update({'full_name': fullName.trim()})
        .eq('id', _userId)
        .select(_columns)
        .single();
    return Profile.fromJson(row);
  });

  @override
  Future<DateTime> confirmAdult() => _guard(() async {
    final value = await _client.rpc<String>('confirm_adult');
    return DateTime.parse(value);
  });

  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AuthFailure {
      rethrow;
    } on sb.PostgrestException catch (error) {
      throw AuthFailure(
        AuthFailureReason.unknown,
        '${error.code}: ${error.message}',
      );
    } on Exception catch (error) {
      throw AuthFailure(AuthFailureReason.network, '$error');
    }
  }
}
