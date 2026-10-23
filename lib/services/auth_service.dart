import 'dart:convert';
import 'dart:typed_data';

import '../core/api_client.dart';
import '../core/app_settings.dart';
import '../core/session.dart';
import '../models/models.dart';
import 'notifikasi_service.dart';

/// Login buatan sendiri: password diperiksa (bcrypt) oleh fungsi api_login di Supabase,
/// lalu token session disimpan terenkripsi di HP (flutter_secure_storage).
class AuthService {
  static Future<void> register({
    required String nama,
    required String email,
    required String noHp,
    required String password,
  }) async {
    await ApiClient.rpc('api_register', {
      'p_nama': nama,
      'p_email': email,
      'p_no_hp': noHp,
      'p_password': password,
    });
  }

  static Future<UserModel> login(String email, String password) async {
    final data = await ApiClient.rpc('api_login', {'p_email': email, 'p_password': password});
    await Session.saveToken(data['token']);
    return _simpanUser(UserModel.fromJson(Map<String, dynamic>.from(data['user'])));
  }

  /// Ambil data profil dari server (juga memeriksa token masih berlaku).
  static Future<UserModel> me() async {
    final data = await ApiClient.rpcAuth('api_me');
    return _simpanUser(UserModel.fromJson(Map<String, dynamic>.from(data)));
  }

  /// Jika login sidik jari aktif, aplikasi hanya dikunci: token tetap tersimpan
  /// terenkripsi sehingga pengguna bisa masuk lagi cukup dengan sidik jari.
  /// Jika tidak aktif, token dihapus dari server dan HP.
  static Future<void> logout() async {
    if (Session.token != null && await Session.biometrikAktif()) {
      await Session.kunci();
      return;
    }
    try {
      await ApiClient.rpcAuth('api_logout');
    } catch (_) {
      // Tetap keluar di sisi aplikasi walau server tidak terjangkau.
    }
    await NotifikasiService.batalkanSemua(); // pengingat milik akun ini jangan terbawa
    await Session.clear();
  }

  static Future<UserModel> updateProfil({
    String? nama,
    String? noHp,
    String? mataUang,
    String? zona,
  }) async {
    final data = await ApiClient.rpcAuth('api_update_me', {
      'p_nama': ?nama,
      'p_no_hp': ?noHp,
      'p_mata_uang': ?mataUang,
      'p_zona': ?zona,
    });
    return _simpanUser(UserModel.fromJson(Map<String, dynamic>.from(data)));
  }

  /// Foto dikirim sebagai base64 (sudah diperkecil saat dipilih).
  static Future<UserModel> uploadFoto(Uint8List bytes) async {
    final data = await ApiClient.rpcAuth('api_set_foto', {'p_foto_base64': base64Encode(bytes)});
    return _simpanUser(UserModel.fromJson(Map<String, dynamic>.from(data)));
  }

  static Future<void> ubahPassword(String lama, String baru) async {
    await ApiClient.rpcAuth('api_ubah_password', {'p_lama': lama, 'p_baru': baru});
  }

  static UserModel _simpanUser(UserModel u) {
    Session.user = u;
    AppSettings.i.applyUser(u);
    return u;
  }
}
