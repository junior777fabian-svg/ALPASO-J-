import 'package:alpaso/app/theme/app_spacing.dart';
import 'package:alpaso/core/format/money.dart';
import 'package:alpaso/design/widgets/empty_state.dart';
import 'package:alpaso/features/business/data/business_providers.dart';
import 'package:alpaso/features/business/data/earnings_repository.dart';
import 'package:alpaso/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

/// N7. Ventas pendientes de liquidar, comisión, liquidaciones y cuenta de
/// destino.
class EarningsScreen extends ConsumerStatefulWidget {
  const EarningsScreen({required this.lodgingId, super.key});

  final String lodgingId;

  @override
  ConsumerState<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends ConsumerState<EarningsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _holder = TextEditingController();
  final _bank = TextEditingController();
  final _cci = TextEditingController();
  bool _loadedAccount = false;
  bool _busy = false;

  @override
  void dispose() {
    _holder.dispose();
    _bank.dispose();
    _cci.dispose();
    super.dispose();
  }

  Future<void> _saveAccount() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(earningsRepositoryProvider)!
          .setPayoutAccount(
            widget.lodgingId,
            PayoutAccount(
              holderName: _holder.text,
              bankName: _bank.text,
              cci: _cci.text,
            ),
          );
      ref.invalidate(payoutAccountProvider(widget.lodgingId));
      messenger.showSnackBar(SnackBar(content: Text(l10n.payoutAccountSaved)));
    } on Object {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.businessErrorInvalidData)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final earnings = ref.watch(earningsProvider(widget.lodgingId));
    final account = ref.watch(payoutAccountProvider(widget.lodgingId));
    if (!_loadedAccount && account.hasValue) {
      _loadedAccount = true;
      final saved = account.value;
      if (saved != null) {
        _holder.text = saved.holderName;
        _bank.text = saved.bankName;
        _cci.text = saved.cci;
      }
    }
    final date = DateFormat('d MMM yyyy', 'es');

    return Scaffold(
      appBar: AppBar(title: Text(l10n.earningsTitle)),
      body: switch (earnings) {
        AsyncData(:final value) => SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.earningsPending(value.pendingBookings),
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _Row(l10n.earningsGross, value.pendingGrossCents),
                      _Row(
                        l10n.earningsCommission(
                          value.commissionPercent.toStringAsFixed(0),
                        ),
                        -value.pendingCommissionCents,
                      ),
                      const Divider(),
                      _Row(l10n.earningsNet, value.pendingNetCents, bold: true),
                      Text(l10n.earningsHelp, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.payoutsTitle, style: theme.textTheme.titleMedium),
              if (value.payouts.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Text(l10n.payoutsEmpty),
                ),
              for (final p in value.payouts)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${formatSoles(p.netCents)} · ${l10n.payoutBookings(p.bookingsCount)}',
                  ),
                  subtitle: Text(
                    p.isPaid
                        ? l10n.payoutPaid(date.format(p.periodEnd), p.reference)
                        : l10n.payoutPending(date.format(p.periodEnd)),
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              Text(l10n.payoutAccountTitle, style: theme.textTheme.titleMedium),
              Text(l10n.payoutAccountHelp, style: theme.textTheme.bodySmall),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      key: const Key('payout-holder'),
                      controller: _holder,
                      decoration: InputDecoration(labelText: l10n.payoutHolder),
                      validator: (v) => (v ?? '').trim().length < 3
                          ? l10n.lodgingErrorLength(3, 120)
                          : null,
                    ),
                    TextFormField(
                      key: const Key('payout-bank'),
                      controller: _bank,
                      decoration: InputDecoration(labelText: l10n.payoutBank),
                      validator: (v) => (v ?? '').trim().length < 2
                          ? l10n.lodgingErrorLength(2, 60)
                          : null,
                    ),
                    TextFormField(
                      key: const Key('payout-cci'),
                      controller: _cci,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: l10n.payoutCci),
                      validator: (v) =>
                          (v ?? '').replaceAll(RegExp('[^0-9]'), '').length ==
                              20
                          ? null
                          : l10n.payoutCciError,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                key: const Key('payout-save'),
                onPressed: _busy ? null : _saveAccount,
                child: Text(l10n.profileSaveAction),
              ),
            ],
          ),
        ),
        AsyncError() => EmptyState(
          icon: Icons.error_outline,
          title: l10n.profileLoadErrorTitle,
          body: l10n.authErrorNetwork,
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.cents, {this.bold = false});

  final String label;
  final int cents;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = bold ? Theme.of(context).textTheme.titleMedium : null;
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(formatSoles(cents), style: style),
      ],
    );
  }
}
