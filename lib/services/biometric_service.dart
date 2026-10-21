import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// Login khusus sidik jari memakai sensor biometrik HP (paket local_auth).
/// PIN/pola/kata sandi HP tidak diterima (biometricOnly), dan fitur hanya bisa
/// diaktifkan jika sidik jari sudah terdaftar di HP.
/// Catatan Android: MainActivity harus turunan FlutterFragmentActivity.
class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Pesan error terakhir (untuk ditampilkan jika verifikasi gagal bukan karena dibatalkan).
  static String? errorTerakhir;

  static Future<bool> tersedia() async {
    try {
      final bisa = await _auth.canCheckBiometrics;
      final didukung = await _auth.isDeviceSupported();
      return bisa || didukung;
    } catch (e) {
      debugPrint('Biometrik tidak tersedia: $e');
      return false;
    }
  }

  /// Apakah sidik jari sudah didaftarkan di pengaturan HP.
  /// Android melaporkan kelas sensor: "strong" (sidik jari) atau "weak"
  /// (umumnya pengenalan wajah). Hanya fingerprint/strong yang diterima.
  static Future<bool> adaYangTerdaftar() async {
    try {
      final jenis = await _auth.getAvailableBiometrics();
      return jenis.contains(BiometricType.fingerprint) || jenis.contains(BiometricType.strong);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> verifikasi(String alasan) async {
    errorTerakhir = null;
    try {
      return await _auth.authenticate(
        localizedReason: alasan,
        biometricOnly: true, // tanpa PIN/pola/kata sandi
        persistAcrossBackgrounding: true,
      );
    } catch (e) {
      debugPrint('Verifikasi biometrik gagal: $e');
      final teks = e.toString();
      // Dibatalkan pengguna bukan error yang perlu ditampilkan.
      if (!RegExp('cancel', caseSensitive: false).hasMatch(teks)) {
        errorTerakhir = _terjemahkan(teks);
      }
      return false;
    }
  }

  static String _terjemahkan(String e) {
    final t = e.toLowerCase();
    if (t.contains('fragment')) {
      return 'Aplikasi belum dikonfigurasi untuk sidik jari (MainActivity harus FlutterFragmentActivity).';
    }
    if (t.contains('notenrolled') || t.contains('not_enrolled') || t.contains('no biometrics')) {
      return 'Belum ada sidik jari yang terdaftar. Tambahkan di Pengaturan HP > Keamanan > Sidik jari.';
    }
    if (t.contains('lockedout') || t.contains('locked')) {
      return 'Terlalu banyak percobaan. Coba lagi beberapa saat lagi.';
    }
    if (t.contains('notavailable') || t.contains('not_available') || t.contains('nohardware')) {
      return 'Sensor biometrik tidak tersedia di perangkat ini.';
    }
    return 'Verifikasi sidik jari gagal. Coba lagi.';
  }
}
