import 'package:alpaso/features/business/data/business_repository.dart';
import 'package:alpaso/features/business/data/photo_picker.dart';
import 'package:alpaso/features/business/domain/business_failure.dart';
import 'package:alpaso/features/business/domain/lodging.dart';
import 'package:alpaso/features/business/domain/offer.dart';
import 'package:alpaso/features/business/domain/photo.dart';

import 'fake_account.dart';

/// Servidor del modo negocio en memoria. Aplica las mismas reglas que la
/// base para lo que prueban las pantallas.
class FakeBusinessServer implements BusinessRepository {
  FakeBusinessServer(this.accounts);

  final FakeAccountServer accounts;
  final lodgings = <String, Lodging>{};
  final owners = <String, String>{};

  /// Hostales que tienen al menos un tipo de cuarto listo para publicar.
  final complete = <String>{};

  final roomTypesByLodging = <String, List<RoomType>>{};
  final productsByLodging = <String, List<Product>>{};
  final lodgingPhotosByLodging = <String, List<Photo>>{};
  PlatformRules rules = const PlatformRules(
    blockHours: [4, 6, 8, 12, 24],
    alcoholEnabled: false,
  );

  BusinessFailureReason? nextFailure;
  int _ids = 0;

  static const districtList = [
    District(id: 21, name: 'Miraflores', province: 'Lima'),
    District(id: 44, name: 'Callao', province: 'Callao'),
  ];

  void _maybeFail() {
    final reason = nextFailure;
    if (reason != null) {
      nextFailure = null;
      throw BusinessFailure(reason, 'falla de prueba');
    }
  }

  String get _me => accounts.currentUser!.id;

  Lodging _with(Lodging l, {LodgingDraft? draft, LodgingStatus? status}) =>
      Lodging(
        id: l.id,
        draft: draft ?? l.draft,
        districtName: districtList
            .firstWhere((d) => d.id == (draft ?? l.draft).districtId)
            .name,
        status: status ?? l.status,
        reviewNote: l.reviewNote,
      );

  /// Crea un hostal ya existente para la cuenta indicada.
  Lodging seed(
    String ownerId, {
    String name = 'Hostal Sol',
    LodgingStatus status = LodgingStatus.draft,
  }) {
    final id = 'l${_ids++}';
    final lodging = Lodging(
      id: id,
      districtName: 'Miraflores',
      status: status,
      draft: LodgingDraft(
        name: name,
        districtId: 21,
        address: 'Av. Larco 123',
        latitude: -12.12,
        longitude: -77.03,
      ),
    );
    lodgings[id] = lodging;
    owners[id] = ownerId;
    return lodging;
  }

  @override
  Future<List<District>> districts() async => districtList;

  @override
  Future<List<Lodging>> myLodgings() async {
    _maybeFail();
    return [
      for (final l in lodgings.values)
        if (owners[l.id] == _me) l,
    ];
  }

  @override
  Future<Lodging> lodging(String id) async {
    _maybeFail();
    return lodgings[id]!;
  }

  @override
  Future<String> createLodging(LodgingDraft draft) async {
    _maybeFail();
    final profile = accounts.profiles[_me]!;
    if (!profile.isAdultConfirmed) {
      throw const BusinessFailure(BusinessFailureReason.adultNotConfirmed);
    }
    final l = seed(_me, name: draft.name.trim());
    lodgings[l.id] = _with(l, draft: draft);
    return l.id;
  }

  @override
  Future<void> updateLodging(String id, LodgingDraft draft) async {
    _maybeFail();
    if (owners[id] != _me) {
      throw const BusinessFailure(BusinessFailureReason.notOwner);
    }
    lodgings[id] = _with(lodgings[id]!, draft: draft);
  }

  @override
  Future<void> submitLodging(String id) async {
    _maybeFail();
    final l = lodgings[id]!;
    if (!l.status.canSubmit) {
      throw const BusinessFailure(BusinessFailureReason.invalidStatus);
    }
    if (!complete.contains(id)) {
      final types = roomTypesByLodging[id] ?? const <RoomType>[];
      final missing = [
        if ((lodgingPhotosByLodging[id] ?? const []).isEmpty) 'lodging_photo',
        if (!types.any(
          (t) =>
              t.draft.isActive &&
              t.draft.rates.isNotEmpty &&
              t.draft.rooms.isNotEmpty,
        ))
          'room_type_ready',
        if (types.any(
          (t) =>
              t.draft.isActive &&
              t.draft.rates.isNotEmpty &&
              t.missingPhotos.isNotEmpty,
        ))
          'room_type_photos',
      ];
      if (missing.isNotEmpty) {
        throw BusinessFailure(
          BusinessFailureReason.lodgingIncomplete,
          'falta',
          missing,
        );
      }
    }
    lodgings[id] = _with(l, status: LodgingStatus.pendingReview);
  }

  @override
  Future<PlatformRules> platformRules() async => rules;

  @override
  Future<List<RoomType>> roomTypes(String lodgingId) async {
    _maybeFail();
    return List.of(roomTypesByLodging[lodgingId] ?? const []);
  }

  @override
  Future<String> saveRoomType(
    String lodgingId,
    RoomTypeDraft draft, {
    String? roomTypeId,
  }) async {
    _maybeFail();
    final list = roomTypesByLodging.putIfAbsent(lodgingId, () => []);
    final taken = list
        .where((t) => t.id != roomTypeId)
        .expand((t) => t.draft.rooms)
        .toSet();
    if (draft.rooms.any(taken.contains)) {
      throw const BusinessFailure(BusinessFailureReason.roomLabelTaken);
    }
    final id = roomTypeId ?? 't${_ids++}';
    final previous = list.where((t) => t.id == id).firstOrNull;
    final type = RoomType(
      id: id,
      draft: draft,
      photos: previous?.photos ?? const [],
    );
    final index = list.indexWhere((t) => t.id == id);
    if (index >= 0) {
      list[index] = type;
    } else {
      list.add(type);
    }
    return id;
  }

  @override
  Future<void> deleteRoomType(String roomTypeId) async {
    for (final list in roomTypesByLodging.values) {
      list.removeWhere((t) => t.id == roomTypeId);
    }
  }

  @override
  Future<List<Product>> products(String lodgingId) async {
    _maybeFail();
    return List.of(productsByLodging[lodgingId] ?? const []);
  }

  @override
  Future<void> saveProduct(
    String lodgingId,
    ProductDraft draft, {
    String? productId,
  }) async {
    _maybeFail();
    if (draft.category == ProductCategory.alcohol && !rules.alcoholEnabled) {
      throw const BusinessFailure(BusinessFailureReason.alcoholDisabled);
    }
    final list = productsByLodging.putIfAbsent(lodgingId, () => []);
    final id = productId ?? 'p${_ids++}';
    final product = Product(id: id, draft: draft);
    final index = list.indexWhere((p) => p.id == id);
    if (index >= 0) {
      list[index] = product;
    } else {
      list.add(product);
    }
  }

  @override
  Future<void> deleteProduct(String productId) async {
    for (final list in productsByLodging.values) {
      list.removeWhere((p) => p.id == productId);
    }
  }

  Photo _photo(String lodgingId, [PhotoKind? kind]) {
    final id = 'f${_ids++}';
    return Photo(
      id: id,
      storagePath: '$lodgingId/$id.jpg',
      url: 'http://fotos.invalid/$id.jpg',
      kind: kind,
    );
  }

  @override
  Future<List<Photo>> lodgingPhotos(String lodgingId) async =>
      List.of(lodgingPhotosByLodging[lodgingId] ?? const []);

  @override
  Future<void> addLodgingPhoto(String lodgingId, PickedPhoto photo) async {
    _maybeFail();
    lodgingPhotosByLodging
        .putIfAbsent(lodgingId, () => [])
        .add(_photo(lodgingId));
  }

  @override
  Future<void> addRoomTypePhoto(
    String lodgingId,
    String roomTypeId,
    PhotoKind kind,
    PickedPhoto photo,
  ) async {
    _maybeFail();
    final list = roomTypesByLodging[lodgingId]!;
    final index = list.indexWhere((t) => t.id == roomTypeId);
    final type = list[index];
    list[index] = RoomType(
      id: type.id,
      draft: type.draft,
      photos: [...type.photos, _photo(lodgingId, kind)],
    );
  }

  @override
  Future<void> deletePhoto(Photo photo, {required bool roomType}) async {
    _maybeFail();
    for (final list in lodgingPhotosByLodging.values) {
      list.removeWhere((p) => p.id == photo.id);
    }
    for (final list in roomTypesByLodging.values) {
      for (var i = 0; i < list.length; i++) {
        final t = list[i];
        list[i] = RoomType(
          id: t.id,
          draft: t.draft,
          photos: [
            for (final p in t.photos)
              if (p.id != photo.id) p,
          ],
        );
      }
    }
  }
}

/// Selector de fotos que siempre devuelve una imagen pequeña, o nada si
/// [cancel] es verdadero.
class FakePhotoPicker implements PhotoPicker {
  bool cancel = false;
  int picks = 0;

  @override
  Future<PickedPhoto?> pick({required bool camera}) async {
    picks++;
    return cancel
        ? null
        : const PickedPhoto(bytes: [1, 2, 3], mimeType: 'image/jpeg');
  }
}
