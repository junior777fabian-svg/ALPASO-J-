import 'package:alpaso/features/booking/data/booking_repository.dart';
import 'package:alpaso/features/booking/domain/booking.dart';
import 'package:alpaso/features/booking/domain/booking_failure.dart';
import 'package:latlong2/latlong.dart';

/// Reservas en memoria, con las reglas del servidor que prueban las
/// pantallas.
class FakeBookingServer implements BookingRepository {
  FakeBookingServer({DateTime Function()? clock})
    : _clock = clock ?? (() => DateTime(2026, 11, 19, 20));

  final DateTime Function() _clock;
  final bookings = <String, Booking>{};
  final menus = <String, List<MenuItem>>{};
  final payments = <String, String>{}; // pago → reserva
  final idempotencyKeys = <String>[];
  int roomPriceCents = 4500;
  BookingFailureReason? nextFailure;
  int _ids = 0;

  void _maybeFail() {
    final reason = nextFailure;
    if (reason != null) {
      nextFailure = null;
      throw BookingFailure(reason, 'falla de prueba');
    }
  }

  /// Una reserva ya existente.
  Booking seed({
    BookingStatus status = BookingStatus.confirmed,
    DateTime? arrival,
    DateTime? paidAt,
    String lodgingName = 'Hostal Sol',
  }) {
    final at = arrival ?? _clock().add(const Duration(hours: 3));
    final booking = Booking(
      id: 'b${_ids++}',
      code: 'K7X9QA',
      status: status,
      lodgingId: 'l1',
      lodgingName: lodgingName,
      address: 'Av. Larco 123',
      location: const LatLng(-12.12, -77.03),
      roomTypeName: 'Suite',
      blockHours: 4,
      arrival: at,
      departure: at.add(const Duration(hours: 4)),
      totalCents: 4500,
      paidAt: paidAt ?? (status == BookingStatus.confirmed ? _clock() : null),
    );
    bookings[booking.id] = booking;
    return booking;
  }

  Booking _with(Booking b, BookingStatus status, {int? refund}) => Booking(
    id: b.id,
    code: b.code,
    status: status,
    lodgingId: b.lodgingId,
    lodgingName: b.lodgingName,
    address: b.address,
    location: b.location,
    roomTypeName: b.roomTypeName,
    blockHours: b.blockHours,
    arrival: b.arrival,
    departure: b.departure,
    totalCents: b.totalCents,
    items: b.items,
    paidAt: status == BookingStatus.confirmed ? _clock() : b.paidAt,
    holdExpiresAt: b.holdExpiresAt,
    refundCents: refund ?? b.refundCents,
  );

  Quote _quote(String lodgingId, Map<String, int> items) {
    final menu = menus[lodgingId] ?? const <MenuItem>[];
    final lines = [
      for (final e in items.entries)
        if (e.value > 0)
          QuoteLine(
            productId: e.key,
            name: menu.firstWhere((m) => m.productId == e.key).name,
            unitPriceCents: menu
                .firstWhere((m) => m.productId == e.key)
                .priceCents,
            quantity: e.value,
          ),
    ];
    final extras = lines.fold<int>(0, (s, l) => s + l.subtotalCents);
    return Quote(
      roomPriceCents: roomPriceCents,
      extrasCents: extras,
      totalCents: roomPriceCents + extras,
      lines: lines,
    );
  }

  @override
  Future<List<MenuItem>> menu(String lodgingId) async =>
      menus[lodgingId] ?? const [];

  @override
  Future<Quote> quote({
    required String roomTypeId,
    required DateTime arrival,
    required int blockHours,
    required Map<String, int> items,
  }) async => _quote('l1', items);

  @override
  Future<CreatedBooking> create({
    required String roomTypeId,
    required DateTime arrival,
    required int blockHours,
    required Map<String, int> items,
    required String idempotencyKey,
  }) async {
    _maybeFail();
    idempotencyKeys.add(idempotencyKey);
    final quote = _quote('l1', items);
    final booking = Booking(
      id: 'b${_ids++}',
      code: 'K7X9QA',
      status: BookingStatus.pendingPayment,
      lodgingId: 'l1',
      lodgingName: 'Hostal Sol',
      address: 'Av. Larco 123',
      location: const LatLng(-12.12, -77.03),
      roomTypeName: 'Suite',
      blockHours: blockHours,
      arrival: arrival,
      departure: arrival.add(Duration(hours: blockHours)),
      totalCents: quote.totalCents,
      items: quote.lines,
      holdExpiresAt: _clock().add(const Duration(minutes: 10)),
    );
    bookings[booking.id] = booking;
    return CreatedBooking(
      bookingId: booking.id,
      code: booking.code,
      totalCents: booking.totalCents,
      holdExpiresAt: booking.holdExpiresAt,
    );
  }

  @override
  Future<PaymentSession> startPayment(String bookingId) async {
    _maybeFail();
    final booking = bookings[bookingId]!;
    final id = 'pay${_ids++}';
    payments[id] = bookingId;
    return PaymentSession(
      paymentId: id,
      provider: 'demo',
      amountCents: booking.totalCents,
      holdExpiresAt: booking.holdExpiresAt,
    );
  }

  @override
  Future<String> completeDemoPayment(
    String paymentId, {
    required bool approved,
  }) async {
    _maybeFail();
    if (!approved) return 'failed';
    final id = payments[paymentId]!;
    bookings[id] = _with(bookings[id]!, BookingStatus.confirmed);
    return 'paid';
  }

  @override
  Future<Booking> booking(String id) async {
    _maybeFail();
    return bookings[id]!;
  }

  @override
  Future<List<Booking>> myBookings() async {
    _maybeFail();
    return bookings.values.toList().reversed.toList();
  }

  @override
  Future<int> cancel(String bookingId, {String reason = ''}) async {
    _maybeFail();
    final b = bookings[bookingId]!;
    if (b.status == BookingStatus.confirmed &&
        !b.canCancelWithRefund(_clock())) {
      throw const BookingFailure(BookingFailureReason.cancelWindowClosed);
    }
    final refund = b.status == BookingStatus.confirmed ? b.totalCents : 0;
    bookings[bookingId] = _with(
      b,
      BookingStatus.cancelled,
      refund: refund == 0 ? null : refund,
    );
    return refund;
  }
}
