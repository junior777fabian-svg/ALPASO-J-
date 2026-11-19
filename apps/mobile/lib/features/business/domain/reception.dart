/// Un extra pedido, como lo ve recepción.
class ReceptionItem {
  const ReceptionItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.status,
  });

  factory ReceptionItem.fromJson(Map<String, dynamic> json) => ReceptionItem(
    id: json['id'] as String,
    name: json['name'] as String,
    quantity: (json['quantity'] as num).toInt(),
    status: json['status'] as String,
  );

  final String id;
  final String name;
  final int quantity;

  /// pending, ready o unavailable.
  final String status;

  bool get isPending => status == 'pending';
}

/// Una llegada o una estadía en curso. Del cliente, solo el nombre.
class ReceptionStay {
  const ReceptionStay({
    required this.bookingId,
    required this.code,
    required this.customerName,
    required this.roomLabel,
    required this.departure,
    this.roomType = '',
    this.arrival,
    this.canCheckIn = false,
    this.items = const [],
  });

  factory ReceptionStay.fromJson(Map<String, dynamic> json) => ReceptionStay(
    bookingId: json['booking_id'] as String,
    code: json['code'] as String,
    customerName: json['customer_name'] as String,
    roomLabel: json['room_label'] as String,
    roomType: (json['room_type'] as String?) ?? '',
    arrival: switch (json['arrival_at']) {
      final String v => DateTime.parse(v).toLocal(),
      _ => null,
    },
    departure: DateTime.parse(json['departure_at'] as String).toLocal(),
    canCheckIn: (json['can_check_in'] as bool?) ?? false,
    items: [
      for (final i
          in ((json['items'] as List?) ?? const [])
              .cast<Map<String, dynamic>>())
        ReceptionItem.fromJson(i),
    ],
  );

  final String bookingId;
  final String code;
  final String customerName;
  final String roomLabel;
  final String roomType;
  final DateTime? arrival;
  final DateTime departure;
  final bool canCheckIn;
  final List<ReceptionItem> items;
}

/// Estado actual de un cuarto.
enum RoomState {
  free,
  reserved,
  occupied,
  cleaning,
  walkIn,
  maintenance,
  inactive;

  static RoomState fromDb(String value) => switch (value) {
    'reserved' || 'hold' => reserved,
    'occupied' => occupied,
    'cleaning' => cleaning,
    'walk_in' => walkIn,
    'maintenance' => maintenance,
    'inactive' => inactive,
    _ => free,
  };
}

class RoomStatus {
  const RoomStatus({
    required this.roomId,
    required this.label,
    required this.roomType,
    required this.state,
    this.occupancyId,
    this.until,
  });

  factory RoomStatus.fromJson(Map<String, dynamic> json) => RoomStatus(
    roomId: json['room_id'] as String,
    label: json['label'] as String,
    roomType: (json['room_type'] as String?) ?? '',
    state: RoomState.fromDb(json['state'] as String),
    occupancyId: json['occupancy_id'] as String?,
    until: switch (json['until']) {
      final String v => DateTime.parse(v).toLocal(),
      _ => null,
    },
  );

  final String roomId;
  final String label;
  final String roomType;
  final RoomState state;
  final String? occupancyId;
  final DateTime? until;
}

class TodayBoard {
  const TodayBoard({
    this.arrivals = const [],
    this.inHouse = const [],
    this.rooms = const [],
  });

  factory TodayBoard.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> list(String key) =>
        ((json[key] as List?) ?? const []).cast<Map<String, dynamic>>();
    return TodayBoard(
      arrivals: list('arrivals').map(ReceptionStay.fromJson).toList(),
      inHouse: list('in_house').map(ReceptionStay.fromJson).toList(),
      rooms: list('rooms').map(RoomStatus.fromJson).toList(),
    );
  }

  final List<ReceptionStay> arrivals;
  final List<ReceptionStay> inHouse;
  final List<RoomStatus> rooms;
}

class StaffMember {
  const StaffMember({
    required this.userId,
    required this.fullName,
    required this.isOwner,
  });

  final String userId;
  final String fullName;
  final bool isOwner;
}

class StaffInvite {
  const StaffInvite({required this.code, required this.expiresAt});

  final String code;
  final DateTime expiresAt;
}

/// Una reserva del hostal, para su dueño.
class HostBooking {
  const HostBooking({
    required this.id,
    required this.code,
    required this.status,
    required this.roomTypeName,
    required this.arrival,
    required this.blockHours,
    required this.totalCents,
  });

  factory HostBooking.fromJson(Map<String, dynamic> json) => HostBooking(
    id: json['id'] as String,
    code: json['code'] as String,
    status: json['status'] as String,
    roomTypeName: switch (json['room_types']) {
      {'name': final String name} => name,
      _ => '',
    },
    arrival: DateTime.parse(json['arrival_at'] as String).toLocal(),
    blockHours: (json['block_hours'] as num).toInt(),
    totalCents: (json['total_cents'] as num).toInt(),
  );

  final String id;
  final String code;
  final String status;
  final String roomTypeName;
  final DateTime arrival;
  final int blockHours;
  final int totalCents;
}
