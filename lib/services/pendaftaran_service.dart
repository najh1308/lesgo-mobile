import '../core/api_client.dart';
import '../models/models.dart';

class PendaftaranService {
  static Future<Pendaftaran> daftar({
    required int programId,
    required int jadwalId,
    required String metodeBayar,
  }) async {
    final data = await ApiClient.post('/pendaftaran', body: {
      'program_id': programId,
      'jadwal_id': jadwalId,
      'metode_bayar': metodeBayar,
    });
    return Pendaftaran.fromJson(Map<String, dynamic>.from(data['pendaftaran']));
  }

  static Future<List<Pendaftaran>> list() async {
    final data = await ApiClient.get('/pendaftaran') as List;
    return data.map((e) => Pendaftaran.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  static Future<void> batal(int id) async {
    await ApiClient.put('/pendaftaran/$id/batal');
  }

  static Future<List<BlockItem>> blocks() async {
    final data = await ApiClient.get('/blockchain') as List;
    return data.map((e) => BlockItem.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  static Future<ValidasiHasil> validasi() async {
    final res = await ApiClient.get('/blockchain/validate');
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
