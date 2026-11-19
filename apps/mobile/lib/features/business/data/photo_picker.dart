import 'package:alpaso/features/business/domain/photo.dart';
import 'package:image_picker/image_picker.dart';

/// Elige una foto de la galería o la cámara. Las pruebas usan una versión
/// falsa.
abstract interface class PhotoPicker {
  /// Nulo si la persona canceló.
  Future<PickedPhoto?> pick({required bool camera});
}

class DevicePhotoPicker implements PhotoPicker {
  final _picker = ImagePicker();

  @override
  Future<PickedPhoto?> pick({required bool camera}) async {
    // Se reduce en el teléfono antes de subir: menos datos móviles y menos
    // espacio en el servidor.
    final file = await _picker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 80,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    final mime =
        file.mimeType ??
        (file.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg');
    return PickedPhoto(bytes: bytes, mimeType: mime);
  }
}
