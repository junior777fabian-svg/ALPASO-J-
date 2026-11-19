import 'package:alpaso/app/theme/app_spacing.dart';
import 'package:alpaso/core/format/money.dart';
import 'package:alpaso/design/widgets/empty_state.dart';
import 'package:alpaso/features/business/data/business_providers.dart';
import 'package:alpaso/features/business/domain/reception.dart';
import 'package:alpaso/features/business/presentation/reception_messages.dart';
import 'package:alpaso/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

/// N4. Tablero del día: ingreso con código, llegadas, estadías en curso,
/// cuartos y extras por preparar.
class ReceptionScreen extends ConsumerStatefulWidget {
  const ReceptionScreen({required this.lodgingId, super.key});

  final String lodgingId;

  @override
  ConsumerState<ReceptionScreen> createState() => _ReceptionScreenState();
}

class _ReceptionScreenState extends ConsumerState<ReceptionScreen> {
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  /// Ejecuta una acción de recepción, avisa el resultado y recarga.
  Future<void> _run(Future<String?> Function() action) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final message = await action();
      // En recepción importa el último aviso: se muestra al instante.
      messenger.hideCurrentSnackBar();
      if (message != null) {
        messenger.showSnackBar(SnackBar(content: Text(message)));
      }
      ref.invalidate(todayBoardProvider(widget.lodgingId));
    } on Object catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(receptionFailureMessage(l10n, error))),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkIn() async {
    final code = _code.text.trim();
    if (code.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    await _run(() async {
      final stay = await ref
          .read(receptionRepositoryProvider)!
          .checkIn(widget.lodgingId, code);
      _code.clear();
      return l10n.receptionCheckedIn(stay.customerName, stay.roomLabel);
    });
  }

  Future<void> _blockRoom(RoomStatus room) async {
    final l10n = AppLocalizations.of(context);
    final choice = await showModalBottomSheet<(String, int)>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                l10n.receptionWalkInTitle(room.label),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Wrap(
              spacing: AppSpacing.sm,
              alignment: WrapAlignment.center,
              children: [
                for (final hours in const [1, 2, 3, 4, 6, 8, 12])
                  ActionChip(
                    label: Text(l10n.hoursShort(hours)),
                    onPressed: () =>
                        Navigator.of(context).pop(('walk_in', hours * 60)),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ListTile(
              leading: const Icon(Icons.build_outlined),
              title: Text(l10n.receptionMaintenance),
              onTap: () => Navigator.of(context).pop(('maintenance', 24 * 60)),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    await _run(() async {
      await ref
          .read(receptionRepositoryProvider)!
          .blockRoom(room.roomId, choice.$1, choice.$2);
      return null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final board = ref.watch(todayBoardProvider(widget.lodgingId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.receptionTitle)),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.refresh(todayBoardProvider(widget.lodgingId).future),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.receptionCheckInTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      key: const Key('checkin-code'),
                      controller: _code,
                      textCapitalization: TextCapitalization.characters,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: l10n.receptionCodeLabel,
                        hintText: 'K7X9QA',
                      ),
                      onSubmitted: (_) => _checkIn(),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    FilledButton(
                      key: const Key('checkin-submit'),
                      onPressed: _busy ? null : _checkIn,
                      child: Text(l10n.receptionCheckInAction),
                    ),
                  ],
                ),
              ),
            ),
            switch (board) {
              AsyncData(:final value) => _Board(
                board: value,
                busy: _busy,
                onCheckOut: (stay) => _run(() async {
                  await ref
                      .read(receptionRepositoryProvider)!
                      .checkOut(stay.bookingId);
                  return l10n.receptionCheckedOut(stay.roomLabel);
                }),
                onItem: (item, status) => _run(() async {
                  final refund = await ref
                      .read(receptionRepositoryProvider)!
                      .setItemStatus(item.id, status);
                  return refund > 0
                      ? l10n.receptionItemRefunded(formatSoles(refund))
                      : null;
                }),
                onClean: (room) => _run(() async {
                  await ref
                      .read(receptionRepositoryProvider)!
                      .markClean(room.roomId);
                  return l10n.receptionRoomClean(room.label);
                }),
                onBlock: _blockRoom,
                onRelease: (room) => _run(() async {
                  await ref
                      .read(receptionRepositoryProvider)!
                      .releaseBlock(room.occupancyId!);
                  return l10n.receptionRoomReleased(room.label);
                }),
              ),
              AsyncError(:final error) => EmptyState(
                icon: Icons.error_outline,
                title: l10n.profileLoadErrorTitle,
                body: receptionFailureMessage(l10n, error),
              ),
              _ => const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Center(child: CircularProgressIndicator()),
              ),
            },
          ],
        ),
      ),
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({
    required this.board,
    required this.busy,
    required this.onCheckOut,
    required this.onItem,
    required this.onClean,
    required this.onBlock,
    required this.onRelease,
  });

  final TodayBoard board;
  final bool busy;
  final void Function(ReceptionStay) onCheckOut;
  final void Function(ReceptionItem, String) onItem;
  final void Function(RoomStatus) onClean;
  final void Function(RoomStatus) onBlock;
  final void Function(RoomStatus) onRelease;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final time = DateFormat('HH:mm', 'es');

    Widget items(List<ReceptionItem> list) => Column(
      children: [
        for (final item in list)
          Row(
            children: [
              Expanded(child: Text('${item.quantity} × ${item.name}')),
              if (item.isPending) ...[
                TextButton(
                  key: Key('item-ready-${item.id}'),
                  onPressed: busy ? null : () => onItem(item, 'ready'),
                  child: Text(l10n.receptionItemReady),
                ),
                TextButton(
                  key: Key('item-missing-${item.id}'),
                  onPressed: busy ? null : () => onItem(item, 'unavailable'),
                  child: Text(l10n.receptionItemMissing),
                ),
              ] else
                Text(
                  item.status == 'ready'
                      ? l10n.receptionItemIsReady
                      : l10n.receptionItemIsMissing,
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.md),
        Text(l10n.receptionArrivals, style: theme.textTheme.titleMedium),
        if (board.arrivals.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Text(l10n.receptionNoArrivals),
          ),
        for (final stay in board.arrivals)
          Card(
            key: Key('arrival-${stay.bookingId}'),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${stay.customerName} · ${stay.code}',
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(
                    l10n.receptionArrivalLine(
                      time.format(stay.arrival!),
                      stay.roomLabel,
                      stay.roomType,
                    ),
                  ),
                  items(stay.items),
                ],
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        Text(l10n.receptionInHouse, style: theme.textTheme.titleMedium),
        if (board.inHouse.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Text(l10n.receptionNoneInHouse),
          ),
        for (final stay in board.inHouse)
          Card(
            key: Key('stay-${stay.bookingId}'),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${stay.customerName} · ${l10n.receptionRoom(stay.roomLabel)}',
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(l10n.receptionUntil(time.format(stay.departure))),
                  items(stay.items),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      key: Key('checkout-${stay.bookingId}'),
                      onPressed: busy ? null : () => onCheckOut(stay),
                      child: Text(l10n.receptionCheckOutAction),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        Text(l10n.receptionRooms, style: theme.textTheme.titleMedium),
        for (final room in board.rooms)
          ListTile(
            key: Key('room-${room.label}'),
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              child: Text(room.label, style: const TextStyle(fontSize: 12)),
            ),
            title: Text(roomStateLabel(l10n, room.state)),
            subtitle: Text(
              [
                room.roomType,
                if (room.until != null && room.state != RoomState.free)
                  l10n.receptionUntil(time.format(room.until!)),
              ].join(' · '),
            ),
            trailing: switch (room.state) {
              RoomState.free => TextButton(
                onPressed: busy ? null : () => onBlock(room),
                child: Text(l10n.receptionOccupy),
              ),
              RoomState.cleaning => TextButton(
                onPressed: busy ? null : () => onClean(room),
                child: Text(l10n.receptionMarkClean),
              ),
              RoomState.walkIn || RoomState.maintenance => TextButton(
                onPressed: busy ? null : () => onRelease(room),
                child: Text(l10n.receptionRelease),
              ),
              _ => null,
            },
          ),
      ],
    );
  }
}
