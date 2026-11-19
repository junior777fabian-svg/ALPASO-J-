import 'package:alpaso/features/auth/data/auth_providers.dart';
import 'package:alpaso/features/business/domain/photo.dart';
import 'package:alpaso/features/explore/data/explore_repository.dart';
import 'package:alpaso/features/explore/data/location_service.dart';
import 'package:alpaso/features/explore/domain/search.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Nulo cuando la app corre sin servidor.
final exploreRepositoryProvider = Provider<ExploreRepository?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : SupabaseExploreRepository(client);
});

final locationServiceProvider = Provider<LocationService>(
  (ref) => DeviceLocationService(),
);

/// La hora actual. Las pruebas la fijan.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Bloques que se pueden elegir. Sin servidor, los de la configuración
/// inicial.
final searchBlocksProvider = FutureProvider<List<int>>((ref) async {
  const fallback = [4, 6, 8, 12, 24];
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return fallback;
  try {
    final settings = await client.rpc<Map<String, dynamic>>(
      'get_public_settings',
    );
    final blocks = [
      for (final h in (settings['booking_blocks_hours'] as List?) ?? const [])
        (h as num).toInt(),
    ];
    return blocks.isEmpty ? fallback : blocks;
  } on Exception {
    return fallback;
  }
});

class SearchQueryNotifier extends Notifier<SearchQuery> {
  @override
  SearchQuery build() => const SearchQuery();

  void update(SearchQuery Function(SearchQuery) change) =>
      state = change(state);
}

final searchQueryProvider = NotifierProvider<SearchQueryNotifier, SearchQuery>(
  SearchQueryNotifier.new,
);

final searchResultsProvider = FutureProvider<List<LodgingResult>>((ref) {
  final repository = ref.watch(exploreRepositoryProvider);
  final query = ref.watch(searchQueryProvider);
  if (repository == null) return Future.value(const []);
  return repository.search(query, ref.read(clockProvider)());
});

final publicLodgingProvider = FutureProvider.family<PublicLodging, String>((
  ref,
  id,
) {
  return ref.watch(exploreRepositoryProvider)!.lodging(id);
});

/// Oferta del hostal para la búsqueda actual.
final lodgingOfferProvider = FutureProvider.family<List<OfferRoomType>, String>(
  (ref, id) {
    final query = ref.watch(searchQueryProvider);
    return ref
        .watch(exploreRepositoryProvider)!
        .offer(
          id,
          query.arrivalOrNow(ref.read(clockProvider)()),
          query.blockHours,
        );
  },
);

final roomTypePhotosProvider = FutureProvider.family<List<Photo>, String>((
  ref,
  roomTypeId,
) {
  return ref.watch(exploreRepositoryProvider)!.roomTypePhotos(roomTypeId);
});
