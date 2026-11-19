/// Motivos por los que el servidor rechazó una operación del modo negocio.
enum BusinessFailureReason {
  adultNotConfirmed,
  accountBlocked,
  tooManyOpenLodgings,
  lodgingIncomplete,
  invalidStatus,
  notOwner,
  alcoholDisabled,
  roomLabelTaken,
  invalidData,
  network,
  unknown,
}

class BusinessFailure implements Exception {
  const BusinessFailure(this.reason, [this.debugMessage = '']);

  final BusinessFailureReason reason;
  final String debugMessage;

  @override
  String toString() => 'BusinessFailure(${reason.name}: $debugMessage)';
}

/// Traduce el código que devuelve el servidor (el texto de `raise
/// exception` o el código de Postgres) a un motivo.
BusinessFailureReason businessReasonFromServer(String message, String? code) {
  return switch (message) {
    'adult_not_confirmed' => BusinessFailureReason.adultNotConfirmed,
    'account_blocked' => BusinessFailureReason.accountBlocked,
    'too_many_open_lodgings' => BusinessFailureReason.tooManyOpenLodgings,
    'lodging_incomplete' => BusinessFailureReason.lodgingIncomplete,
    'invalid_status' => BusinessFailureReason.invalidStatus,
    'not_owner' => BusinessFailureReason.notOwner,
    'alcohol_disabled' => BusinessFailureReason.alcoholDisabled,
    'room_label_taken' => BusinessFailureReason.roomLabelTaken,
    _ => switch (code) {
      '23505' => BusinessFailureReason.roomLabelTaken,
      '23514' || '22P02' || '23503' => BusinessFailureReason.invalidData,
      '42501' => BusinessFailureReason.notOwner,
      _ => BusinessFailureReason.unknown,
    },
  };
}
