import 'package:alpaso/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Fotos que se pasan con el dedo, con un indicador "2 de 5".
class PhotoGallery extends StatefulWidget {
  const PhotoGallery({
    required this.urls,
    this.labels = const [],
    this.height = 240,
    super.key,
  });

  final List<String> urls;

  /// Etiqueta de cada foto ("Baño"…), si la tiene.
  final List<String> labels;
  final double height;

  @override
  State<PhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends State<PhotoGallery> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    if (widget.urls.isEmpty) {
      return Container(
        height: widget.height,
        color: theme.colorScheme.surfaceContainerHighest,
        child: const Center(child: Icon(Icons.hotel_outlined, size: 56)),
      );
    }
    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: widget.urls.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) => Image.network(
              widget.urls[i],
              fit: BoxFit.cover,
              width: double.infinity,
              semanticLabel: i < widget.labels.length ? widget.labels[i] : null,
              errorBuilder: (context, error, stack) => ColoredBox(
                color: theme.colorScheme.surfaceContainerHighest,
                child: const Center(
                  child: Icon(Icons.image_not_supported_outlined),
                ),
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                [
                  if (_page < widget.labels.length) widget.labels[_page],
                  l10n.photoCounter(_page + 1, widget.urls.length),
                ].join(' · '),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
