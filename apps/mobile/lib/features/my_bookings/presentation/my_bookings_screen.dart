import 'package:alpaso/app/router/app_router.dart';
import 'package:alpaso/app/theme/app_spacing.dart';
import 'package:alpaso/core/format/money.dart';
import 'package:alpaso/design/widgets/empty_state.dart';
import 'package:alpaso/features/auth/data/auth_providers.dart';
import 'package:alpaso/features/booking/data/booking_providers.dart';
import 'package:alpaso/features/booking/domain/booking.dart';
import 'package:alpaso/features/booking/presentation/booking_messages.dart';
import 'package:alpaso/features/explore/data/explore_providers.dart';
import 'package:alpaso/features/explore/presentation/explore_messages.dart';
import 'package:alpaso/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// C6. Reservas activas arriba, historial abajo.
class MyBookingsScreen extends ConsumerWidget {
  const MyBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(authUserProvider).value;
    final hasServer = ref.watch(bookingRepositoryProvider) != null;
    final bookings = ref.watch(myBookingsProvider);
    final now = ref.read(clockProvider)();

    Widget body;
    if (!hasServer || user == null) {
      body = EmptyState(
        icon: Icons.confirmation_number_outlined,
        title: l10n.bookingsEmptyTitle,
        body: hasServer ? l10n.bookingsSignInBody : l10n.bookingsEmptyBody,
        action: hasServer
            ? FilledButton(
                onPressed: () => context.push(AppRoutes.signIn),
                child: Text(l10n.profileSignInAction),
              )
            : null,
      );
    } else {
      body = switch (bookings) {
        AsyncData(value: final List<Booking> list) when list.isEmpty =>
          EmptyState(
            icon: Icons.confirmation_number_outlined,
            title: l10n.bookingsEmptyTitle,
            body: l10n.bookingsEmptyBody,
          ),
        AsyncData(value: final List<Booking> list) => RefreshIndicator(
          onRefresh: () => ref.refresh(myBookingsProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              for (final (title, items) in [
                (
                  l10n.bookingsActive,
                  list.where((b) => b.status.isActive).toList(),
                ),
                (
                  l10n.bookingsHistory,
                  list.where((b) => !b.status.isActive).toList(),
                ),
              ])
                if (items.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  for (final b in items)
                    Card(
                      key: Key('booking-${b.id}'),
                      child: ListTile(
                        title: Text(b.lodgingName),
                        subtitle: Text(
                          '${b.roomTypeName} · ${formatArrival(l10n, b.arrival, now)} · ${b.blockHours} h\n'
                          '${bookingStatusLabel(l10n, b.status)} · ${formatSoles(b.totalCents)}',
                        ),
                        trailing: b.status == BookingStatus.confirmed
                            ? Text(
                                b.code,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                      letterSpacing: 2,
                                    ),
                              )
                            : null,
                        onTap: () =>
                            context.push(AppRoutes.bookingDetail(b.id)),
                      ),
                    ),
                ],
            ],
          ),
        ),
        AsyncError(:final error) => EmptyState(
          icon: Icons.error_outline,
          title: l10n.profileLoadErrorTitle,
          body: bookingFailureMessage(l10n, error),
          action: FilledButton(
            onPressed: () => ref.invalidate(myBookingsProvider),
            child: Text(l10n.profileRetryAction),
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      };
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.bookingsTitle)),
      body: body,
    );
  }
}
