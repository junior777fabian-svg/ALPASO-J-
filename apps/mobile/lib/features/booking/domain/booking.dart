import 'package:latlong2/latlong.dart';

enum BookingStatus {
  pendingPayment,
  confirmed,
  checkedIn,
  completed,
  cancelled,
  expired,
  noShow;

  static BookingStatus fromDb(String value) => switch (value) {
    'pending_payment' => pendingPayment,
    'confirmed' => confirmed,
    'checked_in' => checkedIn,
    'completed' => completed,
    'cancelled' => cancelled,
    'expired' => expired,
    _ => noShow,
  };

  /// Todavía cuenta: se muestra arriba en "Mis reservas".
  bool get isActive =>
      this == pendingPayment || this == confirmed || this == checkedIn;
}

/// Un extra de la carta, para elegir al reservar.
class MenuItem {
  const MenuItem({
    required this.productId,
    required this.name,
    required this.priceCents,
    required this.category,
  });

  final String productId;
  final String name;
  final int priceCents;
  final String category;
}

class QuoteLine {
  const QuoteLine({
    required this.productId,
    required this.name,
    required this.unitPriceCents,
    required this.quantity,
  });

  final String productId;
  final String name;
  final int unitPriceCents;
  final int quantity;

  int get subtotalCents => unitPriceCents * quantity;
}

/// Total calculado por el servidor.
class Quote {
  const Quote({
    required this.roomPriceCents,
    required this.extrasCents,
    required this.totalCents,
    this.lines = const [],
  });

  factory Quote.fromJson(Map<String, dynamic> json) => Quote(
    roomPriceCents: (json['room_price_cents'] as num).toInt(),
    extrasCents: (json['extras_cents'] as num).toInt(),
    totalCents: (json['total_cents'] as num).toInt(),
    lines: [
      for (final e
          in ((json['extras'] as List?) ?? const [])
              .cast<Map<String, dynamic>>())
        QuoteLine(
          productId: e['product_id'] as String,
          name: e['name'] as String,
          unitPriceCents: (e['unit_price_cents'] as num).toInt(),
          quantity: (e['quantity'] as num).toInt(),
        ),
    ],
  );

  final int roomPriceCents;
  final int extrasCents;
  final int totalCents;
  final List<QuoteLine> lines;
}

/// Lo que devuelve create_booking.
class CreatedBooking {
  const CreatedBooking({
    required this.bookingId,
    required this.code,
    required this.totalCents,
    this.holdExpiresAt,
  });

  final String bookingId;
  final String code;
  final int totalCents;
  final DateTime? holdExpiresAt;
}

/// Un cobro abierto en el conector activo.
class PaymentSession {
  const PaymentSession({
    required this.paymentId,
    required this.provider,
    required this.amountCents,
    this.holdExpiresAt,
  });

  final String paymentId;
  final String provider;
  final int amountCents;
  final DateTime? holdExpiresAt;

  bool get isDemo => provider == 'demo';
}

/// Una reserva, como la ve su cliente.
class Booking {
  const Booking({
    required this.id,
    required this.code,
    required this.status,
    required this.lodgingId,
    required this.lodgingName,
    required this.address,
    required this.location,
    required this.roomTypeName,
    required this.blockHours,
    required this.arrival,
    required this.departure,
    required this.totalCents,
    this.items = const [],
    this.holdExpiresAt,
    this.paidAt,
    this.refundCents,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    final lodging = (json['lodgings'] as Map<String, dynamic>?) ?? const {};
    final refunds = ((json['refunds'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();
    return Booking(
      id: json['id'] as String,
      code: json['code'] as String,
      status: BookingStatus.fromDb(json['status'] as String),
      lodgingId: json['lodging_id'] as String,
      lodgingName: (lodging['name'] as String?) ?? '',
      address: (lodging['address'] as String?) ?? '',
      location: LatLng(
        (lodging['latitude'] as num?)?.toDouble() ?? 0,
        (lodging['longitude'] as num?)?.toDouble() ?? 0,
      ),
      roomTypeName: switch (json['room_types']) {
        {'name': final String name} => name,
        _ => '',
      },
      blockHours: (json['block_hours'] as num).toInt(),
      arrival: DateTime.parse(json['arrival_at'] as String).toLocal(),
      departure: DateTime.parse(json['departure_at'] as String).toLocal(),
      totalCents: (json['total_cents'] as num).toInt(),
      holdExpiresAt: switch (json['hold_expires_at']) {
        final String v => DateTime.parse(v).toLocal(),
        _ => null,
      },
      paidAt: switch (json['paid_at']) {
        final String v => DateTime.parse(v).toLocal(),
        _ => null,
      },
      refundCents: refunds.isEmpty
          ? null
          : refunds.fold<int>(
              0,
              (sum, r) => sum + (r['amount_cents'] as num).toInt(),
            ),
      items: [
        for (final i
            in ((json['booking_items'] as List?) ?? const [])
                .cast<Map<String, dynamic>>())
          QuoteLine(
            productId: i['product_id'] as String,
            name: i['name'] as String,
            unitPriceCents: (i['unit_price_cents'] as num).toInt(),
            quantity: (i['quantity'] as num).toInt(),
          ),
      ],
    );
  }

  final String id;
  final String code;
  final BookingStatus status;
  final String lodgingId;
  final String lodgingName;
  final String address;
  final LatLng location;
  final String roomTypeName;
  final int blockHours;
  final DateTime arrival;
  final DateTime departure;
  final int totalCents;
  final List<QuoteLine> items;
  final DateTime? holdExpiresAt;
  final DateTime? paidAt;
  final int? refundCents;

  /// La regla de reembolso del servidor, para avisar antes de cancelar.
  bool canCancelWithRefund(DateTime now) {
    if (status == BookingStatus.pendingPayment) return true;
    if (status != BookingStatus.confirmed) return false;
    final deadline = arrival.subtract(const Duration(hours: 1));
    if (!now.isAfter(deadline)) return true;
    final paid = paidAt;
    return paid != null &&
        paid.isAfter(deadline) &&
        !now.isAfter(paid.add(const Duration(minutes: 5)));
  }

  /// Columnas que pide la app.
  static const columns =
      'id, code, status, lodging_id, block_hours, arrival_at, departure_at, '
      'total_cents, hold_expires_at, paid_at, '
      'lodgings(name, address, latitude, longitude), room_types(name), '
      'booking_items(product_id, name, unit_price_cents, quantity), '
      'refunds(amount_cents)';
}
