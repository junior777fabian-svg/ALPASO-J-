import 'package:alpaso/app/theme/app_spacing.dart';
import 'package:alpaso/core/format/money.dart';
import 'package:alpaso/features/auth/presentation/auth_form_widgets.dart';
import 'package:alpaso/features/business/data/business_providers.dart';
import 'package:alpaso/features/business/domain/offer.dart';
import 'package:alpaso/features/business/presentation/business_messages.dart';
import 'package:alpaso/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// N2. Crear o editar un tipo de cuarto: datos, precio por bloque y números
/// de cuarto.
class RoomTypeFormScreen extends ConsumerStatefulWidget {
  const RoomTypeFormScreen({
    required this.lodgingId,
    this.roomTypeId,
    super.key,
  });

  final String lodgingId;

  /// Nulo para crear uno nuevo.
  final String? roomTypeId;

  @override
  ConsumerState<RoomTypeFormScreen> createState() => _RoomTypeFormScreenState();
}

class _RoomTypeFormScreenState extends ConsumerState<RoomTypeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _rooms = TextEditingController();
  final _rates = <int, TextEditingController>{};
  int _maxGuests = 2;
  bool _hasJacuzzi = false;
  bool _hasTv = false;
  bool _hasAirConditioning = false;
  bool _isActive = true;
  bool _loaded = false;
  bool _busy = false;
  String? _error;

  bool get _isNew => widget.roomTypeId == null;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _rooms.dispose();
    for (final c in _rates.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _rate(int hours) =>
      _rates.putIfAbsent(hours, TextEditingController.new);

  void _fill(RoomType type) {
    if (_loaded) return;
    _loaded = true;
    final d = type.draft;
    _name.text = d.name;
    _description.text = d.description;
    _rooms.text = d.rooms.join(', ');
    _maxGuests = d.maxGuests;
    _hasJacuzzi = d.hasJacuzzi;
    _hasTv = d.hasTv;
    _hasAirConditioning = d.hasAirConditioning;
    _isActive = d.isActive;
    for (final e in d.rates.entries) {
      _rate(e.key).text = centsToInput(e.value);
    }
  }

  static List<String> parseRooms(String text) => text
      .split(RegExp(r'[,\s]+'))
      .map((s) => s.trim().toUpperCase())
      .where((s) => s.isNotEmpty)
      .toSet()
      .toList();

  Future<void> _save(List<int> blocks) async {
    if (_busy) return;
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);

    final rates = <int, int>{
      for (final h in blocks) h: ?parseSolesToCents(_rate(h).text),
    };
    if (rates.isEmpty) {
      setState(() => _error = l10n.roomTypeErrorNoRates);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(businessRepositoryProvider)!
          .saveRoomType(
            widget.lodgingId,
            RoomTypeDraft(
              name: _name.text,
              description: _description.text,
              maxGuests: _maxGuests,
              hasJacuzzi: _hasJacuzzi,
              hasTv: _hasTv,
              hasAirConditioning: _hasAirConditioning,
              isActive: _isActive,
              rates: rates,
              rooms: parseRooms(_rooms.text),
            ),
            roomTypeId: widget.roomTypeId,
          );
      ref.invalidate(roomTypesProvider(widget.lodgingId));
      if (mounted) context.pop();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = businessFailureMessage(l10n, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.roomTypeDeleteTitle),
        content: Text(l10n.roomTypeDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.profileCancelAction),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.deleteAction),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(businessRepositoryProvider)!
          .deleteRoomType(widget.roomTypeId!);
      ref.invalidate(roomTypesProvider(widget.lodgingId));
      if (mounted) context.pop();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = businessFailureMessage(l10n, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rules = ref.watch(platformRulesProvider);
    final title = _isNew ? l10n.roomTypeNewTitle : l10n.roomTypeEditTitle;

    if (!_isNew) {
      final types = ref.watch(roomTypesProvider(widget.lodgingId));
      final type = types.value
          ?.where((t) => t.id == widget.roomTypeId)
          .firstOrNull;
      if (type == null) {
        return Scaffold(
          appBar: AppBar(title: Text(title)),
          body: const Center(child: CircularProgressIndicator()),
        );
      }
      _fill(type);
    }

    final blocks = rules.value?.blockHours ?? const <int>[];
    if (rules.isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (!_isNew)
            IconButton(
              tooltip: l10n.deleteAction,
              icon: const Icon(Icons.delete_outline),
              onPressed: _busy ? null : _delete,
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          // Todos los campos construidos, para que se validen todos.
          child: SingleChildScrollView(
            key: const Key('room-type-form'),
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const Key('room-type-name'),
                  controller: _name,
                  textCapitalization: TextCapitalization.sentences,
                  maxLength: 60,
                  decoration: InputDecoration(
                    labelText: l10n.roomTypeNameLabel,
                    hintText: l10n.roomTypeNameHint,
                    counterText: '',
                  ),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    return t.length < 2 || t.length > 60
                        ? l10n.lodgingErrorLength(2, 60)
                        : null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _description,
                  maxLength: 500,
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: l10n.lodgingDescriptionLabel,
                  ),
                ),
                DropdownButtonFormField<int>(
                  initialValue: _maxGuests,
                  decoration: InputDecoration(
                    labelText: l10n.roomTypeGuestsLabel,
                  ),
                  items: [
                    for (var n = 1; n <= 6; n++)
                      DropdownMenuItem(value: n, child: Text('$n')),
                  ],
                  onChanged: (v) => setState(() => _maxGuests = v ?? 2),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.roomTypeJacuzzi),
                  value: _hasJacuzzi,
                  onChanged: (v) => setState(() => _hasJacuzzi = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.roomTypeTv),
                  value: _hasTv,
                  onChanged: (v) => setState(() => _hasTv = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.roomTypeAirConditioning),
                  value: _hasAirConditioning,
                  onChanged: (v) => setState(() => _hasAirConditioning = v),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  l10n.roomTypeRatesTitle,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  l10n.roomTypeRatesHelp,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                for (final h in blocks)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: TextFormField(
                      key: Key('rate-$h'),
                      controller: _rate(h),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: l10n.rateFieldLabel(h),
                        prefixText: 'S/ ',
                      ),
                      validator: (v) {
                        final text = (v ?? '').trim();
                        if (text.isEmpty) return null;
                        final cents = parseSolesToCents(text);
                        return cents == null || cents < 100 || cents > 500000
                            ? l10n.roomTypeErrorPrice
                            : null;
                      },
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  key: const Key('room-type-rooms'),
                  controller: _rooms,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: l10n.roomTypeRoomsLabel,
                    hintText: '201, 202, 203',
                    helperText: l10n.roomTypeRoomsHelp,
                    helperMaxLines: 3,
                  ),
                  validator: (v) =>
                      parseRooms(
                        v ?? '',
                      ).every((r) => RegExp(r'^[A-Z0-9-]{1,10}$').hasMatch(r))
                      ? null
                      : l10n.roomTypeErrorRooms,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.roomTypeActiveLabel),
                  subtitle: Text(l10n.roomTypeActiveHelp),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_error != null) ...[
                  FormErrorBox(message: _error!),
                  const SizedBox(height: AppSpacing.md),
                ],
                SubmitButton(
                  label: l10n.profileSaveAction,
                  busy: _busy,
                  onPressed: () => _save(blocks),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
