import 'package:alpaso/features/auth/domain/auth_failure.dart';
import 'package:alpaso/l10n/app_localizations.dart';

/// Mensaje para el usuario según el motivo del error.
String authFailureMessage(AppLocalizations l10n, Object error) {
  final reason = error is AuthFailure
      ? error.reason
      : AuthFailureReason.unknown;
  return switch (reason) {
    AuthFailureReason.invalidCredentials => l10n.authErrorInvalidCredentials,
    AuthFailureReason.emailInUse => l10n.authErrorEmailInUse,
    AuthFailureReason.weakPassword => l10n.authErrorWeakPassword,
    AuthFailureReason.invalidEmail => l10n.authErrorInvalidEmail,
    AuthFailureReason.emailNotConfirmed => l10n.authErrorEmailNotConfirmed,
    AuthFailureReason.rateLimited => l10n.authErrorRateLimited,
    AuthFailureReason.signupDisabled => l10n.authErrorSignupDisabled,
    AuthFailureReason.network => l10n.authErrorNetwork,
    AuthFailureReason.blocked => l10n.authErrorBlocked,
    AuthFailureReason.activeBookings => l10n.deleteErrorActiveBookings,
    AuthFailureReason.ownsLodgings => l10n.deleteErrorOwnsLodgings,
    AuthFailureReason.unknown => l10n.authErrorUnknown,
  };
}
