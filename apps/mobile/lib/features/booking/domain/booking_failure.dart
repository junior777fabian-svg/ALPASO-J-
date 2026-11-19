enum BookingFailureReason {
  noRoomAvailable,
  pendingBookingExists,
  adultNotConfirmed,
  accountBlocked,
  productNotAvailable,
  notBookable,
  arrivalOutOfRange,
  invalidStatus,
  cancelWindowClosed,
  notFound,
  network,
  unknown,
}

class BookingFailure implements Exception {
  const BookingFailure(this.reason, [this.debugMessage = '']);

  final BookingFailureReason reason;
  final String debugMessage;

  @override
  String toString() => 'BookingFailure(${reason.name}: $debugMessage)';
}

BookingFailureReason bookingReasonFromServer(String message) =>
    switch (message) {
      'no_room_available' => BookingFailureReason.noRoomAvailable,
      'pending_booking_exists' => BookingFailureReason.pendingBookingExists,
      'adult_not_confirmed' => BookingFailureReason.adultNotConfirmed,
      'account_blocked' => BookingFailureReason.accountBlocked,
      'product_not_available' => BookingFailureReason.productNotAvailable,
      'room_type_not_bookable' => BookingFailureReason.notBookable,
      'arrival_out_of_range' => BookingFailureReason.arrivalOutOfRange,
      'invalid_status' => BookingFailureReason.invalidStatus,
      'cancel_window_closed' => BookingFailureReason.cancelWindowClosed,
      'booking_not_found' ||
      'payment_not_found' => BookingFailureReason.notFound,
      _ => BookingFailureReason.unknown,
    };
