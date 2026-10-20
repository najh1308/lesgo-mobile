import 'package:flutter/foundation.dart';

import '../models/models.dart';

/// Preferensi tampilan: mata uang dan zona waktu. Widget yang memakainya
/// dibungkus ListenableBuilder agar otomatis berubah saat pengguna mengganti.
class AppSettings extends ChangeNotifier {
  static final AppSettings i = AppSettings._();
  AppSettings._();

  String mataUang = 'IDR';
  String zona = 'WIB'; // WIB, WITA, WIT, LONDON

  // Kurs: 1 IDR = ... mata uang lain. Diisi dari KursService.
  Map<String, double> rates = {'IDR': 1, 'USD': 0.00006, 'EUR': 0.000052, 'JPY': 0.009};
  String? kursTanggal;
  String kursSumber = 'cadangan';

  void applyUser(UserModel u) {
    mataUang = u.mataUang;
    zona = u.zonaWaktu;
    notifyListeners();
  }

  void setMataUang(String v) {
    mataUang = v;
    notifyListeners();
  }

  void setZona(String v) {
    zona = v;
    notifyListeners();
  }

  void setRates(Map<String, double> r, String? tanggal, String sumber) {
    rates = r;
    kursTanggal = tanggal;
    kursSumber = sumber;
    notifyListeners();
  }
}
