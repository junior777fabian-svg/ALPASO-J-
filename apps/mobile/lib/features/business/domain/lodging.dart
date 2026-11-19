/// Estado de revisión de un hostal. Lo cambia solo el servidor.
enum LodgingStatus {
  draft,
  pendingReview,
  published,
  rejected,
  suspended;

  static LodgingStatus fromDb(String value) => switch (value) {
    'pending_review' => pendingReview,
    'published' => published,
    'rejected' => rejected,
    'suspended' => suspended,
    _ => draft,
  };

  /// El dueño puede enviarlo a revisión.
  bool get canSubmit => this == draft || this == rejected;
}

class District {
  const District({
    required this.id,
    required this.name,
    required this.province,
  });

  factory District.fromJson(Map<String, dynamic> json) => District(
    id: json['id'] as int,
    name: json['name'] as String,
    province: json['province'] as String,
  );

  final int id;
  final String name;
  final String province;
}

/// Datos del hostal que escribe el dueño.
class LodgingDraft {
  const LodgingDraft({
    required this.name,
    required this.districtId,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.addressReference = '',
    this.description = '',
    this.hasParking = false,
    this.hasWifi = false,
    this.cleaningMinutes = 30,
  });

  final String name;
  final int districtId;
  final String address;
  final String addressReference;
  final double latitude;
  final double longitude;
  final String description;
  final bool hasParking;
  final bool hasWifi;
  final int cleaningMinutes;

  /// Columnas que el dueño puede escribir en `lodgings`.
  Map<String, dynamic> toUpdateJson() => {
    'name': name.trim(),
    'district_id': districtId,
    'address': address.trim(),
    'address_reference': addressReference.trim(),
    'latitude': latitude,
    'longitude': longitude,
    'description': description.trim(),
    'has_parking': hasParking,
    'has_wifi': hasWifi,
    'cleaning_minutes': cleaningMinutes,
  };
}

class Lodging {
  const Lodging({
    required this.id,
    required this.draft,
    required this.districtName,
    required this.status,
    this.reviewNote = '',
    this.isOwner = true,
  });

  factory Lodging.fromJson(Map<String, dynamic> json) => Lodging(
    id: json['id'] as String,
    // En "mis hostales" llega el rol de la cuenta; si no, se asume dueño
    // (la ficha la abre quien la administra).
    isOwner: switch (json['lodging_members']) {
      [{'role': final String role}, ...] => role == 'owner',
      _ => true,
    },
    districtName: switch (json['districts']) {
      {'name': final String name} => name,
      _ => '',
    },
    status: LodgingStatus.fromDb(json['status'] as String),
    reviewNote: (json['review_note'] as String?) ?? '',
    draft: LodgingDraft(
      name: json['name'] as String,
      districtId: json['district_id'] as int,
      address: json['address'] as String,
      addressReference: (json['address_reference'] as String?) ?? '',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      description: (json['description'] as String?) ?? '',
      hasParking: (json['has_parking'] as bool?) ?? false,
      hasWifi: (json['has_wifi'] as bool?) ?? false,
      cleaningMinutes: (json['cleaning_minutes'] as int?) ?? 30,
    ),
  );

  final String id;
  final LodgingDraft draft;
  final String districtName;
  final LodgingStatus status;

  /// Motivo del último rechazo, si lo hubo.
  final String reviewNote;

  /// La cuenta es dueña; si no, es recepcionista.
  final bool isOwner;

  String get name => draft.name;
}
