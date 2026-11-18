import 'package:alpaso/app/providers.dart';
import 'package:alpaso/features/auth/data/auth_repository.dart';
import 'package:alpaso/features/auth/domain/app_user.dart';
import 'package:alpaso/features/profile/data/profile_repository.dart';
import 'package:alpaso/features/profile/domain/profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// Cliente del servidor. Solo existe si la app se compiló con servidor;
/// `bootstrap` lo inicializa antes de abrir la app.
final supabaseClientProvider = Provider<sb.SupabaseClient?>((ref) {
  final config = ref.watch(appConfigProvider);
  return config.hasServer ? sb.Supabase.instance.client : null;
});

/// Nulo cuando la app corre sin servidor: las cuentas no están disponibles.
final authRepositoryProvider = Provider<AuthRepository?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : SupabaseAuthRepository(client.auth);
});

final profileRepositoryProvider = Provider<ProfileRepository?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : SupabaseProfileRepository(client);
});

/// La cuenta con sesión, o nulo. Cambia sola al entrar y al salir.
final authUserProvider = StreamProvider<AppUser?>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  if (repository == null) return Stream.value(null);
  return repository.watchUser();
});

/// Perfil de la cuenta con sesión, o nulo si no hay sesión.
final myProfileProvider = FutureProvider<Profile?>((ref) async {
  final user = await ref.watch(authUserProvider.future);
  final repository = ref.watch(profileRepositoryProvider);
  if (user == null || repository == null) return null;
  return repository.fetchMine();
});
