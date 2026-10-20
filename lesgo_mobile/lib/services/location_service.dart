import 'package:geolocator/geolocator.dart';

import '../core/config.dart';

class UserLocation {
  final double lat, lng;
  final bool asli; // false = lokasi cadangan karena izin/GPS tidak tersedia
  const UserLocation(this.lat, this.lng, this.asli);
  String get label => asli ? 'Lokasi saya' : Config.defaultLokasiLabel;
}

/// LBS: mengambil posisi pengguna. Jika ditolak, memakai lokasi cadangan.
class LocationService {
  static const _cadangan = UserLocation(Config.defaultLat, Config.defaultLng, false);
  static UserLocation? terakhir;

  static Future<UserLocation> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return terakhir ?? _cadangan;
      var izin = await Geolocator.checkPermission();
      if (izin == LocationPermission.denied) {
        izin = await Geolocator.requestPermission();
      }
      if (izin == LocationPermission.denied || izin == LocationPermission.deniedForever) {
        return terakhir ?? _cadangan;
      }
      final pos = await Geolocator.getCurrentPosition().timeout(const Duration(seconds: 10));
      return terakhir = UserLocation(pos.latitude, pos.longitude, true);
    } catch (_) {
      return terakhir ?? _cadangan;
    }
  }
}
