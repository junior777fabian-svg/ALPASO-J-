import 'package:alpaso/features/business/data/reception_repository.dart';
import 'package:alpaso/features/business/domain/reception.dart';

/// Recepción en memoria, con las reglas que prueban las pantallas.
class FakeReceptionServer implements ReceptionRepository {
  FakeReceptionServer({DateTime? now})
    : now = now ?? DateTime(2026, 11, 19, 20);

  final DateTime now;
  final arrivals = <ReceptionStay>[];
  final inHouse = <ReceptionStay>[];
  final rooms = <String, RoomStatus>{};
  final used = <String>{};
  final hostBookings = <HostBooking>[];
  final staffList = <StaffMember>[
    const StaffMember(userId: 'u-owner', fullName: 'Ana', isOwner: true),
  ];
  final calls = <String>[];
  final invites = <String>{'ABCD2345'};

  void seedDay() {
    arrivals.add(
      ReceptionStay(
        bookingId: 'b1',
        code: 'K7X9QA',
        customerName: 'Carla',
        roomLabel: '101',
        roomType: 'Simple',
        arrival: now.add(const Duration(minutes: 10)),
        departure: now.add(const Duration(hours: 4, minutes: 10)),
        canCheckIn: true,
        items: const [
          ReceptionItem(id: 'i1', name: 'Agua', quantity: 2, status: 'pending'),
        ],
      ),
    );
    rooms['r101'] = const RoomStatus(
      roomId: 'r101',
      label: '101',
      roomType: 'Simple',
      state: RoomState.reserved,
    );
    rooms['r102'] = const RoomStatus(
      roomId: 'r102',
      label: '102',
      roomType: 'Simple',
      state: RoomState.free,
    );
    rooms['r103'] = RoomStatus(
      roomId: 'r103',
      label: '103',
      roomType: 'Simple',
      state: RoomState.cleaning,
      until: now.add(const Duration(minutes: 15)),
    );
  }

  RoomStatus _room(String id, RoomState state, {String? occupancyId}) {
    final r = rooms[id]!;
    return RoomStatus(
      roomId: r.roomId,
      label: r.label,
      roomType: r.roomType,
      state: state,
      occupancyId: occupancyId,
    );
  }

  @override
  Future<TodayBoard> today(String lodgingId) async => TodayBoard(
    arrivals: List.of(arrivals),
    inHouse: List.of(inHouse),
    rooms: rooms.values.toList(),
  );

  @override
  Future<ReceptionStay> checkIn(String lodgingId, String code) async {
    final clean = code.trim().toUpperCase().replaceAll('ALPASO:', '');
    if (used.contains(clean)) {
      throw const ReceptionFailure(ReceptionFailureReason.codeAlreadyUsed);
    }
    final stay = arrivals.where((a) => a.code == clean).firstOrNull;
    if (stay == null) {
      throw const ReceptionFailure(ReceptionFailureReason.codeNotFound);
    }
    used.add(clean);
    arrivals.remove(stay);
    inHouse.add(stay);
    rooms['r101'] = _room('r101', RoomState.occupied);
    return stay;
  }

  @override
  Future<void> checkOut(String bookingId) async {
    calls.add('checkout:$bookingId');
    inHouse.removeWhere((s) => s.bookingId == bookingId);
    rooms['r101'] = _room('r101', RoomState.cleaning);
  }

  @override
  Future<void> markClean(String roomId) async {
    calls.add('clean:$roomId');
    rooms[roomId] = _room(roomId, RoomState.free);
  }

  @override
  Future<void> blockRoom(String roomId, String kind, int minutes) async {
    calls.add('block:$roomId:$kind:$minutes');
    rooms[roomId] = _room(
      roomId,
      kind == 'walk_in' ? RoomState.walkIn : RoomState.maintenance,
      occupancyId: 'occ-$roomId',
    );
  }

  @override
  Future<void> releaseBlock(String occupancyId) async {
    calls.add('release:$occupancyId');
    final roomId = occupancyId.replaceFirst('occ-', '');
    rooms[roomId] = _room(roomId, RoomState.free);
  }

  @override
  Future<int> setItemStatus(String itemId, String status) async {
    calls.add('item:$itemId:$status');
    ReceptionStay mark(ReceptionStay s) => ReceptionStay(
      bookingId: s.bookingId,
      code: s.code,
      customerName: s.customerName,
      roomLabel: s.roomLabel,
      roomType: s.roomType,
      arrival: s.arrival,
      departure: s.departure,
      canCheckIn: s.canCheckIn,
      items: [
        for (final i in s.items)
          i.id == itemId
              ? ReceptionItem(
                  id: i.id,
                  name: i.name,
                  quantity: i.quantity,
                  status: status,
                )
              : i,
      ],
    );
    for (var k = 0; k < arrivals.length; k++) {
      arrivals[k] = mark(arrivals[k]);
    }
    return status == 'unavailable' ? 600 : 0;
  }

  @override
  Future<List<HostBooking>> bookings(String lodgingId) async =>
      List.of(hostBookings);

  @override
  Future<int> cancelBooking(String bookingId, String reason) async {
    if (reason.trim().isEmpty) {
      throw const ReceptionFailure(ReceptionFailureReason.reasonRequired);
    }
    calls.add('cancel:$bookingId:$reason');
    final i = hostBookings.indexWhere((b) => b.id == bookingId);
    final b = hostBookings[i];
    hostBookings[i] = HostBooking(
      id: b.id,
      code: b.code,
      status: 'cancelled',
      roomTypeName: b.roomTypeName,
      arrival: b.arrival,
      blockHours: b.blockHours,
      totalCents: b.totalCents,
    );
    return b.totalCents;
  }

  @override
  Future<List<StaffMember>> staff(String lodgingId) async => List.of(staffList);

  @override
  Future<StaffInvite> invite(String lodgingId) async => StaffInvite(
    code: 'QWER7934',
    expiresAt: now.add(const Duration(hours: 48)),
  );

  @override
  Future<String> acceptInvite(String code) async {
    if (!invites.remove(code.trim().toUpperCase())) {
      throw const ReceptionFailure(ReceptionFailureReason.inviteNotValid);
    }
    return 'Hostal Sol';
  }

  @override
  Future<void> revoke(String lodgingId, String userId) async {
    staffList.removeWhere((m) => m.userId == userId);
  }
}
