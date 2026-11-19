import 'package:alpaso/features/business/domain/lodging.dart';
import 'package:alpaso/features/business/domain/offer.dart';
import 'package:alpaso/features/business/domain/photo.dart';
import 'package:alpaso/features/business/presentation/lodging_detail_screen.dart';
import 'package:alpaso/features/business/presentation/room_type_form_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_account.dart';
import '../../support/fake_business.dart';
import '../../support/pump_app.dart';

typedef Setup = ({FakeBusinessServer business, Lodging lodging});

Future<Setup> openLodging(
  WidgetTester tester, {
  Future<void> Function(FakeBusinessServer, Lodging)? before,
}) async {
  final accounts = FakeAccountServer();
  accounts.currentUser = accounts.seed(
    email: 'ana@correo.pe',
    password: 'clave-segura',
  );
  final business = FakeBusinessServer(accounts);
  final lodging = business.seed(accounts.currentUser!.id);
  await before?.call(business, lodging);
  await tester.pumpAlPaso(
    config: demoServerConfig,
    server: accounts,
    business: business,
    initialLocation: '/negocio/hostal/${lodging.id}',
  );
  return (business: business, lodging: lodging);
}

Future<void> tapText(WidgetTester tester, String text) async {
  // Un campo con foco vuelve a desplazar la pantalla hacia él.
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
  final finder = find.text(text);
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: find.byType(Scrollable).hitTestable().first,
    );
  }
  await tester.ensureVisible(finder.last);
  // Espera a que termine el desplazamiento antes de tocar.
  await tester.pumpAndSettle();
  await tester.tap(finder.last);
  await tester.pumpAndSettle();
}

Future<void> save(WidgetTester tester) async {
  final button = find.byKey(const Key('auth-submit'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> fillRoomType(
  WidgetTester tester, {
  String name = 'Matrimonial',
  Map<int, String> rates = const {4: '45', 12: '90.50'},
  String rooms = '201, 202',
}) async {
  await tester.enterText(find.byKey(const Key('room-type-name')), name);
  for (final e in rates.entries) {
    await tester.enterText(find.byKey(Key('rate-${e.key}')), e.value);
  }
  await tester.enterText(find.byKey(const Key('room-type-rooms')), rooms);
}

void main() {
  testWidgets('agrega un tipo de cuarto con precios y cuartos', (tester) async {
    final s = await openLodging(tester);
    expect(find.textContaining('Todavía no hay tipos de cuarto'), findsOne);

    await tapText(tester, 'Agregar tipo de cuarto');
    expect(find.byType(RoomTypeFormScreen), findsOneWidget);
    await fillRoomType(tester, rooms: '201, 202 203,201');
    await save(tester);

    expect(find.byType(LodgingDetailScreen), findsOneWidget);
    expect(find.text('Matrimonial'), findsOneWidget);
    expect(
      find.text(
        '4 h S/ 45.00 · 12 h S/ 90.50\nCuartos: 201, 202, 203\n'
        'Faltan fotos: Habitación, Baño',
      ),
      findsOneWidget,
    );
    final saved = s.business.roomTypesByLodging[s.lodging.id]!.single;
    expect(saved.draft.rates, {4: 4500, 12: 9050});
    expect(saved.draft.rooms, ['201', '202', '203']);
  });

  testWidgets('exige al menos un precio y precios válidos', (tester) async {
    final s = await openLodging(tester);
    await tapText(tester, 'Agregar tipo de cuarto');

    await fillRoomType(tester, rates: const {});
    await save(tester);
    expect(find.text('Pon precio al menos a un bloque.'), findsOneWidget);

    await fillRoomType(tester, rates: const {6: '0.50'});
    await save(tester);
    expect(find.textContaining('Escribe un precio entre S/ 1'), findsOneWidget);
    expect(s.business.roomTypesByLodging[s.lodging.id], isNull);
  });

  testWidgets('un número de cuarto repetido muestra el aviso', (tester) async {
    final s = await openLodging(tester);
    await s.business.saveRoomType(
      s.lodging.id,
      const RoomTypeDraft(name: 'Simple', rates: {4: 3000}, rooms: ['101']),
    );
    await tapText(tester, 'Agregar tipo de cuarto');
    await fillRoomType(tester, rooms: '101');
    await save(tester);

    expect(find.text('Ese número de cuarto ya existe en tu hostal.'), findsOne);
    expect(find.byType(RoomTypeFormScreen), findsOneWidget);
  });

  testWidgets('edita un tipo de cuarto y lo oculta', (tester) async {
    late String id;
    final s = await openLodging(
      tester,
      before: (business, lodging) async {
        id = await business.saveRoomType(
          lodging.id,
          const RoomTypeDraft(name: 'Simple', rates: {4: 3000}, rooms: ['101']),
        );
      },
    );

    await tester.scrollUntilVisible(
      find.byKey(Key('room-type-$id')),
      300,
      scrollable: find.byType(Scrollable).hitTestable().first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('room-type-$id')));
    await tester.pumpAndSettle();
    expect(find.text('30'), findsOneWidget, reason: 'el precio cargado');
    await tester.enterText(find.byKey(const Key('rate-4')), '35');
    await tapText(tester, 'Visible para los clientes');
    await save(tester);

    final saved = s.business.roomTypesByLodging[s.lodging.id]!.single;
    expect(saved.draft.rates, {4: 3500});
    expect(saved.draft.isActive, isFalse);
    expect(find.text('Simple (oculto)'), findsOneWidget);
  });

  testWidgets('sin fotos, el envío a revisión dice qué falta', (tester) async {
    final s = await openLodging(tester);
    await tapText(tester, 'Agregar tipo de cuarto');
    await fillRoomType(tester);
    await save(tester);
    expect(find.textContaining('Faltan fotos: Habitación, Baño'), findsOne);

    await tapText(tester, 'Enviar a revisión');
    expect(find.textContaining('Al menos una foto del hostal'), findsOne);
    expect(find.textContaining('foto de la habitación y del baño'), findsOne);
    expect(s.business.lodgings[s.lodging.id]!.status, LodgingStatus.draft);
  });

  testWidgets('con fotos del hostal y del cuarto, se envía a revisión', (
    tester,
  ) async {
    late String typeId;
    final s = await openLodging(
      tester,
      before: (business, lodging) async {
        typeId = await business.saveRoomType(
          lodging.id,
          const RoomTypeDraft(
            name: 'Suite',
            hasJacuzzi: true,
            rates: {4: 4500},
            rooms: ['201'],
          ),
        );
      },
    );

    // Foto del hostal, desde su ficha.
    await tapText(tester, 'Agregar foto');
    await tapText(tester, 'Elegir de la galería');
    expect(s.business.lodgingPhotosByLodging[s.lodging.id], hasLength(1));

    // Fotos del cuarto, desde su formulario: habitación, baño y jacuzzi.
    await tester.scrollUntilVisible(
      find.byKey(Key('room-type-$typeId')),
      300,
      scrollable: find.byType(Scrollable).hitTestable().first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('room-type-$typeId')));
    await tester.pumpAndSettle();
    for (final kind in ['room', 'bathroom', 'jacuzzi']) {
      final add = find.descendant(
        of: find.byKey(Key('photos-$kind')),
        matching: find.text('Agregar foto'),
      );
      await tester.ensureVisible(add);
      await tester.pumpAndSettle();
      await tester.tap(add);
      await tester.pumpAndSettle();
      await tapText(tester, 'Tomar foto');
    }
    final type = s.business.roomTypesByLodging[s.lodging.id]!.single;
    expect(type.missingPhotos, isEmpty);
    // pageBack() busca el botón de Material anterior; aquí se toca por su
    // descripción.
    await tester.tap(find.byTooltip('Atrás'));
    await tester.pumpAndSettle();

    await tapText(tester, 'Enviar a revisión');
    expect(
      s.business.lodgings[s.lodging.id]!.status,
      LodgingStatus.pendingReview,
    );
  });

  testWidgets('quitar una foto la borra y cancelar no sube nada', (
    tester,
  ) async {
    final picker = FakePhotoPicker()..cancel = true;
    final accounts = FakeAccountServer();
    accounts.currentUser = accounts.seed(email: 'a@b.pe', password: 'x');
    final business = FakeBusinessServer(accounts);
    final lodging = business.seed(accounts.currentUser!.id);
    await business.addLodgingPhoto(
      lodging.id,
      const PickedPhoto(bytes: [1], mimeType: 'image/jpeg'),
    );
    await tester.pumpAlPaso(
      config: demoServerConfig,
      server: accounts,
      business: business,
      picker: picker,
      initialLocation: '/negocio/hostal/${lodging.id}',
    );

    await tapText(tester, 'Agregar foto');
    await tapText(tester, 'Elegir de la galería');
    expect(picker.picks, 1);
    expect(business.lodgingPhotosByLodging[lodging.id], hasLength(1));

    await tester.ensureVisible(find.byTooltip('Quitar foto'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Quitar foto'));
    await tester.pumpAndSettle();
    expect(business.lodgingPhotosByLodging[lodging.id], isEmpty);
  });

  testWidgets('agrega un extra a la carta', (tester) async {
    final s = await openLodging(tester);
    await tapText(tester, 'Agregar extra');

    await tester.enterText(find.byKey(const Key('product-name')), 'Gaseosa');
    await tester.tap(find.byKey(const Key('product-category')));
    await tester.pumpAndSettle();
    expect(find.text('Licores'), findsNothing, reason: 'licores apagados');
    await tester.tap(find.text('Bebidas').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('product-price')), '4.5');
    await save(tester);

    expect(find.text('Gaseosa'), findsOneWidget);
    expect(find.text('S/ 4.50'), findsOneWidget);
    final product = s.business.productsByLodging[s.lodging.id]!.single;
    expect(product.draft.priceCents, 450);
    expect(product.draft.category, ProductCategory.drinks);
  });

  testWidgets('un extra sin precio válido no se guarda', (tester) async {
    final s = await openLodging(tester);
    await tapText(tester, 'Agregar extra');
    await tester.enterText(find.byKey(const Key('product-name')), 'Agua');
    await tester.enterText(find.byKey(const Key('product-price')), 'gratis');
    await save(tester);

    expect(find.text('Elige la categoría.'), findsOneWidget);
    expect(find.textContaining('Escribe un precio entre S/ 0.50'), findsOne);
    expect(s.business.productsByLodging[s.lodging.id], isNull);
  });
}
