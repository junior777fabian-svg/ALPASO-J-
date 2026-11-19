@Tags(['server'])
library;

import 'package:alpaso/features/booking/data/booking_repository.dart';
import 'package:alpaso/features/booking/domain/booking.dart';
import 'package:alpaso/features/booking/domain/booking_failure.dart';
import 'package:alpaso/features/business/data/business_repository.dart';
import 'package:alpaso/features/business/domain/offer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'server_support.dart';

/// Cliente HTTP que falla como sin señal cuando [offline] es verdadero.
class _SwitchableClient extends http.BaseClient {
  final _inner = http.Client();
  bool offline = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (offline) {
      throw http.ClientException('sin conexión (prueba)', request.url);
    }
    return _inner.send(request);
  }
}

Matcher _failsWith(BookingFailureReason reason) =>
    throwsA(isA<BookingFailure>().having((f) => f.reason, 'reason', reason));

void main() {
  final run = DateTime.now().microsecondsSinceEpoch;
  final arrival = DateTime.now().add(const Duration(hours: 3));

  group(
    'reservas contra el servidor',
    skip: hasAdminServer ? null : 'sin servidor o sin llave',
    () {
      late SupabaseClient owner;
      late SupabaseClient admin;
      late SupabaseClient ana;
      late SupabaseClient luis;
      late SupabaseBookingRepository anaBookings;
      late String lodgingId;
      late String roomTypeId;
      late String productId;
      late String bookingId;

      setUpAll(() async {
        // La caché de "Mis reservas", en memoria.
        SharedPreferences.setMockInitialValues({});
        admin = phone(secretKey);
        owner = await adultAccount('duena.reserva.$run@example.test');
        final ids = await publishLodging(
          owner: owner,
          admin: admin,
          name: 'Hostal Reserva $run',
          spot: const LatLng(-12.3, -76.8),
        );
        lodgingId = ids.lodgingId;
        roomTypeId = ids.roomTypeId;
        await SupabaseBusinessRepository(owner).saveProduct(
          lodgingId,
          const ProductDraft(
            name: 'Gaseosa',
            category: ProductCategory.drinks,
            priceCents: 400,
          ),
        );
        productId = (await SupabaseBusinessRepository(
          owner,
        ).products(lodgingId)).single.id;

        ana = await adultAccount('ana.reserva.$run@example.test');
        luis = await adultAccount('luis.reserva.$run@example.test');
        anaBookings = SupabaseBookingRepository(ana);
      });

      tearDownAll(() async {
        for (final c in [owner, admin, ana, luis]) {
          await c.dispose();
        }
      });

      test('la carta y la cotización vienen del servidor', () async {
        final menu = await anaBookings.menu(lodgingId);
        expect(menu.single.name, 'Gaseosa');
        final quote = await anaBookings.quote(
          roomTypeId: roomTypeId,
          arrival: arrival,
          blockHours: 4,
          items: {productId: 3},
        );
        expect(quote.roomPriceCents, 4500);
        expect(quote.extrasCents, 1200);
        expect(quote.totalCents, 5700);
      });

      test(
        'dos personas a la vez por el único cuarto: solo una lo obtiene',
        () async {
          final results = await Future.wait([
            for (final client in [ana, luis])
              SupabaseBookingRepository(client)
                  .create(
                    roomTypeId: roomTypeId,
                    arrival: arrival,
                    blockHours: 4,
                    items: {productId: 1},
                    idempotencyKey: newIdempotencyKey(),
                  )
                  .then<Object>((b) => b, onError: (Object e) => e),
          ]);
          final created = results.whereType<CreatedBooking>().toList();
          final failed = results.whereType<BookingFailure>().toList();
          expect(created, hasLength(1));
          expect(failed.single.reason, BookingFailureReason.noRoomAvailable);

          // Quien la obtuvo la cancela, para seguir con Ana.
          final winner = results.indexWhere((r) => r is CreatedBooking) == 0
              ? ana
              : luis;
          await SupabaseBookingRepository(winner)
              .cancel(created.single.bookingId);
        },
      );

      test('reserva, paga en demo y queda confirmada', () async {
        final key = newIdempotencyKey();
        final created = await anaBookings.create(
          roomTypeId: roomTypeId,
          arrival: arrival,
          blockHours: 4,
          items: {productId: 2},
          idempotencyKey: key,
        );
        bookingId = created.bookingId;
        expect(created.totalCents, 5300);
        expect(created.code, matches(RegExp(r'^[A-Z0-9]{6}$')));

        final again = await anaBookings.create(
          roomTypeId: roomTypeId,
          arrival: arrival,
          blockHours: 4,
          items: {productId: 2},
          idempotencyKey: key,
        );
        expect(again.bookingId, bookingId, reason: 'reintento idempotente');

        final session = await anaBookings.startPayment(bookingId);
        expect(session.isDemo, isTrue);
        expect(session.amountCents, 5300);
        expect(
          await anaBookings.completeDemoPayment(
            session.paymentId,
            approved: true,
          ),
          'paid',
        );

        final booking = await anaBookings.booking(bookingId);
        expect(booking.status, BookingStatus.confirmed);
        expect(booking.items.single.quantity, 2);
        expect(booking.lodgingName, 'Hostal Reserva $run');
      });

      test('otra cuenta no ve ni cancela la reserva', () async {
        await expectLater(
          SupabaseBookingRepository(luis).booking(bookingId),
          _failsWith(BookingFailureReason.notFound),
        );
        await expectLater(
          SupabaseBookingRepository(luis).cancel(bookingId),
          _failsWith(BookingFailureReason.notFound),
        );
      });

      test(
        'mis reservas la incluye, y la guarda para verla sin conexión',
        () async {
          // Un teléfono de Ana cuya conexión la prueba puede cortar.
          final network = _SwitchableClient();
          final annaPhone = SupabaseClient(
            serverUrl,
            publishableKey,
            httpClient: network,
            authOptions: const AuthClientOptions(
              autoRefreshToken: false,
              authFlowType: AuthFlowType.implicit,
            ),
          );
          addTearDown(annaPhone.dispose);
          await annaPhone.auth.signInWithPassword(
            email: 'ana.reserva.$run@example.test',
            password: 'Clave-de-prueba-1',
          );
          final repository = SupabaseBookingRepository(annaPhone);

          final online = await repository.myBookings();
          expect(online.map((b) => b.id), contains(bookingId));

          network.offline = true;
          final cached = await repository.myBookings();
          expect(cached.map((b) => b.id), contains(bookingId));
          expect(
            cached.firstWhere((b) => b.id == bookingId).code,
            online.firstWhere((b) => b.id == bookingId).code,
            reason: 'el código se ve sin conexión',
          );
        },
      );

      test('cancelar a tiempo reembolsa todo y libera el cuarto', () async {
        expect(await anaBookings.cancel(bookingId), 5300);
        final booking = await anaBookings.booking(bookingId);
        expect(booking.status, BookingStatus.cancelled);
        expect(booking.refundCents, 5300);

        final again = await SupabaseBookingRepository(luis).create(
          roomTypeId: roomTypeId,
          arrival: arrival,
          blockHours: 4,
          items: const {},
          idempotencyKey: newIdempotencyKey(),
        );
        expect(again.totalCents, 4500, reason: 'el cuarto quedó libre');
      });
    },
  );
}
