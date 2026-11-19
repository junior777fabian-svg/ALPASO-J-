import 'package:alpaso/app/router/app_router.dart';
import 'package:alpaso/app/theme/app_spacing.dart';
import 'package:alpaso/core/format/money.dart';
import 'package:alpaso/design/widgets/empty_state.dart';
import 'package:alpaso/features/auth/data/auth_providers.dart';
import 'package:alpaso/features/auth/presentation/auth_form_widgets.dart';
import 'package:alpaso/features/booking/data/booking_providers.dart';
import 'package:alpaso/features/booking/data/booking_repository.dart';
import 'package:alpaso/features/booking/domain/booking.dart';
import 'package:alpaso/features/booking/presentation/booking_messages.dart';
import 'package:alpaso/features/explore/data/explore_providers.dart';
import 'package:alpaso/features/explore/presentation/explore_messages.dart';
import 'package:alpaso/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// C5. Resumen de la reserva, extras y total del servidor. Al confirmar se
/// crea la reserva con el cuarto retenido y se abre el pago.
class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({
    required this.lodgingId,
    required this.roomTypeId,
    super.key,
  });

  final String lodgingId;
  final String roomTypeId;

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  /// Una clave por intento: reintentar no crea otra reserva.
  final _idempotencyKey = newIdempotencyKey();
  final _items = <String, int>{};

  /// Nula si la llegada es "ahora": se calcula al cotizar y al confirmar,
  /// para que esperar en esta pantalla no deje la llegada en el pasado.
  late final DateTime? _chosenArrival;
  late final int _hours;
  Future<Quote>? _quote;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final query = ref.read(searchQueryProvider);
    _chosenArrival = query.arrival;
    _hours = query.blockHours;
    _refreshQuote();
  }

  DateTime get _arrival => _chosenArrival ?? ref.read(clockProvider)();

  void _refreshQuote() {
    final repository = ref.read(bookingRepositoryProvider);
    if (repository == null) return;
    setState(() {
      _quote = repository.quote(
        roomTypeId: widget.roomTypeId,
        arrival: _arrival,
        blockHours: _hours,
        items: Map.of(_items),
      );
    });
  }

  void _change(String productId, int delta) {
    final next = ((_items[productId] ?? 0) + delta).clamp(0, 10);
    if (next == 0) {
      _items.remove(productId);
    } else {
      _items[productId] = next;
    }
    _refreshQuote();
  }

  Future<void> _confirm() async {
    final repository = ref.read(bookingRepositoryProvider);
    if (_busy || repository == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final created = await repository.create(
        roomTypeId: widget.roomTypeId,
        arrival: _arrival,
        blockHours: _hours,
        items: Map.of(_items),
        idempotencyKey: _idempotencyKey,
      );
      ref.invalidate(myBookingsProvider);
      if (mounted) {
        context.pushReplacement(AppRoutes.payment(created.bookingId));
      }
    } on Object catch (error) {
      if (!mounted) return;
      setState(
        () =>
            _error = bookingFailureMessage(AppLocalizations.of(context), error),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final user = ref.watch(authUserProvider).value;
    final now = ref.read(clockProvider)();

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.bookingTitle)),
        body: EmptyState(
          icon: Icons.lock_outline,
          title: l10n.bookingSignInTitle,
          body: l10n.bookingSignInBody,
          action: FilledButton(
            onPressed: () => context.push(AppRoutes.signIn),
            child: Text(l10n.profileSignInAction),
          ),
        ),
      );
    }

    final offer = ref
        .watch(lodgingOfferProvider(widget.lodgingId))
        .value
        ?.where((t) => t.roomTypeId == widget.roomTypeId)
        .firstOrNull;
    final lodging = ref.watch(publicLodgingProvider(widget.lodgingId)).value;
    final menu = ref.watch(menuProvider(widget.lodgingId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.bookingTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: ListTile(
                  title: Text(lodging?.name ?? ''),
                  subtitle: Text(
                    [
                      offer?.name ?? '',
                      l10n.offerFor(
                        _hours,
                        formatArrival(
                          l10n,
                          ref.read(searchQueryProvider).arrival,
                          now,
                        ),
                      ),
                    ].join('\n'),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.bookingExtrasTitle, style: theme.textTheme.titleMedium),
              Text(l10n.bookingExtrasHelp, style: theme.textTheme.bodySmall),
              switch (menu) {
                AsyncData(value: final List<MenuItem> items)
                    when items.isEmpty =>
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    child: Text(l10n.bookingNoExtras),
                  ),
                AsyncData(value: final List<MenuItem> items) => Column(
                  children: [
                    for (final item in items)
                      ListTile(
                        key: Key('extra-${item.productId}'),
                        contentPadding: EdgeInsets.zero,
                        title: Text(item.name),
                        subtitle: Text(formatSoles(item.priceCents)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: l10n.bookingLess(item.name),
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: (_items[item.productId] ?? 0) == 0
                                  ? null
                                  : () => _change(item.productId, -1),
                            ),
                            Text('${_items[item.productId] ?? 0}'),
                            IconButton(
                              tooltip: l10n.bookingMore(item.name),
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: (_items[item.productId] ?? 0) >= 10
                                  ? null
                                  : () => _change(item.productId, 1),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                AsyncError() => Text(l10n.authErrorNetwork),
                _ => const LinearProgressIndicator(),
              },
              const SizedBox(height: AppSpacing.md),
              FutureBuilder<Quote>(
                future: _quote,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return FormErrorBox(
                      message: bookingFailureMessage(l10n, snapshot.error!),
                    );
                  }
                  final quote = snapshot.data;
                  if (quote == null) return const LinearProgressIndicator();
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        children: [
                          _Line(
                            l10n.bookingRoomLine(_hours),
                            quote.roomPriceCents,
                          ),
                          for (final line in quote.lines)
                            _Line(
                              '${line.quantity} × ${line.name}',
                              line.subtotalCents,
                            ),
                          const Divider(),
                          _Line(
                            l10n.bookingTotal,
                            quote.totalCents,
                            key: const Key('booking-total'),
                            bold: true,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.bookingHoldHelp, style: theme.textTheme.bodySmall),
              Text(l10n.bookingIdHelp, style: theme.textTheme.bodySmall),
              const SizedBox(height: AppSpacing.md),
              if (_error != null) ...[
                FormErrorBox(message: _error!),
                const SizedBox(height: AppSpacing.md),
              ],
              SubmitButton(
                label: l10n.bookingConfirmAction,
                busy: _busy,
                onPressed: _confirm,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.cents, {this.bold = false, super.key});

  final String label;
  final int cents;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(formatSoles(cents), style: style),
        ],
      ),
    );
  }
}
