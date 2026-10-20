import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/app_settings.dart';
import '../core/local_db.dart';

/// Kurs IDR -> USD/EUR/JPY langsung dari web service Frankfurter (data Bank Sentral Eropa).
/// Hasil disimpan di Hive; jika offline, aplikasi memakai kurs terakhir.
class KursService {
  static final _url = Uri.parse('https://api.frankfurter.dev/v1/latest?base=IDR&symbols=USD,EUR,JPY');

  static Future<void> muat() async {
    try {
      final res = await http.get(_url).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) throw Exception('kode ${res.statusCode}');
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final r = Map<String, dynamic>.from(j['rates']);
      final data = {
        'tanggal': j['date'],
        'sumber': 'frankfurter',
        'rates': {'IDR': 1.0, 'USD': r['USD'], 'EUR': r['EUR'], 'JPY': r['JPY']},
      };
      await LocalDb.putCache('kurs', jsonEncode(data));
      _terapkan(data);
    } catch (_) {
      final cache = await LocalDb.getCache('kurs');
      if (cache != null) {
        final data = Map<String, dynamic>.from(jsonDecode(cache));
        data['sumber'] = 'cache';
        _terapkan(data);
      }
      // Tanpa cache: tetap memakai kurs cadangan bawaan di AppSettings.
    }
  }

  static void _terapkan(Map<String, dynamic> data) {
    final rates = (data['rates'] as Map)
        .map((k, v) => MapEntry(k.toString(), (v as num).toDouble()));
    AppSettings.i.setRates(rates, data['tanggal']?.toString(), data['sumber']?.toString() ?? '');
  }
}
