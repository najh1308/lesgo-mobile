import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<bool> tersedia() async {
    try {
      return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  static Future<bool> verifikasi(String alasan) async {
    try {
      return await _auth.authenticate(localizedReason: alasan);
    } catch (_) {
      return false;
    }
  }
}
