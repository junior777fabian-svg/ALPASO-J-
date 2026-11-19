import 'package:supabase_flutter/supabase_flutter.dart';

/// Error del servidor, con su código (por ejemplo `not_admin`).
class AdminFailure implements Exception {
  const AdminFailure(this.code);

  final String code;

  @override
  String toString() => 'AdminFailure($code)';
}

typedef Json = Map<String, dynamic>;

/// Todo lo que el panel pide al servidor. Las pruebas usan una versión falsa.
abstract interface class AdminRepository {
  Future<void> signIn(String email, String password);

  Future<void> signOut();

  bool get isSignedIn;

  /// Falla con `not_admin` si la cuenta no es administradora.
  Future<Json> overview();

  Future<List<Json>> lodgings(String status);

  Future<void> reviewLodging(
    String id, {
    required bool approve,
    String note = '',
  });

  Future<void> setLodgingSuspended(
    String id, {
    required bool suspended,
    required String reason,
  });

  Future<List<Json>> findUsers(String query);

  Future<void> setBlocked(
    String userId, {
    required bool blocked,
    required String reason,
  });

  Future<Json> findBooking(String code);

  Future<int> refundBooking(String bookingId, int amountCents, String reason);

  Future<List<Json>> pendingPayouts();

  Future<List<Json>> payouts();

  Future<Json> createPayout(String lodgingId);

  Future<void> markPayoutPaid(String payoutId, String reference);

  Future<List<Json>> supportCases();

  Future<void> resolveSupportCase(String id, String resolution);

  Future<List<Json>> complaints();

  Future<void> answerComplaint(String number, String answer);

  Future<Json> publicSettings();
}

class SupabaseAdminRepository implements AdminRepository {
  SupabaseAdminRepository(this._client);

  final SupabaseClient _client;

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PostgrestException catch (e) {
      throw AdminFailure(e.message);
    } on AuthException catch (e) {
      throw AdminFailure(e.code ?? 'auth');
    } on Exception {
      throw const AdminFailure('network');
    }
  }

  @override
  Future<void> signIn(String email, String password) => _guard(
    () => _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    ),
  );

  @override
  Future<void> signOut() => _guard(_client.auth.signOut);

  @override
  bool get isSignedIn => _client.auth.currentUser != null;

  @override
  Future<Json> overview() => _guard(() => _client.rpc<Json>('admin_overview'));

  @override
  Future<List<Json>> lodgings(String status) => _guard(() async {
    final rows = await _client
        .from('lodgings')
        .select(
          'id, name, address, status, review_note, submitted_at, districts(name)',
        )
        .eq('status', status)
        .order('submitted_at', ascending: true)
        .limit(200);
    return rows.cast<Json>();
  });

  @override
  Future<void> reviewLodging(
    String id, {
    required bool approve,
    String note = '',
  }) => _guard(
    () => _client.rpc<String>(
      'admin_review_lodging',
      params: {'p_lodging_id': id, 'p_approve': approve, 'p_note': note},
    ),
  );

  @override
  Future<void> setLodgingSuspended(
    String id, {
    required bool suspended,
    required String reason,
  }) => _guard(
    () => _client.rpc<String>(
      'admin_set_lodging_suspended',
      params: {
        'p_lodging_id': id,
        'p_suspended': suspended,
        'p_reason': reason,
      },
    ),
  );

  @override
  Future<List<Json>> findUsers(String query) => _guard(() async {
    final rows = await _client.rpc<List<dynamic>>(
      'admin_find_users',
      params: {'p_query': query},
    );
    return rows.cast<Json>();
  });

  @override
  Future<void> setBlocked(
    String userId, {
    required bool blocked,
    required String reason,
  }) => _guard(
    () => _client.rpc<void>(
      'admin_set_blocked',
      params: {'p_user_id': userId, 'p_blocked': blocked, 'p_reason': reason},
    ),
  );

  @override
  Future<Json> findBooking(String code) => _guard(
    () => _client.rpc<Json>('admin_find_booking', params: {'p_code': code}),
  );

  @override
  Future<int> refundBooking(String bookingId, int amountCents, String reason) =>
      _guard(
        () => _client.rpc<int>(
          'admin_refund_booking',
          params: {
            'p_booking_id': bookingId,
            'p_amount_cents': amountCents,
            'p_reason': reason,
          },
        ),
      );

  @override
  Future<List<Json>> pendingPayouts() => _guard(() async {
    final rows = await _client.rpc<List<dynamic>>('admin_pending_payouts');
    return rows.cast<Json>();
  });

  @override
  Future<List<Json>> payouts() => _guard(() async {
    final rows = await _client
        .from('payouts')
        .select(
          'id, net_cents, gross_cents, commission_cents, bookings_count, status, transfer_reference, created_at, lodgings(name)',
        )
        .order('created_at', ascending: false)
        .limit(100);
    return rows.cast<Json>();
  });

  @override
  Future<Json> createPayout(String lodgingId) => _guard(
    () => _client.rpc<Json>(
      'admin_create_payout',
      params: {'p_lodging_id': lodgingId},
    ),
  );

  @override
  Future<void> markPayoutPaid(String payoutId, String reference) => _guard(
    () => _client.rpc<void>(
      'admin_mark_payout_paid',
      params: {'p_payout_id': payoutId, 'p_reference': reference},
    ),
  );

  @override
  Future<List<Json>> supportCases() => _guard(() async {
    final rows = await _client
        .from('support_cases')
        .select('id, subject, message, status, created_at')
        .eq('status', 'open')
        .order('created_at', ascending: true);
    return rows.cast<Json>();
  });

  @override
  Future<void> resolveSupportCase(String id, String resolution) => _guard(
    () => _client.rpc<void>(
      'admin_resolve_support_case',
      params: {'p_case_id': id, 'p_resolution': resolution},
    ),
  );

  @override
  Future<List<Json>> complaints() => _guard(() async {
    final rows = await _client.rpc<List<dynamic>>(
      'admin_list_complaints',
      params: {'p_only_open': true},
    );
    return rows.cast<Json>();
  });

  @override
  Future<void> answerComplaint(String number, String answer) => _guard(
    () => _client.rpc<void>(
      'admin_answer_complaint',
      params: {'p_number': number, 'p_answer': answer},
    ),
  );

  @override
  Future<Json> publicSettings() =>
      _guard(() => _client.rpc<Json>('get_public_settings'));
}
