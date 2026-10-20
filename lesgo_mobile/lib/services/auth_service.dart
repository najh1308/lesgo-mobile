import '../core/api_client.dart';
import '../core/app_settings.dart';
import '../core/session.dart';
import '../models/models.dart';

class AuthService {
  static Future<void> register({
    required String nama,
    required String email,
    required String noHp,
    required String password,
  }) async {
    await ApiClient.post('/register', body: {
      'nama': nama,
      'email': email,
      'no_hp': noHp,
      'password': password,
    });
  }

  static Future<UserModel> login(String email, String password) async {
    final data = await ApiClient.post('/login', body: {'email': email, 'password': password});
    await Session.saveToken(data['token']);
    return _simpanUser(UserModel.fromJson(Map<String, dynamic>.from(data['user'])));
  }

  /// Ambil data profil dari server (juga memeriksa token masih berlaku).
  static Future<UserModel> me() async {
    final data = await ApiClient.get('/me');
    return _simpanUser(UserModel.fromJson(Map<String, dynamic>.from(data)));
  }

  static Future<void> logout() async {
    try {
      await ApiClient.post('/logout');
    } catch (_) {
      // Tetap keluar di sisi aplikasi walau server tidak terjangkau.
    }
    await Session.clear();
  }

  static Future<UserModel> updateProfil({
    String? nama,
    String? noHp,
    String? mataUang,
    String? zona,
  }) async {
    final data = await ApiClient.put('/me', body: {
      if (nama != null) 'nama': nama,
      if (noHp != null) 'no_hp': noHp,
      if (mataUang != null) 'mata_uang_pref': mataUang,
      if (zona != null) 'zona_waktu_pref': zona,
    });
    return _simpanUser(UserModel.fromJson(Map<String, dynamic>.from(data)));
  }

  static Future<UserModel> uploadFoto(String path) async {
    final data = await ApiClient.upload('/me/foto', 'foto', path);
    return _simpanUser(UserModel.fromJson(Map<String, dynamic>.from(data)));
  }

  static Future<void> ubahPassword(String lama, String baru) async {
    await ApiClient.put('/me/password', body: {'password_lama': lama, 'password_baru': baru});
  }

  static UserModel _simpanUser(UserModel u) {
    Session.user = u;
    AppSettings.i.applyUser(u);
    return u;
  }
}
