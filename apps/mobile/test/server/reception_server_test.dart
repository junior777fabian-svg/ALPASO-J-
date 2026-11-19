@Tags(['server'])
library;

import 'package:alpaso/features/booking/data/booking_repository.dart';
import 'package:alpaso/features/business/data/business_repository.dart';
import 'package:alpaso/features/business/data/reception_repository.dart';
import 'package:alpaso/features/business/domain/offer.dart';
import 'package:alpaso/features/business/domain/reception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'server_support.dart';

Matcher _failsWith(ReceptionFailureReason reason) =>
    throwsA(isA<ReceptionFailure>().having((f) => f.reason, 'reason', reason));

void main() {
  final run = DateTime.now().microsecondsSinceEpoch;

  group(
    'recepción contra el servidor',
    skip: hasAdminServer ? null : 'sin servidor o sin llave',
    () {
      late SupabaseClient admin;
      late SupabaseClient owner;
      late SupabaseClient rosa;
      late SupabaseClient carla;
      late SupabaseReceptionRepository ownerDesk;
      late SupabaseReceptionRepository rosaDesk;
      late String lodgingId;
      late String roomTypeId;
      late String code;
      late String bookingId;

      setUpAll(() async {
        admin = phone(secretKey);
        owner = await adultAccount('duena.recep.$run@example.test');
        rosa = await adultAccount('rosa.recep.$run@example.test');
        carla = await adultAccount('carla.recep.$run@example.test');
        final ids = await publishLodging(
          owner: owner,
          admin: admin,
          name: 'Hostal Recepción $run',
          spot: const LatLng(-12.35, -76.85),
          roomType: const RoomTypeDraft(
            name: 'Simple',
            rates: {4: 4000},
            rooms: ['101', '102'],
          ),
        );
        lodgingId = ids.lodgingId;
        roomTypeId = ids.roomTypeId;
        await SupabaseBusinessRepository(owner).saveProduct(
          lodgingId,
          const ProductDraft(
            name: 'Agua',
            category: ProductCategory.drinks,
            priceCents: 300,
          ),
        );
        final productId = (await SupabaseBusinessRepository(
          owner,
        ).products(lodgingId)).single.id;

        // Carla reserva para dentro de 5 minutos, con 2 aguas, y paga.
        final carlaBookings = SupabaseBookingRepository(carla);
        final created = await carlaBookings.create(
          roomTypeId: roomTypeId,
          arrival: DateTime.now().add(const Duration(minutes: 5)),
          blockHours: 4,
          items: {productId: 2},
          idempotencyKey: newIdempotencyKey(),
        );
        bookingId = created.bookingId;
        code = created.code;
        final session = await carlaBookings.startPayment(bookingId);
        await carlaBookings.completeDemoPayment(
          session.paymentId,
          approved: true,
        );

        ownerDesk = SupabaseReceptionRepository(owner);
        rosaDesk = SupabaseReceptionRepository(rosa);
      });

      tearDownAll(() async {
        for (final c in [admin, owner, rosa, carla]) {
          await c.dispose();
        }
      });

      test('sin invitación, Rosa no ve el tablero', () async {
        await expectLater(
          rosaDesk.today(lodgingId),
          _failsWith(ReceptionFailureReason.notStaff),
        );
      });

      test('la dueña invita y Rosa se une con el código', () async {
        final invite = await ownerDesk.invite(lodgingId);
        expect(invite.code, matches(RegExp(r'^[A-Z0-9]{8}$')));
        expect(
          await rosaDesk.acceptInvite(invite.code.toLowerCase()),
          'Hostal Recepción $run',
        );
        await expectLater(
          rosaDesk.acceptInvite(invite.code),
          _failsWith(ReceptionFailureReason.inviteNotValid),
        );
        final staff = await ownerDesk.staff(lodgingId);
        expect(staff.where((m) => !m.isOwner), hasLength(1));
      });

      test(
        'el tablero muestra la llegada con el nombre y los extras',
        () async {
          final board = await rosaDesk.today(lodgingId);
          final arrival = board.arrivals.single;
          expect(arrival.code, code);
          expect(arrival.customerName, 'Prueba');
          expect(arrival.canCheckIn, isTrue);
          expect(arrival.items.single.quantity, 2);
          expect(board.rooms, hasLength(2));
        },
      );

      test('el ingreso con el QR funciona una sola vez', () async {
        final stay = await rosaDesk.checkIn(
          lodgingId,
          'alpaso:${code.toLowerCase()}',
        );
        expect(stay.roomLabel, '101');
        await expectLater(
          rosaDesk.checkIn(lodgingId, code),
          _failsWith(ReceptionFailureReason.codeAlreadyUsed),
        );
        final board = await rosaDesk.today(lodgingId);
        expect(board.inHouse.single.bookingId, bookingId);
      });

      test('el agua que falta se reembolsa', () async {
        final item = (await rosaDesk.today(lodgingId))
            .inHouse
            .single
            .items
            .single;
        expect(await rosaDesk.setItemStatus(item.id, 'unavailable'), 600);
      });

      test('salida, limpieza y cuarto libre', () async {
        await rosaDesk.checkOut(bookingId);
        var room = (await rosaDesk.today(lodgingId)).rooms
            .firstWhere((r) => r.label == '101');
        expect(room.state, RoomState.cleaning);
        await rosaDesk.markClean(room.roomId);
        room = (await rosaDesk.today(lodgingId)).rooms
            .firstWhere((r) => r.label == '101');
        expect(room.state, RoomState.free);
      });

      test('cliente directo en el 102, y se libera', () async {
        var room = (await rosaDesk.today(lodgingId)).rooms
            .firstWhere((r) => r.label == '102');
        await rosaDesk.blockRoom(room.roomId, 'walk_in', 120);
        room = (await rosaDesk.today(lodgingId)).rooms
            .firstWhere((r) => r.label == '102');
        expect(room.state, RoomState.walkIn);
        await rosaDesk.releaseBlock(room.occupancyId!);
        room = (await rosaDesk.today(lodgingId)).rooms
            .firstWhere((r) => r.label == '102');
        expect(room.state, RoomState.free);
      });

      test('la recepcionista no cancela; la dueña sí, con motivo', () async {
        final carlaBookings = SupabaseBookingRepository(carla);
        final created = await carlaBookings.create(
          roomTypeId: roomTypeId,
          arrival: DateTime.now().add(const Duration(hours: 5)),
          blockHours: 4,
          items: const {},
          idempotencyKey: newIdempotencyKey(),
        );
        final session = await carlaBookings.startPayment(created.bookingId);
        await carlaBookings.completeDemoPayment(
          session.paymentId,
          approved: true,
        );

        await expectLater(
          rosaDesk.cancelBooking(created.bookingId, 'Prueba'),
          _failsWith(ReceptionFailureReason.notOwner),
        );
        await expectLater(
          ownerDesk.cancelBooking(created.bookingId, ' '),
          _failsWith(ReceptionFailureReason.reasonRequired),
        );
        expect(
          await ownerDesk.cancelBooking(created.bookingId, 'Corte de agua'),
          4000,
        );
        final list = await ownerDesk.bookings(lodgingId);
        expect(
          list.firstWhere((b) => b.id == created.bookingId).status,
          'cancelled',
        );
      });

      test('retirada, Rosa deja de ver el tablero', () async {
        final rosaId = rosa.auth.currentUser!.id;
        await ownerDesk.revoke(lodgingId, rosaId);
        await expectLater(
          rosaDesk.today(lodgingId),
          _failsWith(ReceptionFailureReason.notStaff),
        );
      });
    },
  );
}
