import '../core/api_client.dart';
import '../core/format.dart';
import '../core/local_db.dart';
import '../models/models.dart';
import 'notifikasi_service.dart';

class PendaftaranService {
  static const _kunciMulai = 'mulai_pendaftaran_';

  /// [tanggalMulai] = hari pertama kelas yang dipilih pengguna.
  ///
  /// Tanggal dikirim ke server sebagai `p_tanggal_mulai`. Jika fungsi di Supabase belum
  /// punya parameter itu, pendaftaran dikirim tanpa tanggal dan pilihan pengguna disimpan
  /// di HP (Hive), lalu dipakai lagi untuk tampilan dan pengingat jadwal.
  static Future<Pendaftaran> daftar({
    required int programId,
    required int jadwalId,
    required String metodeBayar,
    required DateTime tanggalMulai,
  }) async {
    final iso = Fmt.iso(tanggalMulai);
    final dasar = {
      'p_program_id': programId,
      'p_jadwal_id': jadwalId,
      'p_metode_bayar': metodeBayar,
    };
    dynamic data;
    try {
      data = await ApiClient.rpcAuth('api_pendaftaran_create', {
        ...dasar,
        'p_tanggal_mulai': iso,
      });
    } on ApiException catch (e) {
      // Fungsi server versi lama (tanpa p_tanggal_mulai) tidak ditemukan: coba tanpa parameter itu.
      if (e.status == 500 && e.message.contains('belum dibuat')) {
        data = await ApiClient.rpcAuth('api_pendaftaran_create', dasar);
      } else {
        rethrow;
      }
    }
    var p = Pendaftaran.fromJson(
      Map<String, dynamic>.from(data['pendaftaran']),
    );
    if (p.tanggalMulai != iso) p = p.denganTanggalMulai(iso);
    await LocalDb.setSetting('$_kunciMulai${p.id}', iso);
    await NotifikasiService.pendaftaranBerhasil(p);
    return p;
  }

  /// Memakai tanggal mulai pilihan pengguna (tersimpan di HP) jika ada.
  static Future<Pendaftaran> _terapkanPilihan(Pendaftaran p) async {
    final iso = await LocalDb.getSetting('$_kunciMulai${p.id}');
    if (iso == null || iso.isEmpty || iso == p.tanggalMulai) return p;
    return p.denganTanggalMulai(iso);
  }

  static Future<List<Pendaftaran>> list() async {
    final data = await ApiClient.rpcAuth('api_pendaftaran_list') as List;
    final hasil = <Pendaftaran>[];
    for (final e in data) {
      hasil.add(
        await _terapkanPilihan(
          Pendaftaran.fromJson(Map<String, dynamic>.from(e)),
        ),
      );
    }
    return hasil;
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
    await LocalDb.setSetting('$_kunciMulai$id', '');
  }

  static Future<List<BlockItem>> blocks() async {
    final data = await ApiClient.rpcAuth('api_blockchain_list') as List;
    return data
        .map((e) => BlockItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
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
