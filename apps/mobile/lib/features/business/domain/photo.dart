/// Etiqueta de una foto de tipo de cuarto.
enum PhotoKind {
  room('room'),
  bathroom('bathroom'),
  jacuzzi('jacuzzi'),
  other('other');

  const PhotoKind(this.db);

  final String db;

  static PhotoKind fromDb(String value) =>
      values.firstWhere((k) => k.db == value, orElse: () => other);
}

class Photo {
  const Photo({
    required this.id,
    required this.storagePath,
    required this.url,
    this.kind,
  });

  final String id;

  /// `<lodging_id>/<archivo>` dentro del almacenamiento lodging-photos.
  final String storagePath;

  /// Dirección pública para mostrarla.
  final String url;

  /// Solo en fotos de tipo de cuarto.
  final PhotoKind? kind;
}

/// Una imagen elegida en el teléfono, ya reducida, lista para subir.
class PickedPhoto {
  const PickedPhoto({required this.bytes, required this.mimeType});

  final List<int> bytes;
  final String mimeType;

  String get extension => switch (mimeType) {
    'image/png' => 'png',
    'image/webp' => 'webp',
    _ => 'jpg',
  };
}
