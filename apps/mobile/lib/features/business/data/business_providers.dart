import 'package:alpaso/features/auth/data/auth_providers.dart';
import 'package:alpaso/features/business/data/business_repository.dart';
import 'package:alpaso/features/business/domain/lodging.dart';
import 'package:alpaso/features/business/domain/offer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Nulo cuando la app corre sin servidor.
final businessRepositoryProvider = Provider<BusinessRepository?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : SupabaseBusinessRepository(client);
});

/// Las pruebas lo apagan para no descargar el mapa.
final mapTilesEnabledProvider = Provider<bool>((ref) => true);

final districtsProvider = FutureProvider<List<District>>((ref) async {
  final repository = ref.watch(businessRepositoryProvider);
  return repository == null ? const [] : repository.districts();
});

/// Hostales de la cuenta en sesión. Vacío sin sesión.
final myLodgingsProvider = FutureProvider<List<Lodging>>((ref) async {
  final user = await ref.watch(authUserProvider.future);
  final repository = ref.watch(businessRepositoryProvider);
  if (user == null || repository == null) return const [];
  return repository.myLodgings();
});

final lodgingProvider = FutureProvider.family<Lodging, String>((ref, id) {
  return ref.watch(businessRepositoryProvider)!.lodging(id);
});

final platformRulesProvider = FutureProvider<PlatformRules>((ref) {
  return ref.watch(businessRepositoryProvider)!.platformRules();
});

final roomTypesProvider = FutureProvider.family<List<RoomType>, String>((
  ref,
  lodgingId,
) {
  return ref.watch(businessRepositoryProvider)!.roomTypes(lodgingId);
});

final productsProvider = FutureProvider.family<List<Product>, String>((
  ref,
  lodgingId,
) {
  return ref.watch(businessRepositoryProvider)!.products(lodgingId);
});
