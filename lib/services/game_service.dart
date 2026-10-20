import '../core/api_client.dart';
import '../core/local_db.dart';

class PeringkatItem {
  final int peringkat, skor;
  final String nama;
  PeringkatItem(this.peringkat, this.nama, this.skor);
}

/// Skor Hitung Cepat: disimpan di Hive dulu, lalu dikirim ke server.
/// Skor yang gagal terkirim (offline) akan dikirim ulang pada permainan berikutnya.
class GameService {
  static Future<bool> simpanSkor(
      {required int skor, required int level, required int benar, required int salah, required int durasi}) async {
    int idLokal = 0;
    try {
      idLokal = await LocalDb.tambahSkor(skor: skor, level: level, benar: benar, salah: salah);
    } catch (_) {}
    try {
      await ApiClient.rpcAuth('api_game_simpan_skor', {'p_skor': skor, 'p_level': level, 'p_durasi': durasi});
      if (idLokal > 0) await LocalDb.tandaiTerkirim(idLokal);
      await _kirimTertunda(kecuali: idLokal);
      return true;
    } on ApiException {
      return false;
    }
  }

  static Future<void> _kirimTertunda({required int kecuali}) async {
    try {
      for (final r in await LocalDb.skorBelumTerkirim()) {
        final id = r['id'] as int;
        if (id == kecuali) continue;
        await ApiClient.rpcAuth('api_game_simpan_skor', {'p_skor': r['skor'], 'p_level': r['level'], 'p_durasi': 60});
        await LocalDb.tandaiTerkirim(id);
      }
    } catch (_) {}
  }

  static Future<List<PeringkatItem>> leaderboard() async {
    final data = await ApiClient.rpcAuth('api_game_leaderboard') as List;
    return data.map((e) {
      final m = Map<String, dynamic>.from(e);
      return PeringkatItem((m['peringkat'] as num).toInt(), m['nama'].toString(), (m['skor'] as num).toInt());
    }).toList();
  }

  static Future<int> skorTerbaikLokal() async {
    try {
      return await LocalDb.skorTerbaik();
    } catch (_) {
      return 0;
    }
  }
}
