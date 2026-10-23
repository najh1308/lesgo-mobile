import '../core/api_client.dart';
import '../models/models.dart';
import 'notifikasi_service.dart';

class PendaftaranService {
  static Future<Pendaftaran> daftar({
    required int programId,
    required int jadwalId,
    required String metodeBayar,
  }) async {
    final data = await ApiClient.rpcAuth('api_pendaftaran_create', {
      'p_program_id': programId,
      'p_jadwal_id': jadwalId,
      'p_metode_bayar': metodeBayar,
    });
    final p = Pendaftaran.fromJson(Map<String, dynamic>.from(data['pendaftaran']));
    await NotifikasiService.pendaftaranBerhasil(p);
    return p;
  }

  static Future<List<Pendaftaran>> list() async {
    final data = await ApiClient.rpcAuth('api_pendaftaran_list') as List;
    return data.map((e) => Pendaftaran.fromJson(Map<String, dynamic>.from(e))).toList();
  }

    /// Jadwalkan ulang semua pengingat dari data server (dipanggil saat aplikasi dibuka).
  static Future<void> sinkronkanPengingat() async {
    if (!NotifikasiService.didukung) return;
    try {
      await NotifikasiService.sinkronkan(await list());
    } catch (_) {
      // Offline: pengingat yang sudah terjadwal di HP tetap berjalan.
    }
  }

  static Future<void> batal(int id) async {
    await ApiClient.rpcAuth('api_pendaftaran_batal', {'p_id': id});
    await NotifikasiService.batalkanPengingat(id);
  }

  static Future<List<BlockItem>> blocks() async {
    final data = await ApiClient.rpcAuth('api_blockchain_list') as List;
    return data.map((e) => BlockItem.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  static Future<ValidasiHasil> validasi() async {
    final res = await ApiClient.rpcAuth('api_blockchain_validate');
    final m = Map<String, dynamic>.from(res);
    final valid = m['valid'] == true;
    return ValidasiHasil(
      valid: valid,
      totalBlock: (m['total_block'] as num?)?.toInt() ?? 0,
      pesan: valid
          ? 'Rantai valid. Data tidak pernah diubah.'
          : 'Rantai tidak valid. Ada block yang berubah.',
    );
  }
}
