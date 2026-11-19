import 'package:alpaso/features/business/data/reception_repository.dart';
import 'package:alpaso/features/business/domain/reception.dart';
import 'package:alpaso/l10n/app_localizations.dart';

String receptionFailureMessage(AppLocalizations l10n, Object error) {
  final reason = error is ReceptionFailure
      ? error.reason
      : ReceptionFailureReason.unknown;
  return switch (reason) {
    ReceptionFailureReason.codeNotFound => l10n.receptionErrorCodeNotFound,
    ReceptionFailureReason.codeAlreadyUsed => l10n.receptionErrorCodeUsed,
    ReceptionFailureReason.tooEarly => l10n.receptionErrorTooEarly,
    ReceptionFailureReason.tooLate => l10n.receptionErrorTooLate,
    ReceptionFailureReason.notConfirmed => l10n.receptionErrorNotConfirmed,
    ReceptionFailureReason.roomNotFree => l10n.receptionErrorRoomNotFree,
    ReceptionFailureReason.inviteNotValid => l10n.receptionErrorInvite,
    ReceptionFailureReason.alreadyMember => l10n.receptionErrorAlreadyMember,
    ReceptionFailureReason.notStaff => l10n.receptionErrorNotStaff,
    ReceptionFailureReason.notOwner => l10n.businessErrorNotOwner,
    ReceptionFailureReason.reasonRequired => l10n.receptionErrorReason,
    ReceptionFailureReason.invalidStatus => l10n.businessErrorInvalidStatus,
    ReceptionFailureReason.network => l10n.authErrorNetwork,
    ReceptionFailureReason.unknown => l10n.authErrorUnknown,
  };
}

String roomStateLabel(AppLocalizations l10n, RoomState state) =>
    switch (state) {
      RoomState.free => l10n.roomStateFree,
      RoomState.reserved => l10n.roomStateReserved,
      RoomState.occupied => l10n.roomStateOccupied,
      RoomState.cleaning => l10n.roomStateCleaning,
      RoomState.walkIn => l10n.roomStateWalkIn,
      RoomState.maintenance => l10n.roomStateMaintenance,
      RoomState.inactive => l10n.roomStateInactive,
    };
