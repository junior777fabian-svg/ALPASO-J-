import 'package:alpaso/features/business/data/earnings_repository.dart';

class FakeEarningsServer implements EarningsRepository {
  Earnings value = Earnings(
    pendingGrossCents: 10000,
    pendingCommissionCents: 1000,
    pendingNetCents: 9000,
    pendingBookings: 2,
    commissionPercent: 10,
    payouts: [
      Payout(
        id: 'p1',
        periodEnd: DateTime(2026, 11, 15),
        grossCents: 5000,
        commissionCents: 500,
        netCents: 4500,
        bookingsCount: 1,
        isPaid: true,
        reference: 'OP-123',
      ),
    ],
  );
  final accounts = <String, PayoutAccount>{};

  @override
  Future<Earnings> earnings(String lodgingId) async => value;

  @override
  Future<PayoutAccount?> payoutAccount(String lodgingId) async =>
      accounts[lodgingId];

  @override
  Future<void> setPayoutAccount(String lodgingId, PayoutAccount account) async {
    accounts[lodgingId] = account;
  }
}
