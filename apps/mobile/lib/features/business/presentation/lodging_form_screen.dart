import 'package:alpaso/app/router/app_router.dart';
import 'package:alpaso/app/theme/app_spacing.dart';
import 'package:alpaso/features/auth/presentation/auth_form_widgets.dart';
import 'package:alpaso/features/business/data/business_providers.dart';
import 'package:alpaso/features/business/domain/lodging.dart';
import 'package:alpaso/features/business/presentation/business_messages.dart';
import 'package:alpaso/features/business/presentation/location_picker.dart';
import 'package:alpaso/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

/// N1. Registrar un hostal nuevo o editar sus datos.
class LodgingFormScreen extends ConsumerStatefulWidget {
  const LodgingFormScreen({this.lodgingId, super.key});

  /// Nulo para registrar uno nuevo.
  final String? lodgingId;

  @override
  ConsumerState<LodgingFormScreen> createState() => _LodgingFormScreenState();
}

class _LodgingFormScreenState extends ConsumerState<LodgingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _reference = TextEditingController();
  final _description = TextEditingController();
  int? _districtId;
  LatLng _location = limaCenter;
  bool _hasParking = false;
  bool _hasWifi = false;
  int _cleaningMinutes = 30;
  bool _loaded = false;
  bool _busy = false;
  String? _error;

  bool get _isNew => widget.lodgingId == null;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _reference.dispose();
    _description.dispose();
    super.dispose();
  }

  void _fill(Lodging lodging) {
    if (_loaded) return;
    _loaded = true;
    final d = lodging.draft;
    _name.text = d.name;
    _address.text = d.address;
    _reference.text = d.addressReference;
    _description.text = d.description;
    _districtId = d.districtId;
    _location = LatLng(d.latitude, d.longitude);
    _hasParking = d.hasParking;
    _hasWifi = d.hasWifi;
    _cleaningMinutes = d.cleaningMinutes;
  }

  Future<void> _save() async {
    final repository = ref.read(businessRepositoryProvider);
    if (_busy || repository == null) return;
    if (!_formKey.currentState!.validate()) return;

    final draft = LodgingDraft(
      name: _name.text,
      districtId: _districtId!,
      address: _address.text,
      addressReference: _reference.text,
      latitude: _location.latitude,
      longitude: _location.longitude,
      description: _description.text,
      hasParking: _hasParking,
      hasWifi: _hasWifi,
      cleaningMinutes: _cleaningMinutes,
    );

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_isNew) {
        final id = await repository.createLodging(draft);
        ref.invalidate(myLodgingsProvider);
        if (mounted) context.pushReplacement(AppRoutes.lodging(id));
      } else {
        await repository.updateLodging(widget.lodgingId!, draft);
        ref
          ..invalidate(myLodgingsProvider)
          ..invalidate(lodgingProvider(widget.lodgingId!));
        if (mounted) context.pop();
      }
    } on Object catch (error) {
      if (!mounted) return;
      setState(
        () => _error = businessFailureMessage(
          AppLocalizations.of(context),
          error,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final districts = ref.watch(districtsProvider).value ?? const <District>[];

    if (!_isNew) {
      final lodging = ref.watch(lodgingProvider(widget.lodgingId!));
      if (lodging case AsyncData(:final value)) {
        _fill(value);
      } else {
        return Scaffold(
          appBar: AppBar(title: Text(l10n.lodgingEditTitle)),
          body: const Center(child: CircularProgressIndicator()),
        );
      }
    }

    String? required(String? value, int min, int max) {
      final text = (value ?? '').trim();
      return text.length < min || text.length > max
          ? l10n.lodgingErrorLength(min, max)
          : null;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? l10n.lodgingNewTitle : l10n.lodgingEditTitle),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          // No es un ListView: un ListView construye solo lo visible, y el
          // formulario validaría solo esos campos.
          child: SingleChildScrollView(
            key: const Key('lodging-form'),
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const Key('lodging-name'),
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  maxLength: 80,
                  decoration: InputDecoration(
                    labelText: l10n.lodgingNameLabel,
                    counterText: '',
                  ),
                  validator: (v) => required(v, 3, 80),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<int>(
                  key: const Key('lodging-district'),
                  initialValue: _districtId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l10n.lodgingDistrictLabel,
                  ),
                  items: [
                    for (final d in districts)
                      DropdownMenuItem(value: d.id, child: Text(d.name)),
                  ],
                  onChanged: (value) => setState(() => _districtId = value),
                  validator: (v) =>
                      v == null ? l10n.lodgingErrorDistrict : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  key: const Key('lodging-address'),
                  controller: _address,
                  maxLength: 200,
                  decoration: InputDecoration(
                    labelText: l10n.lodgingAddressLabel,
                    hintText: l10n.lodgingAddressHint,
                    counterText: '',
                  ),
                  validator: (v) => required(v, 5, 200),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  key: const Key('lodging-reference'),
                  controller: _reference,
                  maxLength: 200,
                  decoration: InputDecoration(
                    labelText: l10n.lodgingReferenceLabel,
                    hintText: l10n.lodgingReferenceHint,
                    counterText: '',
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  l10n.lodgingMapTitle,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.lodgingMapHelp,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                LocationPicker(
                  initial: _location,
                  onChanged: (point) => _location = point,
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  key: const Key('lodging-description'),
                  controller: _description,
                  maxLength: 1000,
                  minLines: 2,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: l10n.lodgingDescriptionLabel,
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.lodgingParkingLabel),
                  value: _hasParking,
                  onChanged: (v) => setState(() => _hasParking = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.lodgingWifiLabel),
                  value: _hasWifi,
                  onChanged: (v) => setState(() => _hasWifi = v),
                ),
                DropdownButtonFormField<int>(
                  initialValue: _cleaningMinutes,
                  decoration: InputDecoration(
                    labelText: l10n.lodgingCleaningLabel,
                  ),
                  items: [
                    for (final m in const [0, 15, 20, 30, 45, 60, 90])
                      DropdownMenuItem(
                        value: m,
                        child: Text(l10n.lodgingMinutes(m)),
                      ),
                  ],
                  onChanged: (v) => setState(() => _cleaningMinutes = v ?? 30),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_error != null) ...[
                  FormErrorBox(message: _error!),
                  const SizedBox(height: AppSpacing.md),
                ],
                SubmitButton(
                  label: _isNew
                      ? l10n.lodgingCreateAction
                      : l10n.profileSaveAction,
                  busy: _busy,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
