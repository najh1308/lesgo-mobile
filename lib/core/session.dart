import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/models.dart';

/// Session login. Token disimpan di secure storage (terenkripsi oleh Keystore/Keychain).
class Session {
  static const _storage = FlutterSecureStorage();
  static const _kToken = 'token';
  static const _kBiometrik = 'biometrik_aktif';
  static const _kTerkunci = 'terkunci';

  static String? token;
  static UserModel? user;

  static Future<void> load() async {
    token = await _storage.read(key: _kToken);
  }

  static Future<void> saveToken(String t) async {
    token = t;
    await _storage.write(key: _kToken, value: t);
    await bukaKunci();
  }

  static Future<void> clear() async {
    token = null;
    user = null;
    await _storage.delete(key: _kToken);
    await _storage.delete(key: _kTerkunci);
  }

  /// Keluar tapi token tetap disimpan terenkripsi, supaya bisa masuk lagi
  /// dengan sidik jari (dipakai jika login sidik jari aktif).
  static Future<void> kunci() async {
    user = null;
    await _storage.write(key: _kTerkunci, value: '1');
  }

  static Future<void> bukaKunci() => _storage.delete(key: _kTerkunci);

  static Future<bool> terkunci() async => (await _storage.read(key: _kTerkunci)) == '1';

  static Future<bool> biometrikAktif() async =>
      (await _storage.read(key: _kBiometrik)) == '1';

  static Future<void> setBiometrik(bool aktif) async {
    if (aktif) {
      await _storage.write(key: _kBiometrik, value: '1');
    } else {
      await _storage.delete(key: _kBiometrik);
    }
  }
}
