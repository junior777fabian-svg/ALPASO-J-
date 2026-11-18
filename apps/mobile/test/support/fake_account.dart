import 'dart:async';

import 'package:alpaso/features/auth/data/auth_repository.dart';
import 'package:alpaso/features/auth/domain/app_user.dart';
import 'package:alpaso/features/auth/domain/auth_failure.dart';
import 'package:alpaso/features/profile/data/profile_repository.dart';
import 'package:alpaso/features/profile/domain/profile.dart';

/// Servidor de cuentas en memoria, para pruebas de pantalla.
class FakeAccountServer {
  final _users = <String, ({AppUser user, String password})>{};
  final profiles = <String, Profile>{};
  final _changes = StreamController<AppUser?>.broadcast();
  AppUser? currentUser;

  /// Si no es nulo, la próxima operación falla con este motivo.
  AuthFailureReason? nextFailure;

  /// Si es verdadero, `confirmAdult` falla siempre.
  bool failConfirmAdult = false;

  int _ids = 0;

  /// Crea una cuenta ya existente en el servidor.
  AppUser seed({
    required String email,
    required String password,
    String fullName = '',
    bool adult = true,
  }) {
    final user = AppUser(id: 'u${_ids++}', email: email);
    _users[email] = (user: user, password: password);
    profiles[user.id] = Profile(
      id: user.id,
      fullName: fullName,
      adultConfirmedAt: adult ? DateTime.utc(2026, 1, 1) : null,
      isBlocked: false,
    );
    return user;
  }

  void _maybeFail() {
    final reason = nextFailure;
    if (reason != null) {
      nextFailure = null;
      throw AuthFailure(reason, 'falla de prueba');
    }
  }

  void _setUser(AppUser? user) {
    currentUser = user;
    _changes.add(user);
  }

  late final AuthRepository auth = _FakeAuth(this);
  late final ProfileRepository profileRepository = _FakeProfiles(this);
}

class _FakeAuth implements AuthRepository {
  _FakeAuth(this.server);

  final FakeAccountServer server;

  @override
  AppUser? get currentUser => server.currentUser;

  @override
  Stream<AppUser?> watchUser() async* {
    yield server.currentUser;
    yield* server._changes.stream;
  }

  @override
  Future<AppUser> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    server._maybeFail();
    if (server._users.containsKey(email.trim())) {
      throw const AuthFailure(AuthFailureReason.emailInUse);
    }
    final user = server.seed(
      email: email.trim(),
      password: password,
      fullName: fullName.trim(),
      adult: false,
    );
    server._setUser(user);
    return user;
  }

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    server._maybeFail();
    final entry = server._users[email.trim()];
    if (entry == null || entry.password != password) {
      throw const AuthFailure(AuthFailureReason.invalidCredentials);
    }
    server._setUser(entry.user);
    return entry.user;
  }

  @override
  Future<void> signOut() async => server._setUser(null);
}

class _FakeProfiles implements ProfileRepository {
  _FakeProfiles(this.server);

  final FakeAccountServer server;

  String get _id => server.currentUser!.id;

  @override
  Future<Profile> fetchMine() async {
    server._maybeFail();
    return server.profiles[_id]!;
  }

  @override
  Future<Profile> updateFullName(String fullName) async {
    server._maybeFail();
    return server.profiles[_id] = server.profiles[_id]!.copyWith(
      fullName: fullName.trim(),
    );
  }

  @override
  Future<DateTime> confirmAdult() async {
    if (server.failConfirmAdult) {
      throw const AuthFailure(AuthFailureReason.network);
    }
    final profile = server.profiles[_id]!;
    final at = profile.adultConfirmedAt ?? DateTime.utc(2026, 11, 18);
    server.profiles[_id] = profile.copyWith(adultConfirmedAt: at);
    return at;
  }
}
