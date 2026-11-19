import 'package:alpaso/features/explore/data/explore_repository.dart';
import 'package:alpaso/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

String exploreFailureMessage(AppLocalizations l10n, Object error) {
  final reason = error is ExploreFailure
      ? error.reason
      : ExploreFailureReason.unknown;
  return switch (reason) {
    ExploreFailureReason.arrivalOutOfRange => l10n.exploreErrorArrival,
    ExploreFailureReason.notFound => l10n.exploreErrorNotFound,
    ExploreFailureReason.network => l10n.authErrorNetwork,
    ExploreFailureReason.unknown => l10n.authErrorUnknown,
  };
}

/// "350 m" o "2.4 km".
String formatDistance(int meters) =>
    meters < 1000 ? '$meters m' : '${(meters / 1000).toStringAsFixed(1)} km';

/// Llegada en palabras: "Ahora", "Hoy 21:30", "Mañana 10:00", "sáb 23 nov 18:00".
String formatArrival(AppLocalizations l10n, DateTime? arrival, DateTime now) {
  if (arrival == null) return l10n.arrivalNow;
  final time = DateFormat('HH:mm', 'es').format(arrival);
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(arrival.year, arrival.month, arrival.day);
  final diff = day.difference(today).inDays;
  if (diff == 0) return l10n.arrivalToday(time);
  if (diff == 1) return l10n.arrivalTomorrow(time);
  return '${DateFormat('EEE d MMM', 'es').format(arrival)} $time';
}
