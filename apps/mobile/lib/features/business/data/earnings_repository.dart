import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class Payout {
  const Payout({
    required this.id,
    required this.periodEnd,
    required this.grossCents,
    required this.commissionCents,
    required this.netCents,
    required this.bookingsCount,
    required this.isPaid,
    this.reference = '',
  });

  factory Payout.fromJson(Map<String, dynamic> json) => Payout(
    id: json['id'] as String,
    periodEnd: DateTime.parse(json['period_end'] as String).toLocal(),
    grossCents: (json['gross_cents'] as num).toInt(),
    commissionCents: (json['commission_cents'] as num).toInt(),
    netCents: (json['net_cents'] as num).toInt(),
    bookingsCount: (json['bookings_count'] as num).toInt(),
    isPaid: json['status'] == 'paid',
    reference: (json['transfer_reference'] as String?) ?? '',
  );

  final String id;
  final DateTime periodEnd;
  final int grossCents;
  final int commissionCents;
  final int netCents;
  final int bookingsCount;
  final bool isPaid;
  final String reference;
}

class Earnings {
  const Earnings({
    required this.pendingGrossCents,
    required this.pendingCommissionCents,
    required this.pendingNetCents,
    required this.pendingBookings,
    required this.commissionPercent,
    this.payouts = const [],
  });

  factory Earnings.fromJson(Map<String, dynamic> json) => Earnings(
    pendingGrossCents: (json['pending_gross_cents'] as num).toInt(),
    pendingCommissionCents: (json['pending_commission_cents'] as num).toInt(),
    pendingNetCents: (json['pending_net_cents'] as num).toInt(),
    pendingBookings: (json['pending_bookings'] as num).toInt(),
    commissionPercent: (json['commission_percent'] as num).toDouble(),
    payouts: [
      for (final p
          in ((json['payouts'] as List?) ?? const [])
              .cast<Map<String, dynamic>>())
        Payout.fromJson(p),
    ],
  );

  final int pendingGrossCents;
  final int pendingCommissionCents;
  final int pendingNetCents;
  final int pendingBookings;
  final double commissionPercent;
  final List<Payout> payouts;
}

class PayoutAccount {
  const PayoutAccount({
    required this.holderName,
    required this.bankName,
    required this.cci,
  });

  final String holderName;
  final String bankName;
  final String cci;
}

abstract interface class EarningsRepository {
  Future<Earnings> earnings(String lodgingId);

  Future<PayoutAccount?> payoutAccount(String lodgingId);

  Future<void> setPayoutAccount(String lodgingId, PayoutAccount account);
}

class SupabaseEarningsRepository implements EarningsRepository {
  SupabaseEarningsRepository(this._client);

  final sb.SupabaseClient _client;

  @override
  Future<Earnings> earnings(String lodgingId) async {
    final json = await _client.rpc<Map<String, dynamic>>(
      'lodging_earnings',
      params: {'p_lodging_id': lodgingId},
    );
    return Earnings.fromJson(json);
  }

  @override
  Future<PayoutAccount?> payoutAccount(String lodgingId) async {
    final row = await _client
        .from('lodging_payout_accounts')
        .select('holder_name, bank_name, cci')
        .eq('lodging_id', lodgingId)
        .maybeSingle();
    if (row == null) return null;
    return PayoutAccount(
      holderName: row['holder_name'] as String,
      bankName: row['bank_name'] as String,
      cci: row['cci'] as String,
    );
  }

  @override
  Future<void> setPayoutAccount(String lodgingId, PayoutAccount account) =>
      _client.rpc<void>(
        'set_payout_account',
        params: {
          'p_lodging_id': lodgingId,
          'p_holder': account.holderName,
          'p_bank': account.bankName,
          'p_cci': account.cci,
        },
      );
}
