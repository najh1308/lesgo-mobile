import 'package:hive_ce_flutter/hive_ce_flutter.dart';

/// Database lokal dengan Hive (NoSQL key-value, tersimpan di HP; di Chrome memakai IndexedDB).
/// Data di sini tetap ada walau tidak ada internet:
/// - box "cache"        : salinan data dari server (daftar bimbel, kurs)
/// - box "pengaturan"   : pilihan mata uang dan zona waktu
/// - box "chat_ai"      : riwayat percakapan Tutor AI
/// - box "riwayat_game" : skor permainan Hitung Cepat (termasuk yang belum terkirim)
class LocalDb {
  static late Box _cache, _pengaturan, _chat, _game;
  static bool _siap = false;

  static bool get tersedia => _siap;

  /// Dipanggil sekali di main() sebelum runApp.
  static Future<void> init() async {
    if (_siap) return;
    try {
      await Hive.initFlutter();
      _cache = await Hive.openBox('cache');
      _pengaturan = await Hive.openBox('pengaturan');
      _chat = await Hive.openBox('chat_ai');
      _game = await Hive.openBox('riwayat_game');
      _siap = true;
    } catch (_) {
      // Penyimpanan lokal gagal dibuka: aplikasi tetap jalan tanpa data offline.
    }
  }

  static int get _now => DateTime.now().millisecondsSinceEpoch;

  static Map<String, Object?> _peta(dynamic v) => Map<String, Object?>.from(v as Map);

  // ---------- Cache data server ----------

  static Future<void> putCache(String key, String json) async {
    if (!_siap) return;
    await _cache.put(key, {'json': json, 'updated_at': _now});
  }

  static Future<String?> getCache(String key) async {
    if (!_siap) return null;
    final v = _cache.get(key);
    return v == null ? null : _peta(v)['json'] as String?;
  }

  static Future<void> clearCache() async {
    if (!_siap) return;
    await _cache.clear();
  }

  // ---------- Pengaturan ----------

  static Future<void> setSetting(String key, String value) async {
    if (!_siap) return;
    await _pengaturan.put(key, value);
  }

  static Future<String?> getSetting(String key) async {
    if (!_siap) return null;
    return _pengaturan.get(key) as String?;
  }

  // ---------- Riwayat Tutor AI ----------

  static Future<void> tambahChat(String role, String teks) async {
    if (!_siap) return;
    await _chat.add({'role': role, 'teks': teks, 'created_at': _now});
  }

  /// Pesan terakhir, urut dari yang paling lama.
  static Future<List<Map<String, Object?>>> ambilChat({int limit = 50}) async {
    if (!_siap) return [];
    final semua = _chat.values.map(_peta).toList();
    return semua.length > limit ? semua.sublist(semua.length - limit) : semua;
  }

  static Future<void> hapusChat() async {
    if (!_siap) return;
    await _chat.clear();
  }

  // ---------- Riwayat game ----------

  /// Mengembalikan id (key Hive) skor yang baru disimpan.
  static Future<int> tambahSkor(
      {required int skor, required int level, required int benar, required int salah, bool terkirim = false}) async {
    if (!_siap) return 0;
    return _game.add({
      'skor': skor,
      'level': level,
      'benar': benar,
      'salah': salah,
      'terkirim': terkirim ? 1 : 0,
      'created_at': _now,
    });
  }

  static Future<void> tandaiTerkirim(int id) async {
    if (!_siap) return;
    final v = _game.get(id);
    if (v == null) return;
    await _game.put(id, {..._peta(v), 'terkirim': 1});
  }

  static List<Map<String, Object?>> _skorDenganId() =>
      _game.keys.map((k) => {..._peta(_game.get(k)), 'id': k as int}).toList();

  /// Skor yang belum sempat dikirim ke server (misalnya saat offline).
  static Future<List<Map<String, Object?>>> skorBelumTerkirim() async {
    if (!_siap) return [];
    return _skorDenganId().where((r) => r['terkirim'] == 0).toList();
  }

  static Future<List<Map<String, Object?>>> riwayatSkor({int limit = 5}) async {
    if (!_siap) return [];
    return _skorDenganId().reversed.take(limit).toList();
  }

  static Future<int> skorTerbaik() async {
    if (!_siap) return 0;
    var terbaik = 0;
    for (final v in _game.values) {
      final s = _peta(v)['skor'] as int? ?? 0;
      if (s > terbaik) terbaik = s;
    }
    return terbaik;
  }
}
