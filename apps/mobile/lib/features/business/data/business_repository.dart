import 'package:alpaso/features/business/domain/business_failure.dart';
import 'package:alpaso/features/business/domain/lodging.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// Lo que el modo negocio pide al servidor.
abstract interface class BusinessRepository {
  Future<List<District>> districts();

  /// Hostales donde la cuenta en sesión es dueña o recepcionista.
  Future<List<Lodging>> myLodgings();

  Future<Lodging> lodging(String id);

  /// Registra un hostal en borrador y devuelve su id.
  Future<String> createLodging(LodgingDraft draft);

  Future<void> updateLodging(String id, LodgingDraft draft);

  /// Envía el hostal a revisión.
  Future<void> submitLodging(String id);
}

class SupabaseBusinessRepository implements BusinessRepository {
  SupabaseBusinessRepository(this._client);

  final sb.SupabaseClient _client;

  static const _lodgingColumns =
      'id, name, description, district_id, address, address_reference, '
      'latitude, longitude, has_parking, has_wifi, cleaning_minutes, status, '
      'review_note, districts(name)';

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw const BusinessFailure(BusinessFailureReason.unknown, 'sin sesión');
    }
    return id;
  }

  @override
  Future<List<District>> districts() => guardBusiness(() async {
    final rows = await _client
        .from('districts')
        .select('id, name, province')
        .order('name', ascending: true);
    return rows.map(District.fromJson).toList();
  });

  @override
  Future<List<Lodging>> myLodgings() => guardBusiness(() async {
    final rows = await _client
        .from('lodgings')
        .select('$_lodgingColumns, lodging_members!inner(user_id)')
        .eq('lodging_members.user_id', _userId)
        .order('created_at', ascending: true);
    return rows.map(Lodging.fromJson).toList();
  });

  @override
  Future<Lodging> lodging(String id) => guardBusiness(() async {
    final row = await _client
        .from('lodgings')
        .select(_lodgingColumns)
        .eq('id', id)
        .single();
    return Lodging.fromJson(row);
  });

  @override
  Future<String> createLodging(LodgingDraft draft) => guardBusiness(() async {
    final id = await _client.rpc<String>(
      'create_lodging',
      params: {
        'p_name': draft.name.trim(),
        'p_district_id': draft.districtId,
        'p_address': draft.address.trim(),
        'p_address_reference': draft.addressReference.trim(),
        'p_latitude': draft.latitude,
        'p_longitude': draft.longitude,
      },
    );
    // Lo que create_lodging no recibe (descripción, servicios, limpieza).
    await _client.from('lodgings').update(draft.toUpdateJson()).eq('id', id);
    return id;
  });

  @override
  Future<void> updateLodging(String id, LodgingDraft draft) =>
      guardBusiness(() async {
        await _client
            .from('lodgings')
            .update(draft.toUpdateJson())
            .eq('id', id)
            .select('id')
            .single();
      });

  @override
  Future<void> submitLodging(String id) => guardBusiness(() async {
    await _client.rpc<String>('submit_lodging', params: {'p_lodging_id': id});
  });
}

/// Convierte los errores del cliente de Supabase en [BusinessFailure].
Future<T> guardBusiness<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on BusinessFailure {
    rethrow;
  } on sb.PostgrestException catch (error) {
    throw BusinessFailure(
      businessReasonFromServer(error.message, error.code),
      '${error.code}: ${error.message}',
    );
  } on Exception catch (error) {
    throw BusinessFailure(BusinessFailureReason.network, '$error');
  }
}
