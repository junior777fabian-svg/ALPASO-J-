import 'dart:async';

import 'package:alpaso/app/router/app_router.dart';
import 'package:alpaso/app/theme/app_spacing.dart';
import 'package:alpaso/core/format/money.dart';
import 'package:alpaso/design/widgets/empty_state.dart';
import 'package:alpaso/features/auth/presentation/auth_form_widgets.dart';
import 'package:alpaso/features/booking/data/booking_providers.dart';
import 'package:alpaso/features/booking/domain/booking.dart';
import 'package:alpaso/features/booking/presentation/booking_messages.dart';
import 'package:alpaso/features/explore/data/explore_providers.dart';
import 'package:alpaso/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Pago de una reserva. Con el conector demo muestra la pasarela de prueba,
/// rotulada: aprobar o rechazar. Solo el servidor confirma la reserva.
class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({required this.bookingId, super.key});

  final String bookingId;

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  Future<PaymentSession>? _session;
  Timer? _ticker;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _start();
    // Solo redibuja la cuenta regresiva.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _start() {
    setState(() {
      _message = null;
      _session = ref
          .read(bookingRepositoryProvider)!
          .startPayment(widget.bookingId);
    });
  }

  Future<void> _complete(
    PaymentSession session, {
    required bool approved,
  }) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(bookingRepositoryProvider)!
          .completeDemoPayment(session.paymentId, approved: approved);
      ref
        ..invalidate(myBookingsProvider)
        ..invalidate(bookingProvider(widget.bookingId));
      if (!mounted) return;
      switch (result) {
        case 'paid':
          context.go(AppRoutes.bookingDetail(widget.bookingId));
        case 'refunded':
          setState(() => _message = l10n.paymentLateRefunded);
        default:
          setState(() => _message = l10n.paymentRejected);
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _message = bookingFailureMessage(l10n, error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final now = ref.read(clockProvider)();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.paymentTitle)),
      body: FutureBuilder<PaymentSession>(
        future: _session,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.error_outline,
              title: l10n.paymentErrorTitle,
              body: bookingFailureMessage(l10n, snapshot.error!),
              action: OutlinedButton(
                onPressed: () => context.go(AppRoutes.bookings),
                child: Text(l10n.paymentGoToBookings),
              ),
            );
          }
          final session = snapshot.data;
          if (session == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final remaining = session.holdExpiresAt?.difference(now);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (session.isDemo)
                  Container(
                    key: const Key('demo-gateway-label'),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: Colors.deepOrange.shade700,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      l10n.paymentDemoLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
                Text(l10n.paymentAmount, textAlign: TextAlign.center),
                Text(
                  formatSoles(session.amountCents),
                  key: const Key('payment-amount'),
                  style: theme.textTheme.displaySmall,
                  textAlign: TextAlign.center,
                ),
                if (remaining != null && !remaining.isNegative)
                  Text(
                    l10n.paymentHoldRemaining(formatRemaining(remaining)),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                const SizedBox(height: AppSpacing.lg),
                if (_message != null) ...[
                  FormErrorBox(message: _message!),
                  const SizedBox(height: AppSpacing.md),
                ],
                // Tras un rechazo, el cobro quedó cerrado: se paga con uno nuevo.
                if (session.isDemo && _message != l10n.paymentRejected) ...[
                  FilledButton(
                    key: const Key('demo-approve'),
                    onPressed: _busy
                        ? null
                        : () => _complete(session, approved: true),
                    child: Text(l10n.paymentDemoApprove),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton(
                    key: const Key('demo-reject'),
                    onPressed: _busy
                        ? null
                        : () => _complete(session, approved: false),
                    child: Text(l10n.paymentDemoReject),
                  ),
                ] else if (!session.isDemo)
                  Text(l10n.paymentRealPending, textAlign: TextAlign.center),
                if (_message == l10n.paymentRejected) ...[
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(onPressed: _start, child: Text(l10n.paymentRetry)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
