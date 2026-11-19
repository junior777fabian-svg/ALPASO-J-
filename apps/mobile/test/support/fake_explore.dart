import 'package:alpaso/features/business/domain/photo.dart';
import 'package:alpaso/features/explore/data/explore_repository.dart';
import 'package:alpaso/features/explore/data/location_service.dart';
import 'package:alpaso/features/explore/domain/search.dart';
import 'package:latlong2/latlong.dart';

/// Búsqueda en memoria. Guarda la última consulta para comprobarla.
class FakeExploreServer implements ExploreRepository {
  final results = <LodgingResult>[];
  final lodgings = <String, PublicLodging>{};
  final offers = <String, List<OfferRoomType>>{};
  final photos = <String, List<Photo>>{};
  final queries = <SearchQuery>[];
  ExploreFailureReason? nextFailure;

  SearchQuery? get lastQuery => queries.isEmpty ? null : queries.last;

  /// Agrega un hostal con un tipo de cuarto libre.
  void seedLodging({
    String id = 'l1',
    String name = 'Hostal Sol',
    int priceCents = 3000,
    bool available = true,
  }) {
    results.add(
      LodgingResult(
        lodgingId: id,
        name: name,
        districtName: 'Miraflores',
        address: 'Av. Larco 123',
        location: const LatLng(-12.1211, -77.0297),
        distanceMeters: 850,
        minPriceCents: priceCents,
        availableRoomTypes: 1,
        hasJacuzzi: true,
      ),
    );
    lodgings[id] = PublicLodging(
      id: id,
      name: name,
      districtName: 'Miraflores',
      address: 'Av. Larco 123',
      addressReference: 'Frente al parque',
      location: const LatLng(-12.1211, -77.0297),
      hasParking: true,
      photoUrls: const ['http://fotos.invalid/fachada.jpg'],
    );
    offers[id] = [
      OfferRoomType(
        roomTypeId: '$id-suite',
        name: 'Suite',
        hasJacuzzi: true,
        priceCents: priceCents,
        isAvailable: available,
        rates: {4: priceCents, 12: priceCents * 2},
      ),
      const OfferRoomType(
        roomTypeId: 'simple',
        name: 'Simple',
        isAvailable: false,
        priceCents: 2000,
        rates: {4: 2000},
      ),
    ];
    photos['$id-suite'] = const [
      Photo(
        id: 'p1',
        storagePath: 'x/b.jpg',
        url: 'http://fotos.invalid/b.jpg',
        kind: PhotoKind.bathroom,
      ),
      Photo(
        id: 'p2',
        storagePath: 'x/c.jpg',
        url: 'http://fotos.invalid/c.jpg',
        kind: PhotoKind.room,
      ),
    ];
  }

  void _maybeFail() {
    final reason = nextFailure;
    if (reason != null) {
      nextFailure = null;
      throw ExploreFailure(reason, 'falla de prueba');
    }
  }

  @override
  Future<List<LodgingResult>> search(SearchQuery query, DateTime now) async {
    queries.add(query);
    _maybeFail();
    return [
      for (final r in results)
        if (query.maxPriceCents == null ||
            r.minPriceCents <= query.maxPriceCents!)
          r,
    ];
  }

  @override
  Future<PublicLodging> lodging(String lodgingId) async {
    _maybeFail();
    final lodging = lodgings[lodgingId];
    if (lodging == null) {
      throw const ExploreFailure(ExploreFailureReason.notFound);
    }
    return lodging;
  }

  @override
  Future<List<OfferRoomType>> offer(
    String lodgingId,
    DateTime arrival,
    int blockHours,
  ) async => offers[lodgingId] ?? const [];

  @override
  Future<List<Photo>> roomTypePhotos(String roomTypeId) async =>
      photos[roomTypeId] ?? const [];
}

class FakeLocationService implements LocationService {
  FakeLocationService([this.point]);

  LatLng? point;

  @override
  Future<LatLng?> current() async => point;
}
