import 'package:alpaso/features/booking/domain/booking.dart';
import 'package:alpaso/features/booking/domain/booking_failure.dart';
import 'package:alpaso/l10n/app_localizations.dart';

String bookingFailureMessage(AppLocalizations l10n, Object error) {
  final reason = error is BookingFailure
      ? error.reason
      : BookingFailureReason.unknown;
  return switch (reason) {
    BookingFailureReason.noRoomAvailable => l10n.bookingErrorNoRoom,
    BookingFailureReason.pendingBookingExists => l10n.bookingErrorPending,
    BookingFailureReason.adultNotConfirmed => l10n.businessErrorNotAdult,
    BookingFailureReason.phoneNotVerified => l10n.bookingPhoneNeeded,
    BookingFailureReason.accountBlocked => l10n.authErrorBlocked,
    BookingFailureReason.productNotAvailable => l10n.bookingErrorProduct,
    BookingFailureReason.notBookable => l10n.bookingErrorNotBookable,
    BookingFailureReason.arrivalOutOfRange => l10n.exploreErrorArrival,
    BookingFailureReason.invalidStatus => l10n.businessErrorInvalidStatus,
    BookingFailureReason.cancelWindowClosed => l10n.bookingErrorCancelWindow,
    BookingFailureReason.notFound => l10n.bookingErrorNotFound,
    BookingFailureReason.network => l10n.authErrorNetwork,
    BookingFailureReason.unknown => l10n.authErrorUnknown,
  };
}

String bookingStatusLabel(AppLocalizations l10n, BookingStatus status) =>
    switch (status) {
      BookingStatus.pendingPayment => l10n.bookingStatusPending,
      BookingStatus.confirmed => l10n.bookingStatusConfirmed,
      BookingStatus.checkedIn => l10n.bookingStatusCheckedIn,
      BookingStatus.completed => l10n.bookingStatusCompleted,
      BookingStatus.cancelled => l10n.bookingStatusCancelled,
      BookingStatus.expired => l10n.bookingStatusExpired,
      BookingStatus.noShow => l10n.bookingStatusNoShow,
    };

/// "1 h 05 min" o "12 min".
String formatRemaining(Duration d) {
  final minutes = d.inMinutes;
  if (minutes < 60) return '$minutes min';
  return '${d.inHours} h ${(minutes % 60).toString().padLeft(2, '0')} min';
}
