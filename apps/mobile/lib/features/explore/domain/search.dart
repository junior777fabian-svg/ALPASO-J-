import 'package:latlong2/latlong.dart';

/// Centro de Lima, para cuando no se conoce la ubicación.
const limaCenter = LatLng(-12.0464, -77.0428);

/// Lo que el cliente busca. La hora de llegada nula significa "ahora".
class SearchQuery {
  const SearchQuery({
    this.blockHours = 4,
    this.arrival,
    this.center = limaCenter,
    this.nearMe = false,
    this.districtId,
    this.maxPriceCents,
    this.needsJacuzzi = false,
    this.needsParking = false,
  });

  final int blockHours;
  final DateTime? arrival;
  final LatLng center;

  /// El centro es la ubicación del teléfono: se busca más cerca.
  final bool nearMe;
  final int? districtId;
  final int? maxPriceCents;
  final bool needsJacuzzi;
  final bool needsParking;

  /// 5 km alrededor del cliente; sin su ubicación, toda Lima.
  int get radiusMeters => nearMe ? 5000 : 30000;

  /// La llegada que se envía al servidor.
  DateTime arrivalOrNow(DateTime now) => arrival ?? now;

  int get activeFilters =>
      (districtId != null ? 1 : 0) +
      (maxPriceCents != null ? 1 : 0) +
      (needsJacuzzi ? 1 : 0) +
      (needsParking ? 1 : 0);

  SearchQuery copyWith({
    int? blockHours,
    DateTime? Function()? arrival,
    LatLng? center,
    bool? nearMe,
    int? Function()? districtId,
    int? Function()? maxPriceCents,
    bool? needsJacuzzi,
    bool? needsParking,
  }) => SearchQuery(
    blockHours: blockHours ?? this.blockHours,
    arrival: arrival != null ? arrival() : this.arrival,
    center: center ?? this.center,
    nearMe: nearMe ?? this.nearMe,
    districtId: districtId != null ? districtId() : this.districtId,
    maxPriceCents: maxPriceCents != null ? maxPriceCents() : this.maxPriceCents,
    needsJacuzzi: needsJacuzzi ?? this.needsJacuzzi,
    needsParking: needsParking ?? this.needsParking,
  );
}

/// Un hostal con al menos un cuarto libre para la búsqueda.
class LodgingResult {
  const LodgingResult({
    required this.lodgingId,
    required this.name,
    required this.districtName,
    required this.address,
    required this.location,
    required this.distanceMeters,
    required this.minPriceCents,
    required this.availableRoomTypes,
    this.addressReference = '',
    this.hasParking = false,
    this.hasWifi = false,
    this.hasJacuzzi = false,
    this.coverPhotoUrl,
  });

  factory LodgingResult.fromJson(
    Map<String, dynamic> json, {
    required String Function(String path) photoUrl,
  }) => LodgingResult(
    lodgingId: json['lodging_id'] as String,
    name: json['name'] as String,
    districtName: json['district_name'] as String,
    address: json['address'] as String,
    addressReference: (json['address_reference'] as String?) ?? '',
    location: LatLng(
      (json['latitude'] as num).toDouble(),
      (json['longitude'] as num).toDouble(),
    ),
    distanceMeters: (json['distance_m'] as num).toInt(),
    minPriceCents: (json['min_price_cents'] as num).toInt(),
    availableRoomTypes: (json['available_room_types'] as num).toInt(),
    hasParking: (json['has_parking'] as bool?) ?? false,
    hasWifi: (json['has_wifi'] as bool?) ?? false,
    hasJacuzzi: (json['has_jacuzzi'] as bool?) ?? false,
    coverPhotoUrl: switch (json['cover_photo_path']) {
      final String path => photoUrl(path),
      _ => null,
    },
  );

  final String lodgingId;
  final String name;
  final String districtName;
  final String address;
  final String addressReference;
  final LatLng location;
  final int distanceMeters;
  final int minPriceCents;
  final int availableRoomTypes;
  final bool hasParking;
  final bool hasWifi;
  final bool hasJacuzzi;
  final String? coverPhotoUrl;
}

/// Ficha pública de un hostal publicado.
class PublicLodging {
  const PublicLodging({
    required this.id,
    required this.name,
    required this.districtName,
    required this.address,
    required this.location,
    this.addressReference = '',
    this.description = '',
    this.hasParking = false,
    this.hasWifi = false,
    this.photoUrls = const [],
  });

  final String id;
  final String name;
  final String districtName;
  final String address;
  final String addressReference;
  final String description;
  final LatLng location;
  final bool hasParking;
  final bool hasWifi;
  final List<String> photoUrls;
}

/// Un tipo de cuarto en la ficha pública, con su precio para la búsqueda.
class OfferRoomType {
  const OfferRoomType({
    required this.roomTypeId,
    required this.name,
    required this.isAvailable,
    this.description = '',
    this.maxGuests = 2,
    this.hasJacuzzi = false,
    this.hasTv = false,
    this.hasAirConditioning = false,
    this.priceCents,
    this.rates = const {},
  });

  factory OfferRoomType.fromJson(Map<String, dynamic> json) => OfferRoomType(
    roomTypeId: json['room_type_id'] as String,
    name: json['name'] as String,
    description: (json['description'] as String?) ?? '',
    maxGuests: (json['max_guests'] as num?)?.toInt() ?? 2,
    hasJacuzzi: (json['has_jacuzzi'] as bool?) ?? false,
    hasTv: (json['has_tv'] as bool?) ?? false,
    hasAirConditioning: (json['has_air_conditioning'] as bool?) ?? false,
    priceCents: (json['price_cents'] as num?)?.toInt(),
    isAvailable: (json['is_available'] as bool?) ?? false,
    rates: {
      for (final e
          in ((json['rates'] as Map<String, dynamic>?) ?? const {}).entries)
        int.parse(e.key): (e.value as num).toInt(),
    },
  );

  final String roomTypeId;
  final String name;
  final String description;
  final int maxGuests;
  final bool hasJacuzzi;
  final bool hasTv;
  final bool hasAirConditioning;

  /// Precio del bloque buscado; nulo si este tipo no lo vende.
  final int? priceCents;
  final bool isAvailable;
  final Map<int, int> rates;

  /// Se puede reservar para la búsqueda actual.
  bool get isBookable => isAvailable && priceCents != null;
}
