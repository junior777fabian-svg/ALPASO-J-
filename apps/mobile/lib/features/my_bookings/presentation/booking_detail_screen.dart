import 'dart:async';

import 'package:alpaso/app/router/app_router.dart';
import 'package:alpaso/app/theme/app_spacing.dart';
import 'package:alpaso/core/format/money.dart';
import 'package:alpaso/design/widgets/empty_state.dart';
import 'package:alpaso/features/booking/data/booking_providers.dart';
import 'package:alpaso/features/booking/domain/booking.dart';
import 'package:alpaso/features/booking/presentation/booking_messages.dart';
import 'package:alpaso/features/explore/data/explore_providers.dart';
import 'package:alpaso/features/explore/presentation/explore_messages.dart';
import 'package:alpaso/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// C6. Detalle de una reserva: código y QR para recepción, cómo llegar,
/// tiempo restante y cancelación.
class BookingDetailScreen extends ConsumerStatefulWidget {
  const BookingDetailScreen({required this.bookingId, super.key});

  final String bookingId;

  @override
  ConsumerState<BookingDetailScreen> createState() =>
      _BookingDetailScreenState();
}

class _BookingDetailScreenState extends ConsumerState<BookingDetailScreen> {
  Timer? _ticker;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _cancel(Booking booking) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final now = ref.read(clockProvider)();
    final paid = booking.status == BookingStatus.confirmed;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.cancelTitle),
        content: Text(
          paid && booking.canCancelWithRefund(now)
              ? l10n.cancelRefundBody(formatSoles(booking.totalCents))
              : l10n.cancelUnpaidBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancelKeep),
          ),
          FilledButton(
            key: const Key('cancel-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.cancelAction),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      final refund = await ref
          .read(bookingRepositoryProvider)!
          .cancel(booking.id);
      ref
        ..invalidate(bookingProvider(booking.id))
        ..invalidate(myBookingsProvider)
        ..invalidate(searchResultsProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            refund > 0
                ? l10n.cancelDoneRefund(formatSoles(refund))
                : l10n.cancelDone,
          ),
        ),
      );
    } on Object catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(bookingFailureMessage(l10n, error))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final booking = ref.watch(bookingProvider(widget.bookingId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.bookingDetailTitle)),
      body: switch (booking) {
        AsyncData(:final value) => _details(context, l10n, value),
        AsyncError(:final error) => EmptyState(
          icon: Icons.error_outline,
          title: l10n.profileLoadErrorTitle,
          body: bookingFailureMessage(l10n, error),
          action: FilledButton(
            onPressed: () => ref.invalidate(bookingProvider(widget.bookingId)),
            child: Text(l10n.profileRetryAction),
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _details(BuildContext context, AppLocalizations l10n, Booking b) {
    final theme = Theme.of(context);
    final now = ref.read(clockProvider)();
    final confirmed = b.status == BookingStatus.confirmed;
    final canCancel =
        b.status == BookingStatus.pendingPayment ||
        (confirmed && b.canCancelWithRefund(now));

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text(b.lodgingName, style: theme.textTheme.headlineSmall),
        Text('${b.roomTypeName} · ${b.blockHours} h'),
        const SizedBox(height: AppSpacing.sm),
        Text(
          bookingStatusLabel(l10n, b.status),
          key: const Key('booking-status'),
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (confirmed) ...[
          Center(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: QrImageView(
                data: 'ALPASO:${b.code}',
                size: 200,
                semanticsLabel: l10n.bookingQrSemantics,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            b.code,
            key: const Key('booking-code'),
            textAlign: TextAlign.center,
            style: theme.textTheme.displaySmall?.copyWith(letterSpacing: 6),
          ),
          Text(
            l10n.bookingCodeHelp,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.schedule),
                title: Text(
                  l10n.bookingArrival(formatArrival(l10n, b.arrival, now)),
                ),
                subtitle: Text(
                  confirmed && b.arrival.isAfter(now)
                      ? l10n.bookingStartsIn(
                          formatRemaining(b.arrival.difference(now)),
                        )
                      : l10n.bookingDeparture(
                          formatArrival(l10n, b.departure, now),
                        ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.place_outlined),
                title: Text(b.address),
                trailing: TextButton(
                  onPressed: () => launchUrl(
                    Uri.parse(
                      'https://www.google.com/maps/dir/?api=1&destination='
                      '${b.location.latitude},${b.location.longitude}',
                    ),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: Text(l10n.bookingDirections),
                ),
              ),
              for (final item in b.items)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.local_drink_outlined),
                  title: Text('${item.quantity} × ${item.name}'),
                  trailing: Text(formatSoles(item.subtotalCents)),
                ),
              ListTile(
                title: Text(l10n.bookingTotal),
                trailing: Text(
                  formatSoles(b.totalCents),
                  style: theme.textTheme.titleMedium,
                ),
              ),
              if (b.refundCents != null)
                ListTile(
                  title: Text(l10n.bookingRefunded),
                  trailing: Text(formatSoles(b.refundCents!)),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(l10n.bookingBringId, style: theme.textTheme.bodySmall),
        const SizedBox(height: AppSpacing.md),
        if (b.status == BookingStatus.pendingPayment)
          FilledButton(
            onPressed: () => context.push(AppRoutes.payment(b.id)),
            child: Text(l10n.bookingPayAction),
          ),
        if (canCancel)
          OutlinedButton(
            key: const Key('booking-cancel'),
            onPressed: _busy ? null : () => _cancel(b),
            child: Text(l10n.cancelAction),
          )
        else if (confirmed)
          Text(l10n.cancelWindowClosedHelp, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
