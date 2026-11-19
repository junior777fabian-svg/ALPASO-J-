@Tags(['server'])
library;

import 'package:alpaso/features/auth/data/auth_repository.dart';
import 'package:alpaso/features/business/data/business_repository.dart';
import 'package:alpaso/features/business/domain/business_failure.dart';
import 'package:alpaso/features/business/domain/lodging.dart';
import 'package:alpaso/features/profile/data/profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _url = String.fromEnvironment('SUPABASE_URL');
const _key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

SupabaseClient _phone() => SupabaseClient(
  _url,
  _key,
  authOptions: const AuthClientOptions(
    autoRefreshToken: false,
    authFlowType: AuthFlowType.implicit,
  ),
);

Matcher _failsWith(BusinessFailureReason reason) =>
    throwsA(isA<BusinessFailure>().having((f) => f.reason, 'reason', reason));

const _draft = LodgingDraft(
  name: 'Hostal Prueba',
  districtId: 21,
  address: 'Av. Larco 123',
  addressReference: 'Frente al parque',
  latitude: -12.1211,
  longitude: -77.0297,
  hasWifi: true,
  cleaningMinutes: 20,
);

void main() {
  final run = DateTime.now().microsecondsSinceEpoch;

  group(
    'modo negocio contra el servidor',
    skip: _url.isEmpty ? 'sin servidor' : null,
    () {
      late SupabaseClient ana;
      late SupabaseBusinessRepository business;
      late String lodgingId;

      setUpAll(() async {
        ana = _phone();
        await SupabaseAuthRepository(ana.auth).signUp(
          email: 'duena.$run@example.test',
          password: 'Clave-de-prueba-1',
          fullName: 'Ana',
        );
        business = SupabaseBusinessRepository(ana);
      });

      tearDownAll(() async => ana.dispose());

      test('los distritos llegan ordenados', () async {
        final districts = await business.districts();
        expect(districts, hasLength(50));
        expect(districts.first.name, 'Ancón');
      });

      test('sin mayoría de edad confirmada no se registra', () async {
        await expectLater(
          business.createLodging(_draft),
          _failsWith(BusinessFailureReason.adultNotConfirmed),
        );
      });

      test('registra el hostal con todos sus datos', () async {
        await SupabaseProfileRepository(ana).confirmAdult();
        lodgingId = await business.createLodging(_draft);

        final lodging = await business.lodging(lodgingId);
        expect(lodging.name, 'Hostal Prueba');
        expect(lodging.districtName, 'Miraflores');
        expect(lodging.status, LodgingStatus.draft);
        expect(lodging.draft.hasWifi, isTrue);
        expect(lodging.draft.cleaningMinutes, 20);
        expect(lodging.draft.latitude, closeTo(-12.1211, 1e-9));

        final mine = await business.myLodgings();
        expect(mine.map((l) => l.id), [lodgingId]);
      });

      test('edita sus datos', () async {
        await business.updateLodging(
          lodgingId,
          const LodgingDraft(
            name: 'Hostal Prueba 2',
            districtId: 44,
            address: 'Jr. Callao 1',
            latitude: -12.05,
            longitude: -77.13,
            hasParking: true,
          ),
        );
        final lodging = await business.lodging(lodgingId);
        expect(lodging.name, 'Hostal Prueba 2');
        expect(lodging.districtName, 'Callao');
        expect(lodging.draft.hasParking, isTrue);
      });

      test('una ubicación fuera de Lima la rechaza el servidor', () async {
        await expectLater(
          business.updateLodging(
            lodgingId,
            const LodgingDraft(
              name: 'Hostal Prueba 2',
              districtId: 44,
              address: 'Jr. Callao 1',
              latitude: -16.4,
              longitude: -71.5,
            ),
          ),
          _failsWith(BusinessFailureReason.invalidData),
        );
      });

      test('sin cuartos no se envía a revisión', () async {
        await expectLater(
          business.submitLodging(lodgingId),
          _failsWith(BusinessFailureReason.lodgingIncomplete),
        );
      });

      test('otra cuenta no ve ni edita el hostal', () async {
        final luis = _phone();
        addTearDown(luis.dispose);
        await SupabaseAuthRepository(luis.auth).signUp(
          email: 'otro.$run@example.test',
          password: 'Clave-de-prueba-1',
          fullName: 'Luis',
        );
        final other = SupabaseBusinessRepository(luis);
        expect(await other.myLodgings(), isEmpty);
        await expectLater(
          other.updateLodging(lodgingId, _draft),
          throwsA(isA<BusinessFailure>()),
        );
        await expectLater(
          other.submitLodging(lodgingId),
          _failsWith(BusinessFailureReason.notOwner),
        );
      });
    },
  );
}
