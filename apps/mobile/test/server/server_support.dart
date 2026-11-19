import 'package:alpaso/features/auth/data/auth_repository.dart';
import 'package:alpaso/features/business/data/business_repository.dart';
import 'package:alpaso/features/business/domain/lodging.dart';
import 'package:alpaso/features/business/domain/offer.dart';
import 'package:alpaso/features/business/domain/photo.dart';
import 'package:alpaso/features/profile/data/profile_repository.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const serverUrl = String.fromEnvironment('SUPABASE_URL');
const publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

/// Llave de servidor local, desde config/server.admin.local.json.
const secretKey = String.fromEnvironment('SUPABASE_SECRET_KEY');

bool get hasAdminServer => serverUrl.isNotEmpty && secretKey.isNotEmpty;

/// Un cliente nuevo, como un teléfono distinto.
SupabaseClient phone([String key = publishableKey]) => SupabaseClient(
  serverUrl,
  key,
  authOptions: const AuthClientOptions(
    autoRefreshToken: false,
    authFlowType: AuthFlowType.implicit,
  ),
);

/// Crea una cuenta con mayoría de edad confirmada.
Future<SupabaseClient> adultAccount(String email) async {
  final client = phone();
  await SupabaseAuthRepository(client.auth)
      .signUp(email: email, password: 'Clave-de-prueba-1', fullName: 'Prueba');
  await SupabaseProfileRepository(client).confirmAdult();
  return client;
}

const _png = PickedPhoto(
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

/// Publica un hostal con un tipo de cuarto y devuelve sus ids.
Future<({String lodgingId, String roomTypeId})> publishLodging({
  required SupabaseClient owner,
  required SupabaseClient admin,
  required String name,
  required LatLng spot,
  RoomTypeDraft roomType = const RoomTypeDraft(
    name: 'Suite',
    rates: {4: 4500, 12: 9000},
    rooms: ['201'],
  ),
}) async {
  final business = SupabaseBusinessRepository(owner);
  final lodgingId = await business.createLodging(
    LodgingDraft(
      name: name,
      districtId: 21,
      address: 'Calle Prueba 1',
      latitude: spot.latitude,
      longitude: spot.longitude,
    ),
  );
  final roomTypeId = await business.saveRoomType(lodgingId, roomType);
  await business.addLodgingPhoto(lodgingId, _png);
  for (final kind in [
    PhotoKind.room,
    PhotoKind.bathroom,
    if (roomType.hasJacuzzi) PhotoKind.jacuzzi,
  ]) {
    await business.addRoomTypePhoto(lodgingId, roomTypeId, kind, _png);
  }
  await business.submitLodging(lodgingId);
  await admin.rpc<String>(
    'admin_review_lodging',
    params: {'p_lodging_id': lodgingId, 'p_approve': true},
  );
  return (lodgingId: lodgingId, roomTypeId: roomTypeId);
}
