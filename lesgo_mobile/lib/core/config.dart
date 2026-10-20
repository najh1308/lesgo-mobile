/// Pengaturan dasar aplikasi.
class Config {
  /// Alamat backend. Emulator Android: 10.0.2.2 = laptop kalian.
  /// HP asli: ganti dengan IP laptop, misalnya http://192.168.1.10:8000
  /// Bisa juga lewat: flutter run --dart-define=API_BASE=http://192.168.1.10:8000
  static const String baseUrl =
      String.fromEnvironment('API_BASE', defaultValue: 'http://10.0.2.2:8000');

  /// Lokasi cadangan jika izin lokasi ditolak (Jakarta Selatan, sesuai desain).
  static const double defaultLat = -6.2263;
  static const double defaultLng = 106.8546;
  static const String defaultLokasiLabel = 'Jakarta Selatan';

  /// Wajib diisi untuk tile OpenStreetMap.
  static const String mapUserAgent = 'com.example.lesgo';
}
