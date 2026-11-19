import 'package:alpaso/app/theme/app_spacing.dart';
import 'package:alpaso/features/business/data/business_providers.dart';
import 'package:alpaso/features/business/domain/photo.dart';
import 'package:alpaso/features/business/presentation/business_messages.dart';
import 'package:alpaso/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Miniaturas con botón para borrar cada una y otro para agregar.
class PhotoStrip extends ConsumerStatefulWidget {
  const PhotoStrip({
    required this.photos,
    required this.addLabel,
    required this.onAdd,
    required this.onDelete,
    super.key,
  });

  final List<Photo> photos;
  final String addLabel;

  /// Sube la foto elegida.
  final Future<void> Function(PickedPhoto photo) onAdd;
  final Future<void> Function(Photo photo) onDelete;

  @override
  ConsumerState<PhotoStrip> createState() => _PhotoStripState();
}

class _PhotoStripState extends ConsumerState<PhotoStrip> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action();
    } on Object catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(businessFailureMessage(l10n, error))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    final l10n = AppLocalizations.of(context);
    final camera = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.photoFromGallery),
              onTap: () => Navigator.of(context).pop(false),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.photoFromCamera),
              onTap: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    );
    if (camera == null || !mounted) return;
    final picked = await ref.read(photoPickerProvider).pick(camera: camera);
    if (picked == null || !mounted) return;
    await _run(() => widget.onAdd(picked));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final photo in widget.photos)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  photo.url,
                  width: 96,
                  height: 96,
                  fit: BoxFit.cover,
                  semanticLabel: photo.kind == null
                      ? l10n.photoSemantics
                      : photoKindLabel(l10n, photo.kind!),
                  errorBuilder: (context, error, stack) => Container(
                    width: 96,
                    height: 96,
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    child: const Icon(Icons.image_not_supported_outlined),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                child: IconButton.filledTonal(
                  visualDensity: VisualDensity.compact,
                  tooltip: l10n.photoDeleteAction,
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: _busy
                      ? null
                      : () => _run(() => widget.onDelete(photo)),
                ),
              ),
            ],
          ),
        if (_busy)
          const SizedBox.square(
            dimension: 32,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          OutlinedButton.icon(
            onPressed: _add,
            icon: const Icon(Icons.add_a_photo_outlined),
            label: Text(widget.addLabel),
          ),
      ],
    );
  }
}

/// Fotos del hostal, en su ficha.
class LodgingPhotosSection extends ConsumerWidget {
  const LodgingPhotosSection({required this.lodgingId, super.key});

  final String lodgingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final photos = ref.watch(lodgingPhotosProvider(lodgingId));
    final repository = ref.watch(businessRepositoryProvider)!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.lodgingPhotosTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.lodgingPhotosHelp,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            switch (photos) {
              AsyncData(:final value) => PhotoStrip(
                key: const Key('lodging-photos'),
                photos: value,
                addLabel: l10n.photoAddAction,
                onAdd: (picked) async {
                  await repository.addLodgingPhoto(lodgingId, picked);
                  ref.invalidate(lodgingPhotosProvider(lodgingId));
                },
                onDelete: (photo) async {
                  await repository.deletePhoto(photo, roomType: false);
                  ref.invalidate(lodgingPhotosProvider(lodgingId));
                },
              ),
              AsyncError(:final error) => Text(
                businessFailureMessage(l10n, error),
              ),
              _ => const LinearProgressIndicator(),
            },
          ],
        ),
      ),
    );
  }
}
