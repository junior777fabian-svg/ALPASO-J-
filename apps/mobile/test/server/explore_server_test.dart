@Tags(['server'])
library;

import 'package:alpaso/features/auth/data/auth_repository.dart';
import 'package:alpaso/features/business/data/business_repository.dart';
import 'package:alpaso/features/business/domain/lodging.dart';
import 'package:alpaso/features/business/domain/offer.dart';
import 'package:alpaso/features/business/domain/photo.dart';
import 'package:alpaso/features/explore/data/explore_repository.dart';
import 'package:alpaso/features/explore/domain/search.dart';
import 'package:alpaso/features/profile/data/profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _url = String.fromEnvironment('SUPABASE_URL');
const _key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
// Llave de servidor local, desde config/server.admin.local.json.
const _secret = String.fromEnvironment('SUPABASE_SECRET_KEY');

SupabaseClient _client([String key = _key]) => SupabaseClient(
  _url,
  key,
  authOptions: const AuthClientOptions(
    autoRefreshToken: false,
    authFlowType: AuthFlowType.implicit,
  ),
);

void main() {
  final run = DateTime.now().microsecondsSinceEpoch;
  // Un punto propio de esta corrida, lejos de los hostales de otras pruebas.
  final spot = LatLng(-12.0 - (run % 400) / 1000, -77.0 - (run % 300) / 1000);

  group(
    'Explorar contra el servidor',
    skip: _url.isEmpty || _secret.isEmpty ? 'sin servidor o sin llave' : null,
    () {
      late SupabaseClient owner;
      late SupabaseClient admin;
      late SupabaseExploreRepository explore;
      late String lodgingId;
      late String roomTypeId;
      final arrival = DateTime.now().add(const Duration(hours: 3));

      setUpAll(() async {
        owner = _client();
        admin = _client(_secret);
        explore = SupabaseExploreRepository(_client());

        await SupabaseAuthRepository(owner.auth).signUp(
          email: 'explora.$run@example.test',
          password: 'Clave-de-prueba-1',
          fullName: 'Dueña',
        );
        await SupabaseProfileRepository(owner).confirmAdult();
        final business = SupabaseBusinessRepository(owner);
        lodgingId = await business.createLodging(
          LodgingDraft(
            name: 'Hostal Explora $run',
            districtId: 21,
            address: 'Calle Prueba 1',
            latitude: spot.latitude,
            longitude: spot.longitude,
            hasParking: true,
          ),
        );
        roomTypeId = await business.saveRoomType(
          lodgingId,
          const RoomTypeDraft(
            name: 'Suite',
            hasJacuzzi: true,
            rates: {4: 4500, 12: 9000},
            rooms: ['201'],
          ),
        );
        // Un PNG de 1×1.
        const png = PickedPhoto(
          mimeType: 'image/png',
          bytes: [
            137,
            80,
            78,
            71,
            13,
            10,
            26,
            10,
            0,
            0,
            0,
            13,
            73,
            72,
            68,
            82,
            0,
            0,
            0,
            1,
            0,
            0,
            0,
            1,
            8,
            2,
            0,
            0,
            0,
            144,
            119,
            83,
            222,
            0,
            0,
            0,
            12,
            73,
            68,
            65,
            84,
            120,
            156,
            99,
            248,
            207,
            192,
            0,
            0,
            3,
            1,
            1,
            0,
            201,
            254,
            146,
            239,
            0,
            0,
            0,
            0,
            73,
            69,
            78,
            68,
            174,
            66,
            96,
            130,
          ],
        );
        await business.addLodgingPhoto(lodgingId, png);
        for (final kind in [
          PhotoKind.room,
          PhotoKind.bathroom,
          PhotoKind.jacuzzi,
        ]) {
          await business.addRoomTypePhoto(lodgingId, roomTypeId, kind, png);
        }
        await business.submitLodging(lodgingId);
        await admin.rpc<String>(
          'admin_review_lodging',
          params: {'p_lodging_id': lodgingId, 'p_approve': true},
        );
      });

      tearDownAll(() async {
        await owner.dispose();
        await admin.dispose();
      });

      SearchQuery query({int hours = 4, bool jacuzzi = false}) => SearchQuery(
        blockHours: hours,
        arrival: arrival,
        center: spot,
        nearMe: true,
        needsJacuzzi: jacuzzi,
      );

      test('sin cuenta encuentra el hostal publicado con su precio', () async {
        final results = await explore.search(query(), DateTime.now());
        final mine = results.where((r) => r.lodgingId == lodgingId).single;
        expect(mine.minPriceCents, 4500);
        expect(mine.distanceMeters, lessThan(10));
        expect(mine.hasJacuzzi, isTrue);
        expect(mine.coverPhotoUrl, contains('lodging-photos'));
      });

      test('el precio cambia con el bloque', () async {
        final results = await explore.search(query(hours: 12), DateTime.now());
        expect(
          results.where((r) => r.lodgingId == lodgingId).single.minPriceCents,
          9000,
        );
      });

      test('la ficha y la oferta', () async {
        final lodging = await explore.lodging(lodgingId);
        expect(lodging.districtName, 'Miraflores');
        expect(lodging.photoUrls, hasLength(1));

        final offer = await explore.offer(lodgingId, arrival, 4);
        expect(offer.single.priceCents, 4500);
        expect(offer.single.isBookable, isTrue);
        expect(offer.single.rates, {4: 4500, 12: 9000});

        final photos = await explore.roomTypePhotos(roomTypeId);
        expect(photos.map((p) => p.kind).toSet(), {
          PhotoKind.room,
          PhotoKind.bathroom,
          PhotoKind.jacuzzi,
        });
      });

      test('ocupado su único cuarto, desaparece de la búsqueda', () async {
        final room = await admin
            .from('rooms')
            .select('id')
            .eq('room_type_id', roomTypeId)
            .single();
        await admin.from('room_occupancy').insert({
          'room_id': room['id'],
          'lodging_id': lodgingId,
          'kind': 'walk_in',
          'period':
              '[${arrival.subtract(const Duration(minutes: 30)).toUtc().toIso8601String()},'
              '${arrival.add(const Duration(hours: 2)).toUtc().toIso8601String()})',
        });

        final results = await explore.search(query(), DateTime.now());
        expect(results.where((r) => r.lodgingId == lodgingId), isEmpty);
        final offer = await explore.offer(lodgingId, arrival, 4);
        expect(offer.single.isAvailable, isFalse);
      });

      test('una llegada fuera de los 7 días se rechaza', () async {
        await expectLater(
          explore.search(
            SearchQuery(
              arrival: DateTime.now().add(const Duration(days: 9)),
              center: spot,
            ),
            DateTime.now(),
          ),
          throwsA(
            isA<ExploreFailure>().having(
              (f) => f.reason,
              'reason',
              ExploreFailureReason.arrivalOutOfRange,
            ),
          ),
        );
      });
    },
  );
}
