import 'package:alpaso/features/business/domain/business_failure.dart';
import 'package:alpaso/features/business/domain/reception.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// Errores propios de recepción.
enum ReceptionFailureReason {
  codeNotFound,
  codeAlreadyUsed,
  tooEarly,
  tooLate,
  notConfirmed,
  roomNotFree,
  inviteNotValid,
  alreadyMember,
  notStaff,
  notOwner,
  reasonRequired,
  invalidStatus,
  network,
  unknown,
}

class ReceptionFailure implements Exception {
  const ReceptionFailure(this.reason, [this.debugMessage = '']);

  final ReceptionFailureReason reason;
  final String debugMessage;

  @override
  String toString() => 'ReceptionFailure(${reason.name}: $debugMessage)';
}

abstract interface class ReceptionRepository {
  Future<TodayBoard> today(String lodgingId);

  /// Devuelve la estadía registrada.
  Future<ReceptionStay> checkIn(String lodgingId, String code);

  Future<void> checkOut(String bookingId);

  Future<void> markClean(String roomId);

  /// [kind]: walk_in o maintenance.
  Future<void> blockRoom(String roomId, String kind, int minutes);

  Future<void> releaseBlock(String occupancyId);

  /// [status]: ready o unavailable. Devuelve lo reembolsado.
  Future<int> setItemStatus(String itemId, String status);

  Future<List<HostBooking>> bookings(String lodgingId);

  /// Devuelve lo reembolsado.
  Future<int> cancelBooking(String bookingId, String reason);

  Future<List<StaffMember>> staff(String lodgingId);

  Future<StaffInvite> invite(String lodgingId);

  /// Devuelve el nombre del hostal.
  Future<String> acceptInvite(String code);

  Future<void> revoke(String lodgingId, String userId);
}

class SupabaseReceptionRepository implements ReceptionRepository {
  SupabaseReceptionRepository(this._client);

  final sb.SupabaseClient _client;

  @override
  Future<TodayBoard> today(String lodgingId) => _guard(() async {
    final json = await _client.rpc<Map<String, dynamic>>(
      'host_today',
      params: {'p_lodging_id': lodgingId},
    );
    return TodayBoard.fromJson(json);
  });

  @override
  Future<ReceptionStay> checkIn(String lodgingId, String code) =>
      _guard(() async {
        final json = await _client.rpc<Map<String, dynamic>>(
          'host_check_in',
          params: {'p_lodging_id': lodgingId, 'p_code': code},
        );
        return ReceptionStay.fromJson(json);
      });

  @override
  Future<void> checkOut(String bookingId) => _guard(
    () => _client.rpc<void>(
      'host_check_out',
      params: {'p_booking_id': bookingId},
    ),
  );

  @override
  Future<void> markClean(String roomId) => _guard(
    () => _client.rpc<void>('host_mark_clean', params: {'p_room_id': roomId}),
  );

  @override
  Future<void> blockRoom(String roomId, String kind, int minutes) => _guard(
    () => _client.rpc<String>(
      'host_block_room',
      params: {'p_room_id': roomId, 'p_kind': kind, 'p_minutes': minutes},
    ),
  );

  @override
  Future<void> releaseBlock(String occupancyId) => _guard(
    () => _client.rpc<void>(
      'host_release_block',
      params: {'p_occupancy_id': occupancyId},
    ),
  );

  @override
  Future<int> setItemStatus(String itemId, String status) => _guard(() async {
    final json = await _client.rpc<Map<String, dynamic>>(
      'host_set_item_status',
      params: {'p_item_id': itemId, 'p_status': status},
    );
    return (json['refund_cents'] as num).toInt();
  });

  @override
  Future<List<HostBooking>> bookings(String lodgingId) => _guard(() async {
    final rows = await _client
        .from('bookings')
        .select(
          'id, code, status, arrival_at, block_hours, total_cents, room_types(name)',
        )
        .eq('lodging_id', lodgingId)
        .neq('status', 'pending_payment')
        .order('arrival_at', ascending: false)
        .limit(100);
    return rows.map(HostBooking.fromJson).toList();
  });

  @override
  Future<int> cancelBooking(String bookingId, String reason) =>
      _guard(() async {
        final json = await _client.rpc<Map<String, dynamic>>(
          'host_cancel_booking',
          params: {'p_booking_id': bookingId, 'p_reason': reason},
        );
        return (json['refund_cents'] as num).toInt();
      });

  @override
  Future<List<StaffMember>> staff(String lodgingId) => _guard(() async {
    final rows = await _client.rpc<List<dynamic>>(
      'lodging_staff',
      params: {'p_lodging_id': lodgingId},
    );
    return [
      for (final r in rows.cast<Map<String, dynamic>>())
        StaffMember(
          userId: r['user_id'] as String,
          fullName: r['full_name'] as String,
          isOwner: r['role'] == 'owner',
        ),
    ];
  });

  @override
  Future<StaffInvite> invite(String lodgingId) => _guard(() async {
    final json = await _client.rpc<Map<String, dynamic>>(
      'invite_staff',
      params: {'p_lodging_id': lodgingId},
    );
    return StaffInvite(
      code: json['code'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String).toLocal(),
    );
  });

  @override
  Future<String> acceptInvite(String code) => _guard(() async {
    final json = await _client.rpc<Map<String, dynamic>>(
      'accept_invite',
      params: {'p_code': code},
    );
    return json['lodging_name'] as String;
  });

  @override
  Future<void> revoke(String lodgingId, String userId) => _guard(
    () => _client.rpc<void>(
      'revoke_staff',
      params: {'p_lodging_id': lodgingId, 'p_user_id': userId},
    ),
  );

  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on ReceptionFailure {
      rethrow;
    } on sb.PostgrestException catch (error) {
      throw ReceptionFailure(switch (error.message) {
        'code_not_found' => ReceptionFailureReason.codeNotFound,
        'code_already_used' => ReceptionFailureReason.codeAlreadyUsed,
        'too_early' => ReceptionFailureReason.tooEarly,
        'too_late' => ReceptionFailureReason.tooLate,
        'booking_not_confirmed' => ReceptionFailureReason.notConfirmed,
        'room_not_free' => ReceptionFailureReason.roomNotFree,
        'invite_not_valid' => ReceptionFailureReason.inviteNotValid,
        'already_member' => ReceptionFailureReason.alreadyMember,
        'not_staff' => ReceptionFailureReason.notStaff,
        'not_owner' => ReceptionFailureReason.notOwner,
        'reason_required' => ReceptionFailureReason.reasonRequired,
        'invalid_status' ||
        'item_already_set' => ReceptionFailureReason.invalidStatus,
        _ => switch (businessReasonFromServer(error.message, error.code)) {
          BusinessFailureReason.adultNotConfirmed ||
          BusinessFailureReason.accountBlocked =>
            ReceptionFailureReason.notStaff,
          _ => ReceptionFailureReason.unknown,
        },
      }, '${error.code}: ${error.message}');
    } on Exception catch (error) {
      throw ReceptionFailure(ReceptionFailureReason.network, '$error');
    }
  }
}
