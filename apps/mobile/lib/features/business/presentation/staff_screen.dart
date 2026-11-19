import 'package:alpaso/app/theme/app_spacing.dart';
import 'package:alpaso/core/format/money.dart';
import 'package:alpaso/design/widgets/empty_state.dart';
import 'package:alpaso/design/widgets/text_prompt_dialog.dart';
import 'package:alpaso/features/business/data/business_providers.dart';
import 'package:alpaso/features/business/domain/reception.dart';
import 'package:alpaso/features/business/presentation/reception_messages.dart';
import 'package:alpaso/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

/// N6. Personal del hostal: invitar y retirar recepcionistas.
class StaffScreen extends ConsumerStatefulWidget {
  const StaffScreen({required this.lodgingId, super.key});

  final String lodgingId;

  @override
  ConsumerState<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends ConsumerState<StaffScreen> {
  StaffInvite? _invite;
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action();
    } on Object catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(receptionFailureMessage(l10n, error))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final staff = ref.watch(staffProvider(widget.lodgingId));
    final repository = ref.watch(receptionRepositoryProvider)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.staffTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          switch (staff) {
            AsyncData(value: final List<StaffMember> list) => Column(
              children: [
                for (final m in list)
                  ListTile(
                    leading: Icon(
                      m.isOwner ? Icons.star_outline : Icons.badge_outlined,
                    ),
                    title: Text(m.fullName),
                    subtitle: Text(
                      m.isOwner ? l10n.staffOwner : l10n.staffReceptionist,
                    ),
                    trailing: m.isOwner
                        ? null
                        : TextButton(
                            onPressed: _busy
                                ? null
                                : () => _run(() async {
                                    await repository.revoke(
                                      widget.lodgingId,
                                      m.userId,
                                    );
                                    ref.invalidate(
                                      staffProvider(widget.lodgingId),
                                    );
                                  }),
                            child: Text(l10n.staffRevoke),
                          ),
                  ),
              ],
            ),
            AsyncError(:final error) => Text(
              receptionFailureMessage(l10n, error),
            ),
            _ => const LinearProgressIndicator(),
          },
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.staffInviteHelp,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_invite != null)
            Card(
              child: ListTile(
                title: Text(
                  _invite!.code,
                  key: const Key('invite-code'),
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(letterSpacing: 4),
                ),
                subtitle: Text(
                  l10n.staffInviteExpires(
                    DateFormat('d MMM HH:mm', 'es').format(_invite!.expiresAt),
                  ),
                ),
                trailing: IconButton(
                  tooltip: l10n.staffCopy,
                  icon: const Icon(Icons.copy),
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: _invite!.code)),
                ),
              ),
            ),
          FilledButton.icon(
            key: const Key('staff-invite'),
            onPressed: _busy
                ? null
                : () => _run(() async {
                    final invite = await repository.invite(widget.lodgingId);
                    setState(() => _invite = invite);
                  }),
            icon: const Icon(Icons.person_add_alt),
            label: Text(l10n.staffInviteAction),
          ),
        ],
      ),
    );
  }
}

/// N5. Reservas del hostal, con cancelación con motivo para el dueño.
class HostBookingsScreen extends ConsumerWidget {
  const HostBookingsScreen({required this.lodgingId, super.key});

  final String lodgingId;

  Future<void> _cancel(
    BuildContext context,
    WidgetRef ref,
    HostBooking b,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final text = await showTextPrompt(
      context,
      title: l10n.hostCancelTitle(b.code),
      label: l10n.hostCancelReason,
      confirmLabel: l10n.cancelAction,
      cancelLabel: l10n.cancelKeep,
      fieldKey: const Key('host-cancel-reason'),
      confirmKey: const Key('host-cancel-confirm'),
    );
    if (text == null) return;
    try {
      final refund = await ref
          .read(receptionRepositoryProvider)!
          .cancelBooking(b.id, text);
      ref.invalidate(hostBookingsProvider(lodgingId));
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(l10n.hostCancelDone(formatSoles(refund)))),
        );
    } on Object catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(receptionFailureMessage(l10n, error))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final bookings = ref.watch(hostBookingsProvider(lodgingId));
    final format = DateFormat('EEE d MMM HH:mm', 'es');

    return Scaffold(
      appBar: AppBar(title: Text(l10n.hostBookingsTitle)),
      body: switch (bookings) {
        AsyncData(value: final List<HostBooking> list) when list.isEmpty =>
          EmptyState(
            icon: Icons.event_busy,
            title: l10n.hostBookingsEmpty,
            body: '',
          ),
        AsyncData(value: final List<HostBooking> list) => ListView(
          children: [
            for (final b in list)
              ListTile(
                key: Key('host-booking-${b.id}'),
                title: Text('${b.code} · ${b.roomTypeName}'),
                subtitle: Text(
                  '${format.format(b.arrival)} · ${b.blockHours} h · '
                  '${formatSoles(b.totalCents)} · ${l10n.hostBookingStatus(b.status)}',
                ),
                trailing: b.status == 'confirmed'
                    ? IconButton(
                        tooltip: l10n.cancelAction,
                        icon: const Icon(Icons.cancel_outlined),
                        onPressed: () => _cancel(context, ref, b),
                      )
                    : null,
              ),
          ],
        ),
        AsyncError(:final error) => EmptyState(
          icon: Icons.error_outline,
          title: l10n.profileLoadErrorTitle,
          body: receptionFailureMessage(l10n, error),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
