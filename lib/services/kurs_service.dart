import 'dart:convert';

import '../core/api_client.dart';
import '../core/app_settings.dart';
import '../core/local_db.dart';

/// Memuat kurs dari server (yang mengambil dari Frankfurter). Jika offline,
/// memakai kurs terakhir di database lokal.
class KursService {
  static Future<void> muat() async {
    try {
      final data = Map<String, dynamic>.from(await ApiClient.get('/kurs'));
      await LocalDb.putCache('kurs', jsonEncode(data));
      _terapkan(data);
    } catch (_) {
      final cache = await LocalDb.getCache('kurs');
      if (cache != null) {
        final data = Map<String, dynamic>.from(jsonDecode(cache));
        data['sumber'] = 'cache';
        _terapkan(data);
      }
    }
  }

  static void _terapkan(Map<String, dynamic> data) {
    final rates = (data['rates'] as Map)
        .map((k, v) => MapEntry(k.toString(), (v as num).toDouble()));
    AppSettings.i.setRates(rates, data['tanggal']?.toString(), data['sumber']?.toString() ?? '');
  }
}
