/// Pengaturan dasar aplikasi.
class Config {
  /// Project Supabase (database online bersama).
  /// Ambil dari Supabase: Project Settings > API Keys / Data API.
  /// Publishable key (atau anon key) AMAN ditaruh di aplikasi karena semua tabel
  /// dikunci; aplikasi hanya bisa memanggil fungsi api_* yang memeriksa token login.
  /// JANGAN pernah menaruh secret key / service_role key di sini.
  static const String supabaseUrl =
      String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://zxmdlqqcssfbtvcasdsd.supabase.co');
  static const String supabaseKey =
      String.fromEnvironment('SUPABASE_KEY', defaultValue: 'sb_publishable_KRi3z4SmYZku15Y0HVUF5g_tQqP1Xq5');

  static bool get sudahDiisi => !supabaseUrl.contains('ISI-PROJECT') && !supabaseKey.startsWith('ISI_');

  /// Lokasi cadangan jika izin lokasi ditolak (Tugu Yogyakarta).
  static const double defaultLat = -7.7829;
  static const double defaultLng = 110.3671;
  static const String defaultLokasiLabel = 'Yogyakarta';

  /// Wajib diisi untuk tile OpenStreetMap.
  static const String mapUserAgent = 'com.example.lesgo';
}
