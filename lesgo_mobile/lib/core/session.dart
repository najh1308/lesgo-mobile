import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/models.dart';

/// Session login. Token disimpan di secure storage (terenkripsi oleh Keystore/Keychain).
class Session {
  static const _storage = FlutterSecureStorage();
  static const _kToken = 'token';
  static const _kBiometrik = 'biometrik_aktif';

  static String? token;
  static UserModel? user;

  static Future<void> load() async {
    token = await _storage.read(key: _kToken);
  }

  static Future<void> saveToken(String t) async {
    token = t;
    await _storage.write(key: _kToken, value: t);
  }

  static Future<void> clear() async {
    token = null;
    user = null;
    await _storage.delete(key: _kToken);
  }

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
