import 'package:alpaso/features/business/data/business_providers.dart';
import 'package:alpaso/l10n/app_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

/// Centro de Lima, para el primer encuadre.
const limaCenter = LatLng(-12.0464, -77.0428);

/// Mapa con un pin fijo al centro: el dueño mueve el mapa hasta que el pin
/// quede sobre la puerta de su hostal.
class LocationPicker extends ConsumerWidget {
  const LocationPicker({
    required this.initial,
    required this.onChanged,
    super.key,
  });

  final LatLng initial;
  final ValueChanged<LatLng> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tiles = ref.watch(mapTilesEnabledProvider);
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      label: l10n.lodgingMapSemantics,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 240,
          child: Stack(
            children: [
              FlutterMap(
                options: MapOptions(
                  initialCenter: initial,
                  initialZoom: 16,
                  minZoom: 10,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                  onPositionChanged: (camera, hasGesture) {
                    if (hasGesture) onChanged(camera.center);
                  },
                ),
                children: [
                  if (tiles)
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'pe.alpaso.app',
                    ),
                  if (tiles)
                    const SimpleAttributionWidget(
                      source: Text('OpenStreetMap'),
                    ),
                ],
              ),
              IgnorePointer(
                child: Center(
                  child: Padding(
                    // La punta del pin queda en el centro exacto.
                    padding: const EdgeInsets.only(bottom: 40),
                    child: Icon(
                      Icons.location_on,
                      size: 40,
                      color: scheme.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
