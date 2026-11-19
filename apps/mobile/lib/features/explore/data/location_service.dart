import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Dónde está el teléfono. Las pruebas usan una versión falsa.
abstract interface class LocationService {
  /// Nulo si no hay permiso o el GPS está apagado.
  Future<LatLng?> current();
}

class DeviceLocationService implements LocationService {
  @override
  Future<LatLng?> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return LatLng(position.latitude, position.longitude);
    } on Exception {
      return null;
    }
  }
}
