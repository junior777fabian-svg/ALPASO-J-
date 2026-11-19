/// Reglas de la plataforma que el modo negocio necesita conocer. Vienen de
/// `get_public_settings`.
class PlatformRules {
  const PlatformRules({required this.blockHours, required this.alcoholEnabled});

  factory PlatformRules.fromSettings(Map<String, dynamic> settings) =>
      PlatformRules(
        blockHours: [
          for (final h
              in (settings['booking_blocks_hours'] as List?) ?? const [])
            (h as num).toInt(),
        ],
        alcoholEnabled: settings['alcohol_enabled'] == true,
      );

  /// Bloques de horas que se pueden vender, por ejemplo [4, 6, 8, 12, 24].
  final List<int> blockHours;
  final bool alcoholEnabled;
}

/// Tipo de cuarto con sus tarifas y sus cuartos.
class RoomTypeDraft {
  const RoomTypeDraft({
    required this.name,
    this.description = '',
    this.maxGuests = 2,
    this.hasJacuzzi = false,
    this.hasTv = false,
    this.hasAirConditioning = false,
    this.isActive = true,
    this.rates = const {},
    this.rooms = const [],
  });

  final String name;
  final String description;
  final int maxGuests;
  final bool hasJacuzzi;
  final bool hasTv;
  final bool hasAirConditioning;
  final bool isActive;

  /// Horas → céntimos.
  final Map<int, int> rates;

  /// Números de cuarto: "201", "202"…
  final List<String> rooms;
}

class RoomType {
  const RoomType({required this.id, required this.draft});

  factory RoomType.fromJson(Map<String, dynamic> json) {
    final rates = <int, int>{
      for (final r
          in ((json['rates'] as List?) ?? const [])
              .cast<Map<String, dynamic>>())
        (r['block_hours'] as num).toInt(): (r['price_cents'] as num).toInt(),
    };
    final rooms = [
      for (final r
          in ((json['rooms'] as List?) ?? const [])
              .cast<Map<String, dynamic>>())
        r['label'] as String,
    ]..sort();
    return RoomType(
      id: json['id'] as String,
      draft: RoomTypeDraft(
        name: json['name'] as String,
        description: (json['description'] as String?) ?? '',
        maxGuests: (json['max_guests'] as num?)?.toInt() ?? 2,
        hasJacuzzi: (json['has_jacuzzi'] as bool?) ?? false,
        hasTv: (json['has_tv'] as bool?) ?? false,
        hasAirConditioning: (json['has_air_conditioning'] as bool?) ?? false,
        isActive: (json['is_active'] as bool?) ?? true,
        rates: rates,
        rooms: rooms,
      ),
    );
  }

  final String id;
  final RoomTypeDraft draft;

  /// Listo para publicarse: activo, con precio y con al menos un cuarto.
  bool get isReady =>
      draft.isActive && draft.rates.isNotEmpty && draft.rooms.isNotEmpty;
}

enum ProductCategory {
  drinks('drinks'),
  snacks('snacks'),
  personalCare('personal_care'),
  alcohol('alcohol'),
  other('other');

  const ProductCategory(this.db);

  final String db;

  static ProductCategory fromDb(String value) =>
      values.firstWhere((c) => c.db == value, orElse: () => other);
}

class ProductDraft {
  const ProductDraft({
    required this.name,
    required this.category,
    required this.priceCents,
    this.description = '',
    this.isAvailable = true,
  });

  final String name;
  final String description;
  final ProductCategory category;
  final int priceCents;
  final bool isAvailable;

  Map<String, dynamic> toJson() => {
    'name': name.trim(),
    'description': description.trim(),
    'category': category.db,
    'price_cents': priceCents,
    'is_available': isAvailable,
  };
}

class Product {
  const Product({required this.id, required this.draft});

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id'] as String,
    draft: ProductDraft(
      name: json['name'] as String,
      description: (json['description'] as String?) ?? '',
      category: ProductCategory.fromDb(json['category'] as String),
      priceCents: (json['price_cents'] as num).toInt(),
      isAvailable: (json['is_available'] as bool?) ?? true,
    ),
  );

  final String id;
  final ProductDraft draft;
}
