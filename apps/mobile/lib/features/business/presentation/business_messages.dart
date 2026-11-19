import 'package:alpaso/features/business/domain/business_failure.dart';
import 'package:alpaso/features/business/domain/lodging.dart';
import 'package:alpaso/features/business/domain/offer.dart';
import 'package:alpaso/features/business/domain/photo.dart';
import 'package:alpaso/l10n/app_localizations.dart';

String businessFailureMessage(AppLocalizations l10n, Object error) {
  final reason = error is BusinessFailure
      ? error.reason
      : BusinessFailureReason.unknown;
  if (error is BusinessFailure &&
      reason == BusinessFailureReason.lodgingIncomplete &&
      error.missing.isNotEmpty) {
    return '${l10n.businessErrorIncompleteTitle}\n'
        '${missingMessage(l10n, error.missing)}';
  }
  return switch (reason) {
    BusinessFailureReason.adultNotConfirmed => l10n.businessErrorNotAdult,
    BusinessFailureReason.accountBlocked => l10n.authErrorBlocked,
    BusinessFailureReason.tooManyOpenLodgings => l10n.businessErrorTooMany,
    BusinessFailureReason.lodgingIncomplete => l10n.businessErrorIncomplete,
    BusinessFailureReason.invalidStatus => l10n.businessErrorInvalidStatus,
    BusinessFailureReason.notOwner => l10n.businessErrorNotOwner,
    BusinessFailureReason.alcoholDisabled => l10n.businessErrorAlcohol,
    BusinessFailureReason.roomLabelTaken => l10n.businessErrorRoomLabel,
    BusinessFailureReason.invalidData => l10n.businessErrorInvalidData,
    BusinessFailureReason.network => l10n.authErrorNetwork,
    BusinessFailureReason.unknown => l10n.authErrorUnknown,
  };
}

String lodgingStatusLabel(AppLocalizations l10n, LodgingStatus status) =>
    switch (status) {
      LodgingStatus.draft => l10n.lodgingStatusDraft,
      LodgingStatus.pendingReview => l10n.lodgingStatusPending,
      LodgingStatus.published => l10n.lodgingStatusPublished,
      LodgingStatus.rejected => l10n.lodgingStatusRejected,
      LodgingStatus.suspended => l10n.lodgingStatusSuspended,
    };

String lodgingStatusHelp(AppLocalizations l10n, LodgingStatus status) =>
    switch (status) {
      LodgingStatus.draft => l10n.lodgingStatusDraftHelp,
      LodgingStatus.pendingReview => l10n.lodgingStatusPendingHelp,
      LodgingStatus.published => l10n.lodgingStatusPublishedHelp,
      LodgingStatus.rejected => l10n.lodgingStatusRejectedHelp,
      LodgingStatus.suspended => l10n.lodgingStatusSuspendedHelp,
    };

String productCategoryLabel(AppLocalizations l10n, ProductCategory category) =>
    switch (category) {
      ProductCategory.drinks => l10n.productCategoryDrinks,
      ProductCategory.snacks => l10n.productCategorySnacks,
      ProductCategory.personalCare => l10n.productCategoryPersonalCare,
      ProductCategory.alcohol => l10n.productCategoryAlcohol,
      ProductCategory.other => l10n.productCategoryOther,
    };

String photoKindLabel(AppLocalizations l10n, PhotoKind kind) => switch (kind) {
  PhotoKind.room => l10n.photoKindRoom,
  PhotoKind.bathroom => l10n.photoKindBathroom,
  PhotoKind.jacuzzi => l10n.photoKindJacuzzi,
  PhotoKind.other => l10n.photoKindOther,
};

/// Qué falta para enviar a revisión, según lo que devolvió el servidor.
String missingMessage(AppLocalizations l10n, List<String> missing) => [
  for (final m in missing)
    switch (m) {
      'lodging_photo' => l10n.missingLodgingPhoto,
      'room_type_ready' => l10n.missingRoomTypeReady,
      'room_type_photos' => l10n.missingRoomTypePhotos,
      _ => m,
    },
].join('\n');
