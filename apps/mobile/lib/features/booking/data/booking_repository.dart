import 'dart:convert';
import 'dart:math';

import 'package:alpaso/features/booking/domain/booking.dart';
import 'package:alpaso/features/booking/domain/booking_failure.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

abstract interface class BookingRepository {
  /// Extras disponibles de un hostal publicado.
  Future<List<MenuItem>> menu(String lodgingId);

  /// Total del servidor. [items]: producto → cantidad.
  Future<Quote> quote({
    required String roomTypeId,
    required DateTime arrival,
    required int blockHours,
    required Map<String, int> items,
  });

  Future<CreatedBooking> create({
    required String roomTypeId,
    required DateTime arrival,
    required int blockHours,
    required Map<String, int> items,
    required String idempotencyKey,
  });

  Future<PaymentSession> startPayment(String bookingId);

  /// La pasarela demo. Devuelve 'paid', 'failed' o 'refunded'.
  Future<String> completeDemoPayment(
    String paymentId, {
    required bool approved,
  });

  Future<Booking> booking(String id);

  /// Reservas de la cuenta, de la más reciente a la más antigua.
  Future<List<Booking>> myBookings();

  /// Devuelve lo reembolsado, en céntimos.
  Future<int> cancel(String bookingId, {String reason = ''});
}

/// Clave nueva para que reintentar una reserva no cree otra (uuid v4).
String newIdempotencyKey([Random? random]) {
  final r = random ?? Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}

class SupabaseBookingRepository implements BookingRepository {
  SupabaseBookingRepository(this._client);

  final sb.SupabaseClient _client;

  static const _cacheKey = 'my_bookings_cache_v1';

  List<Map<String, dynamic>> _itemsJson(Map<String, int> items) => [
    for (final e in items.entries)
      if (e.value > 0) {'product_id': e.key, 'quantity': e.value},
  ];

  @override
  Future<List<MenuItem>> menu(String lodgingId) => _guard(() async {
    final rows = await _client
        .from('products')
        .select('id, name, price_cents, category')
        .eq('lodging_id', lodgingId)
        .eq('is_available', true)
        .order('name', ascending: true);
    return [
      for (final r in rows)
        MenuItem(
          productId: r['id'] as String,
          name: r['name'] as String,
          priceCents: (r['price_cents'] as num).toInt(),
          category: r['category'] as String,
        ),
    ];
  });

  @override
  Future<Quote> quote({
    required String roomTypeId,
    required DateTime arrival,
    required int blockHours,
    required Map<String, int> items,
  }) => _guard(() async {
    final json = await _client.rpc<Map<String, dynamic>>(
      'get_quote',
      params: {
        'p_room_type_id': roomTypeId,
        'p_arrival': arrival.toUtc().toIso8601String(),
        'p_block_hours': blockHours,
        'p_items': _itemsJson(items),
      },
    );
    return Quote.fromJson(json);
  });

  @override
  Future<CreatedBooking> create({
    required String roomTypeId,
    required DateTime arrival,
    required int blockHours,
    required Map<String, int> items,
    required String idempotencyKey,
  }) => _guard(() async {
    final json = await _client.rpc<Map<String, dynamic>>(
      'create_booking',
      params: {
        'p_room_type_id': roomTypeId,
        'p_arrival': arrival.toUtc().toIso8601String(),
        'p_block_hours': blockHours,
        'p_items': _itemsJson(items),
        'p_idempotency_key': idempotencyKey,
      },
    );
    return CreatedBooking(
      bookingId: json['booking_id'] as String,
      code: json['code'] as String,
      totalCents: (json['total_cents'] as num).toInt(),
      holdExpiresAt: switch (json['hold_expires_at']) {
        final String v => DateTime.parse(v).toLocal(),
        _ => null,
      },
    );
  });

  @override
  Future<PaymentSession> startPayment(String bookingId) => _guard(() async {
    final json = await _client.rpc<Map<String, dynamic>>(
      'start_payment',
      params: {'p_booking_id': bookingId},
    );
    return PaymentSession(
      paymentId: json['payment_id'] as String,
      provider: json['provider'] as String,
      amountCents: (json['amount_cents'] as num).toInt(),
      holdExpiresAt: switch (json['hold_expires_at']) {
        final String v => DateTime.parse(v).toLocal(),
        _ => null,
      },
    );
  });

  @override
  Future<String> completeDemoPayment(
    String paymentId, {
    required bool approved,
  }) => _guard(
    () => _client.rpc<String>(
      'demo_gateway_complete',
      params: {'p_payment_id': paymentId, 'p_approved': approved},
    ),
  );

  @override
  Future<Booking> booking(String id) => _guard(() async {
    final row = await _client
        .from('bookings')
        .select(Booking.columns)
        .eq('id', id)
        .maybeSingle();
    if (row == null) {
      throw const BookingFailure(BookingFailureReason.notFound);
    }
    return Booking.fromJson(row);
  });

  @override
  Future<List<Booking>> myBookings() async {
    final userId = _client.auth.currentUser?.id;
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = '$_cacheKey:$userId';
    try {
      final rows = await _client
          .from('bookings')
          .select(Booking.columns)
          .eq('customer_id', userId ?? '')
          .order('arrival_at', ascending: false)
          .limit(50);
      // Se guardan para mostrar el código aunque no haya conexión.
      await prefs.setString(cacheKey, jsonEncode(rows));
      return rows.map(Booking.fromJson).toList();
    } on Exception catch (error) {
      final cached = prefs.getString(cacheKey);
      if (cached != null) {
        return (jsonDecode(cached) as List)
            .cast<Map<String, dynamic>>()
            .map(Booking.fromJson)
            .toList();
      }
      throw BookingFailure(BookingFailureReason.network, '$error');
    }
  }

  @override
  Future<int> cancel(String bookingId, {String reason = ''}) =>
      _guard(() async {
        final json = await _client.rpc<Map<String, dynamic>>(
          'cancel_booking',
          params: {'p_booking_id': bookingId, 'p_reason': reason},
        );
        return (json['refund_cents'] as num).toInt();
      });

  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on BookingFailure {
      rethrow;
    } on sb.PostgrestException catch (error) {
      throw BookingFailure(
        bookingReasonFromServer(error.message),
        '${error.code}: ${error.message}',
      );
    } on Exception catch (error) {
      throw BookingFailure(BookingFailureReason.network, '$error');
    }
  }
}
