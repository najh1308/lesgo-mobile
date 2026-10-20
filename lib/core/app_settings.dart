import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'local_db.dart';

/// Preferensi tampilan: mata uang dan zona waktu. Widget yang memakainya
/// dibungkus ListenableBuilder agar otomatis berubah saat pengguna mengganti.
/// Pilihan juga disimpan di Hive (lokal), sehingga langsung berlaku saat aplikasi
/// dibuka walau server belum merespons.
class AppSettings extends ChangeNotifier {
  static final AppSettings i = AppSettings._();
  AppSettings._();

  String mataUang = 'IDR';
  String zona = 'WIB'; // WIB, WITA, WIT, LONDON

  // Kurs: 1 IDR = ... mata uang lain. Diisi dari KursService.
  Map<String, double> rates = {'IDR': 1, 'USD': 0.00006, 'EUR': 0.000052, 'JPY': 0.009};
  String? kursTanggal;
  String kursSumber = 'cadangan';

  /// Dipanggil sekali saat aplikasi dibuka.
  Future<void> muatLokal() async {
    try {
      mataUang = await LocalDb.getSetting('mata_uang') ?? mataUang;
      zona = await LocalDb.getSetting('zona_waktu') ?? zona;
      notifyListeners();
    } catch (_) {
      // Database lokal gagal dibuka: pakai nilai bawaan.
    }
  }

  Future<void> _simpan() async {
    try {
      await LocalDb.setSetting('mata_uang', mataUang);
      await LocalDb.setSetting('zona_waktu', zona);
    } catch (_) {}
  }

  void applyUser(UserModel u) {
    mataUang = u.mataUang;
    zona = u.zonaWaktu;
    notifyListeners();
    _simpan();
  }

  void setMataUang(String v) {
    mataUang = v;
    notifyListeners();
    _simpan();
  }

  void setZona(String v) {
    zona = v;
    notifyListeners();
    _simpan();
  }

  void setRates(Map<String, double> r, String? tanggal, String sumber) {
    rates = r;
    kursTanggal = tanggal;
    kursSumber = sumber;
    notifyListeners();
  }
}
