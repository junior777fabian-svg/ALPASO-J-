import 'package:alpaso/app/router/app_router.dart';
import 'package:alpaso/app/theme/app_spacing.dart';
import 'package:alpaso/core/format/money.dart';
import 'package:alpaso/design/widgets/empty_state.dart';
import 'package:alpaso/features/business/data/business_providers.dart';
import 'package:alpaso/features/business/domain/lodging.dart';
import 'package:alpaso/features/explore/data/explore_providers.dart';
import 'package:alpaso/features/explore/domain/search.dart';
import 'package:alpaso/features/explore/presentation/explore_messages.dart';
import 'package:alpaso/l10n/app_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// C2. Hostales con cuarto libre para la duración y la llegada elegidas, en
/// lista o en mapa. Se puede usar sin cuenta.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  bool _showMap = false;
  bool _locating = false;

  SearchQueryNotifier get _query => ref.read(searchQueryProvider.notifier);

  Future<void> _useMyLocation() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _locating = true);
    final point = await ref.read(locationServiceProvider).current();
    if (!mounted) return;
    setState(() => _locating = false);
    if (point == null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.exploreNoLocation)));
      return;
    }
    _query.update(
      (q) => q.copyWith(center: point, nearMe: true, districtId: () => null),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasServer = ref.watch(exploreRepositoryProvider) != null;

    if (!hasServer) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.exploreTitle)),
        body: EmptyState(
          icon: Icons.map_outlined,
          title: l10n.exploreEmptyTitle,
          body: l10n.exploreNoServerBody,
        ),
      );
    }

    final query = ref.watch(searchQueryProvider);
    final results = ref.watch(searchResultsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.exploreTitle),
        actions: [
          IconButton(
            tooltip: l10n.exploreNearMe,
            icon: _locating
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    query.nearMe ? Icons.my_location : Icons.location_searching,
                  ),
            onPressed: _locating ? null : _useMyLocation,
          ),
          IconButton(
            tooltip: _showMap ? l10n.exploreShowList : l10n.exploreShowMap,
            icon: Icon(
              _showMap ? Icons.view_list_outlined : Icons.map_outlined,
            ),
            onPressed: () => setState(() => _showMap = !_showMap),
          ),
        ],
      ),
      body: Column(
        children: [
          const _SearchBar(),
          Expanded(
            child: switch (results) {
              AsyncData(value: final List<LodgingResult> list)
                  when list.isEmpty =>
                EmptyState(
                  icon: Icons.search_off,
                  title: l10n.exploreNoResultsTitle,
                  body: l10n.exploreNoResultsBody,
                ),
              AsyncData(value: final List<LodgingResult> list) =>
                _showMap
                    ? _ResultsMap(results: list)
                    : _ResultsList(results: list),
              AsyncError(:final error) => EmptyState(
                icon: Icons.error_outline,
                title: l10n.exploreErrorTitle,
                body: exploreFailureMessage(l10n, error),
                action: FilledButton(
                  onPressed: () => ref.invalidate(searchResultsProvider),
                  child: Text(l10n.profileRetryAction),
                ),
              ),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
        ],
      ),
    );
  }
}

/// Duración, llegada y filtros.
class _SearchBar extends ConsumerWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final query = ref.watch(searchQueryProvider);
    final notifier = ref.read(searchQueryProvider.notifier);
    final blocks =
        ref.watch(searchBlocksProvider).value ?? const [4, 6, 8, 12, 24];
    final now = ref.read(clockProvider)();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final h in blocks)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ChoiceChip(
                      label: Text(l10n.hoursShort(h)),
                      selected: query.blockHours == h,
                      onSelected: (_) =>
                          notifier.update((q) => q.copyWith(blockHours: h)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('explore-arrival'),
                  icon: const Icon(Icons.schedule),
                  label: Text(
                    l10n.arrivalLabel(formatArrival(l10n, query.arrival, now)),
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: () => _pickArrival(context, ref),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              OutlinedButton.icon(
                key: const Key('explore-filters'),
                // El tema pide botones de ancho completo; en una fila no se
                // puede.
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
                icon: const Icon(Icons.tune),
                label: Text(
                  query.activeFilters == 0
                      ? l10n.filtersAction
                      : l10n.filtersActive(query.activeFilters),
                ),
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const _FiltersSheet(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickArrival(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(searchQueryProvider.notifier);
    final now = ref.read(clockProvider)();
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.bolt),
              title: Text(l10n.arrivalNow),
              onTap: () => Navigator.of(context).pop('now'),
            ),
            ListTile(
              leading: const Icon(Icons.today),
              title: Text(l10n.arrivalLaterToday),
              onTap: () => Navigator.of(context).pop('today'),
            ),
            ListTile(
              leading: const Icon(Icons.event),
              title: Text(l10n.arrivalOtherDay),
              onTap: () => Navigator.of(context).pop('other'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    if (choice == 'now') {
      notifier.update((q) => q.copyWith(arrival: () => null));
      return;
    }
    var day = DateTime(now.year, now.month, now.day);
    if (choice == 'other') {
      final picked = await showDatePicker(
        context: context,
        initialDate: day.add(const Duration(days: 1)),
        firstDate: day,
        lastDate: day.add(const Duration(days: 7)),
      );
      if (picked == null || !context.mounted) return;
      day = picked;
    }
    final soon = now.add(const Duration(minutes: 30));
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: soon.hour,
        minute: soon.minute < 30 ? 30 : 0,
      ),
    );
    if (time == null || !context.mounted) return;
    var arrival = DateTime(
      day.year,
      day.month,
      day.day,
      time.hour,
      time.minute,
    );
    // Una hora que ya pasó hoy se toma como "ahora".
    if (arrival.isBefore(now)) arrival = now;
    final limit = now.add(const Duration(days: 7));
    if (arrival.isAfter(limit)) arrival = limit;
    notifier.update((q) => q.copyWith(arrival: () => arrival));
  }
}

class _FiltersSheet extends ConsumerStatefulWidget {
  const _FiltersSheet();

  @override
  ConsumerState<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends ConsumerState<_FiltersSheet> {
  late SearchQuery _draft = ref.read(searchQueryProvider);
  late final _maxPrice = TextEditingController(
    text: _draft.maxPriceCents == null
        ? ''
        : centsToInput(_draft.maxPriceCents!),
  );

  @override
  void dispose() {
    _maxPrice.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final districts = ref.watch(districtsProvider).value ?? const <District>[];

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.filtersTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<int?>(
              key: const Key('filter-district'),
              initialValue: _draft.districtId,
              isExpanded: true,
              decoration: InputDecoration(labelText: l10n.lodgingDistrictLabel),
              items: [
                DropdownMenuItem(value: null, child: Text(l10n.filterNearby)),
                for (final d in districts)
                  DropdownMenuItem(value: d.id, child: Text(d.name)),
              ],
              onChanged: (v) =>
                  setState(() => _draft = _draft.copyWith(districtId: () => v)),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('filter-max-price'),
              controller: _maxPrice,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: l10n.filterMaxPrice,
                prefixText: 'S/ ',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.roomTypeJacuzzi),
              value: _draft.needsJacuzzi,
              onChanged: (v) =>
                  setState(() => _draft = _draft.copyWith(needsJacuzzi: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.lodgingParkingLabel),
              value: _draft.needsParking,
              onChanged: (v) =>
                  setState(() => _draft = _draft.copyWith(needsParking: v)),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      ref
                          .read(searchQueryProvider.notifier)
                          .update(
                            (q) => q.copyWith(
                              districtId: () => null,
                              maxPriceCents: () => null,
                              needsJacuzzi: false,
                              needsParking: false,
                            ),
                          );
                      Navigator.of(context).pop();
                    },
                    child: Text(l10n.filtersClear),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    key: const Key('filters-apply'),
                    onPressed: () {
                      final price = parseSolesToCents(_maxPrice.text);
                      ref
                          .read(searchQueryProvider.notifier)
                          .update(
                            (_) => _draft.copyWith(maxPriceCents: () => price),
                          );
                      Navigator.of(context).pop();
                    },
                    child: Text(l10n.filtersApply),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultsList extends ConsumerWidget {
  const _ResultsList({required this.results});

  final List<LodgingResult> results;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () => ref.refresh(searchResultsProvider.future),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        itemCount: results.length,
        itemBuilder: (context, i) => LodgingResultCard(result: results[i]),
      ),
    );
  }
}

/// Tarjeta de un hostal en la lista de resultados.
class LodgingResultCard extends ConsumerWidget {
  const LodgingResultCard({required this.result, super.key});

  final LodgingResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final hours = ref.watch(searchQueryProvider).blockHours;
    final query = ref.watch(searchQueryProvider);

    return Card(
      key: Key('result-${result.lodgingId}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.publicLodging(result.lodgingId)),
        child: Row(
          children: [
            SizedBox(
              width: 110,
              height: 110,
              child: result.coverPhotoUrl == null
                  ? ColoredBox(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.hotel_outlined, size: 40),
                    )
                  : Image.network(
                      result.coverPhotoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => ColoredBox(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.hotel_outlined, size: 40),
                      ),
                    ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(result.name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      query.districtId == null
                          ? '${result.districtName} · ${formatDistance(result.distanceMeters)}'
                          : result.districtName,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.priceFrom(formatSoles(result.minPriceCents), hours),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    if (result.hasJacuzzi || result.hasParking)
                      Text(
                        [
                          if (result.hasJacuzzi) l10n.roomTypeJacuzzi,
                          if (result.hasParking) l10n.lodgingParkingLabel,
                        ].join(' · '),
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultsMap extends ConsumerStatefulWidget {
  const _ResultsMap({required this.results});

  final List<LodgingResult> results;

  @override
  ConsumerState<_ResultsMap> createState() => _ResultsMapState();
}

class _ResultsMapState extends ConsumerState<_ResultsMap> {
  LodgingResult? _selected;

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final tiles = ref.watch(mapTilesEnabledProvider);
    final theme = Theme.of(context);
    final center = query.nearMe || widget.results.isEmpty
        ? query.center
        : widget.results.first.location;

    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: query.nearMe ? 14 : 12,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onTap: (_, _) => setState(() => _selected = null),
          ),
          children: [
            if (tiles)
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'pe.alpaso.app',
              ),
            MarkerLayer(
              markers: [
                for (final r in widget.results)
                  Marker(
                    point: r.location,
                    width: 96,
                    height: 36,
                    child: GestureDetector(
                      key: Key('pin-${r.lodgingId}'),
                      onTap: () => setState(() => _selected = r),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _selected == r
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          formatSoles(r.minPriceCents),
                          style: TextStyle(
                            color: _selected == r
                                ? theme.colorScheme.surface
                                : theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (tiles)
              const SimpleAttributionWidget(source: Text('OpenStreetMap')),
          ],
        ),
        if (_selected != null)
          Positioned(
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: AppSpacing.md,
            child: LodgingResultCard(result: _selected!),
          ),
      ],
    );
  }
}
