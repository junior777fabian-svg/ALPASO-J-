import 'package:alpaso/features/business/domain/photo.dart';
import 'package:alpaso/features/explore/domain/search.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// Por qué falló una búsqueda.
enum ExploreFailureReason { arrivalOutOfRange, notFound, network, unknown }

class ExploreFailure implements Exception {
  const ExploreFailure(this.reason, [this.debugMessage = '']);

  final ExploreFailureReason reason;
  final String debugMessage;

  @override
  String toString() => 'ExploreFailure(${reason.name}: $debugMessage)';
}

/// Lo que el modo cliente consulta al servidor. Se puede usar sin cuenta.
abstract interface class ExploreRepository {
  Future<List<LodgingResult>> search(SearchQuery query, DateTime now);

  Future<PublicLodging> lodging(String lodgingId);

  Future<List<OfferRoomType>> offer(
    String lodgingId,
    DateTime arrival,
    int blockHours,
  );

  /// Fotos de un tipo de cuarto de un hostal publicado.
  Future<List<Photo>> roomTypePhotos(String roomTypeId);
}

class SupabaseExploreRepository implements ExploreRepository {
  SupabaseExploreRepository(this._client);

  final sb.SupabaseClient _client;

  String _photoUrl(String path) =>
      _client.storage.from('lodging-photos').getPublicUrl(path);

  @override
  Future<List<LodgingResult>> search(SearchQuery query, DateTime now) =>
      _guard(() async {
        final rows = await _client.rpc<List<dynamic>>(
          'search_lodgings',
          params: {
            'p_latitude': query.center.latitude,
            'p_longitude': query.center.longitude,
            'p_arrival': query.arrivalOrNow(now).toUtc().toIso8601String(),
            'p_block_hours': query.blockHours,
            'p_radius_m': query.radiusMeters,
            'p_district_id': query.districtId,
            'p_max_price_cents': query.maxPriceCents,
            'p_needs_jacuzzi': query.needsJacuzzi,
            'p_needs_parking': query.needsParking,
          },
        );
        return [
          for (final row in rows.cast<Map<String, dynamic>>())
            LodgingResult.fromJson(row, photoUrl: _photoUrl),
        ];
      });

  @override
  Future<PublicLodging> lodging(String lodgingId) => _guard(() async {
    final row = await _client
        .from('lodgings')
        .select(
          'id, name, description, address, address_reference, latitude, '
          'longitude, has_parking, has_wifi, districts(name), '
          'lodging_photos(storage_path, sort_order)',
        )
        .eq('id', lodgingId)
        .eq('status', 'published')
        .maybeSingle();
    if (row == null) {
      throw const ExploreFailure(ExploreFailureReason.notFound);
    }
    final photos =
        ((row['lodging_photos'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .toList()
          ..sort(
            (a, b) =>
                (a['sort_order'] as num).compareTo(b['sort_order'] as num),
          );
    return PublicLodging(
      id: row['id'] as String,
      name: row['name'] as String,
      description: (row['description'] as String?) ?? '',
      districtName: switch (row['districts']) {
        {'name': final String name} => name,
        _ => '',
      },
      address: row['address'] as String,
      addressReference: (row['address_reference'] as String?) ?? '',
      location: LatLng(
        (row['latitude'] as num).toDouble(),
        (row['longitude'] as num).toDouble(),
      ),
      hasParking: (row['has_parking'] as bool?) ?? false,
      hasWifi: (row['has_wifi'] as bool?) ?? false,
      photoUrls: [
        for (final p in photos) _photoUrl(p['storage_path'] as String),
      ],
    );
  });

  @override
  Future<List<OfferRoomType>> offer(
    String lodgingId,
    DateTime arrival,
    int blockHours,
  ) => _guard(() async {
    final rows = await _client.rpc<List<dynamic>>(
      'get_lodging_offer',
      params: {
        'p_lodging_id': lodgingId,
        'p_arrival': arrival.toUtc().toIso8601String(),
        'p_block_hours': blockHours,
      },
    );
    return [
      for (final row in rows.cast<Map<String, dynamic>>())
        OfferRoomType.fromJson(row),
    ];
  });

  @override
  Future<List<Photo>> roomTypePhotos(String roomTypeId) => _guard(() async {
    final rows = await _client
        .from('room_type_photos')
        .select('id, kind, storage_path')
        .eq('room_type_id', roomTypeId)
        .order('sort_order', ascending: true)
        .order('created_at', ascending: true);
    return [
      for (final r in rows)
        Photo(
          id: r['id'] as String,
          storagePath: r['storage_path'] as String,
          url: _photoUrl(r['storage_path'] as String),
          kind: PhotoKind.fromDb(r['kind'] as String),
        ),
    ];
  });

  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on ExploreFailure {
      rethrow;
    } on sb.PostgrestException catch (error) {
      throw ExploreFailure(switch (error.message) {
        'arrival_out_of_range' => ExploreFailureReason.arrivalOutOfRange,
        'lodging_not_found' => ExploreFailureReason.notFound,
        _ => ExploreFailureReason.unknown,
      }, '${error.code}: ${error.message}');
    } on Exception catch (error) {
      throw ExploreFailure(ExploreFailureReason.network, '$error');
    }
  }
}
