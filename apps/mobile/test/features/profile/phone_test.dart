import 'package:alpaso/features/booking/domain/booking.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_account.dart';
import '../../support/fake_booking.dart';
import '../../support/fake_explore.dart';
import '../../support/pump_app.dart';

void main() {
  testWidgets(
    'reservar pide verificar el celular, con el código demo rotulado',
    (tester) async {
      final accounts = FakeAccountServer();
      accounts.currentUser = accounts.seed(
        email: 'a@b.pe',
        password: 'x',
        phoneVerified: false,
      );
      final booking = FakeBookingServer()..menus['l1'] = const <MenuItem>[];
      await tester.pumpAlPaso(
        config: demoServerConfig,
        server: accounts,
        explore: FakeExploreServer()..seedLodging(),
        booking: booking,
        initialLocation: '/reservar/l1/l1-suite',
      );

      expect(find.byKey(const Key('auth-submit')), findsNothing);
      final verify = find.byKey(const Key('booking-verify-phone'));
      await tester.ensureVisible(verify);
      await tester.tap(verify);
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('phone-number')), '12345');
      await tester.tap(find.byKey(const Key('phone-send')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Escribe un celular peruano'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('phone-number')),
        '987 654 321',
      );
      await tester.tap(find.byKey(const Key('phone-send')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('DEMO · No se envía un mensaje real'),
        findsOneWidget,
      );
      expect(find.textContaining('123456'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('phone-code')), '000000');
      await tester.tap(find.byKey(const Key('phone-verify')));
      await tester.pumpAndSettle();
      expect(
        find.text('El código no es correcto o ya venció.'),
        findsOneWidget,
      );

      await tester.enterText(find.byKey(const Key('phone-code')), '123456');
      await tester.tap(find.byKey(const Key('phone-verify')));
      await tester.pumpAndSettle();

      // De vuelta en Reservar, ya se puede confirmar.
      expect(find.byKey(const Key('auth-submit')), findsOneWidget);
      expect(
        accounts.profiles[accounts.currentUser!.id]!.phone,
        '+51987654321',
      );
    },
  );
}
