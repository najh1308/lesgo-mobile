double _d(dynamic v) => v == null ? 0 : (v as num).toDouble();
int _i(dynamic v) => v == null ? 0 : (v as num).toInt();
List<String> _list(dynamic v) =>
    v == null ? <String>[] : (v as List).map((e) => e.toString()).toList();

class UserModel {
  final int id;
  final String nama, email, noHp, mataUang, zonaWaktu;
  final String? fotoUrl;
  UserModel({
    required this.id,
    required this.nama,
    required this.email,
    required this.noHp,
    required this.mataUang,
    required this.zonaWaktu,
    this.fotoUrl,
  });

  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
        id: _i(j['id']),
        nama: j['nama'] ?? '',
        email: j['email'] ?? '',
        noHp: j['no_hp'] ?? '',
        mataUang: j['mata_uang_pref'] ?? 'IDR',
        zonaWaktu: j['zona_waktu_pref'] ?? 'WIB',
        fotoUrl: j['foto_url'],
      );
}

class Jadwal {
  final int id, kuota, terisi, sisa;
  final String hari, jamMulai, jamSelesai, tanggalMulai; // jam dalam WIB
  Jadwal({
    required this.id,
    required this.hari,
    required this.jamMulai,
    required this.jamSelesai,
    required this.tanggalMulai,
    required this.kuota,
    required this.terisi,
    required this.sisa,
  });
  factory Jadwal.fromJson(Map<String, dynamic> j) => Jadwal(
        id: _i(j['id']),
        hari: j['hari'] ?? '',
        jamMulai: j['jam_mulai'] ?? '',
        jamSelesai: j['jam_selesai'] ?? '',
        tanggalMulai: j['tanggal_mulai'] ?? '',
        kuota: _i(j['kuota']),
        terisi: _i(j['terisi']),
        sisa: _i(j['sisa']),
      );
}

class Program {
  final int id, hargaIdr, durasiMinggu;
  final String nama, jenjang, mapel, mode, deskripsi;
  final List<Jadwal> jadwal;
  Program({
    required this.id,
    required this.nama,
    required this.jenjang,
    required this.mapel,
    required this.mode,
    required this.hargaIdr,
    required this.durasiMinggu,
    required this.deskripsi,
    required this.jadwal,
  });
  factory Program.fromJson(Map<String, dynamic> j) => Program(
        id: _i(j['id']),
        nama: j['nama_program'] ?? '',
        jenjang: j['jenjang'] ?? '',
        mapel: j['mapel'] ?? '',
        mode: j['mode'] ?? 'offline',
        hargaIdr: _i(j['harga_idr']),
        durasiMinggu: _i(j['durasi_minggu']),
        deskripsi: j['deskripsi'] ?? '',
        jadwal: ((j['jadwal'] ?? []) as List)
            .map((e) => Jadwal.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

/// Ringkasan bimbel untuk daftar (beranda, pencarian, favorit).
class Bimbel {
  final int id, hargaMulai;
  final String nama, alamat, kota, mapel;
  final double lat, lng, rating;
  final double? jarakKm;
  final List<String> jenjang, mode;
  bool isFavorit;
  Bimbel({
    required this.id,
    required this.nama,
    required this.alamat,
    required this.kota,
    required this.lat,
    required this.lng,
    required this.rating,
    required this.hargaMulai,
    required this.jenjang,
    required this.mode,
    required this.mapel,
    this.jarakKm,
    this.isFavorit = false,
  });
  factory Bimbel.fromJson(Map<String, dynamic> j) => Bimbel(
        id: _i(j['id']),
        nama: j['nama'] ?? '',
        alamat: j['alamat'] ?? '',
        kota: j['kota'] ?? '',
        lat: _d(j['latitude']),
        lng: _d(j['longitude']),
        rating: _d(j['rating_avg']),
        hargaMulai: _i(j['harga_mulai']),
        jenjang: _list(j['jenjang']),
        mode: _list(j['mode']),
        mapel: j['mapel'] ?? '',
        jarakKm: j['jarak_km'] == null ? null : _d(j['jarak_km']),
        isFavorit: j['is_favorit'] == true,
      );
}

class BimbelDetail {
  final int id, jumlahReview;
  final String nama, alamat, kota, deskripsi, kontak, jamBuka;
  final double lat, lng, rating;
  final double? jarakKm;
  bool isFavorit;
  final List<Program> program;
  BimbelDetail({
    required this.id,
    required this.nama,
    required this.alamat,
    required this.kota,
    required this.deskripsi,
    required this.kontak,
    required this.jamBuka,
    required this.lat,
    required this.lng,
    required this.rating,
    required this.jumlahReview,
    required this.isFavorit,
    required this.program,
    this.jarakKm,
  });
  factory BimbelDetail.fromJson(Map<String, dynamic> j) => BimbelDetail(
        id: _i(j['id']),
        nama: j['nama'] ?? '',
        alamat: j['alamat'] ?? '',
        kota: j['kota'] ?? '',
        deskripsi: j['deskripsi'] ?? '',
        kontak: j['kontak'] ?? '',
        jamBuka: j['jam_buka'] ?? '',
        lat: _d(j['latitude']),
        lng: _d(j['longitude']),
        rating: _d(j['rating_avg']),
        jumlahReview: _i(j['jumlah_review']),
        jarakKm: j['jarak_km'] == null ? null : _d(j['jarak_km']),
        isFavorit: j['is_favorit'] == true,
        program: ((j['program'] ?? []) as List)
            .map((e) => Program.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class Review {
  final String nama, komentar, createdAt;
  final int rating;
  Review({required this.nama, required this.komentar, required this.createdAt, required this.rating});
  factory Review.fromJson(Map<String, dynamic> j) => Review(
        nama: j['nama'] ?? '',
        komentar: j['komentar'] ?? '',
        createdAt: j['created_at'] ?? '',
        rating: _i(j['rating']),
      );
}

class Pendaftaran {
  final int id, totalIdr, durasiMinggu, bimbelId;
  final String status, metodeBayar, createdAt;
  final String bimbelNama, bimbelAlamat, namaProgram, jenjang, mapel, mode;
  final String hari, jamMulai, jamSelesai, tanggalMulai;
  Pendaftaran({
    required this.id,
    required this.status,
    required this.totalIdr,
    required this.metodeBayar,
    required this.createdAt,
    required this.bimbelId,
    required this.bimbelNama,
    required this.bimbelAlamat,
    required this.namaProgram,
    required this.jenjang,
    required this.mapel,
    required this.mode,
    required this.durasiMinggu,
    required this.hari,
    required this.jamMulai,
    required this.jamSelesai,
    required this.tanggalMulai,
  });
  factory Pendaftaran.fromJson(Map<String, dynamic> j) {
    final p = Map<String, dynamic>.from(j['program']);
    final b = Map<String, dynamic>.from(j['bimbel']);
    final w = Map<String, dynamic>.from(j['jadwal']);
    return Pendaftaran(
      id: _i(j['id']),
      status: j['status'] ?? '',
      totalIdr: _i(j['total_idr']),
      metodeBayar: j['metode_bayar'] ?? '',
      createdAt: j['created_at'] ?? '',
      bimbelId: _i(b['id']),
      bimbelNama: b['nama'] ?? '',
      bimbelAlamat: b['alamat'] ?? '',
      namaProgram: p['nama_program'] ?? '',
      jenjang: p['jenjang'] ?? '',
      mapel: p['mapel'] ?? '',
      mode: p['mode'] ?? '',
      durasiMinggu: _i(p['durasi_minggu']),
      hari: w['hari'] ?? '',
      jamMulai: w['jam_mulai'] ?? '',
      jamSelesai: w['jam_selesai'] ?? '',
      tanggalMulai: w['tanggal_mulai'] ?? '',
    );
  }
}

class BlockItem {
  final int index, nonce;
  final String event, hash, prevHash, createdAt;
  BlockItem({
    required this.index,
    required this.event,
    required this.hash,
    required this.prevHash,
    required this.nonce,
    required this.createdAt,
  });
  factory BlockItem.fromJson(Map<String, dynamic> j) => BlockItem(
        index: _i(j['block_index']),
        event: j['event'] ?? '-',
        hash: j['hash'] ?? '',
        prevHash: j['prev_hash'] ?? '',
        nonce: _i(j['nonce']),
        createdAt: j['created_at'] ?? '',
      );
}

class ValidasiHasil {
  final bool valid;
  final int totalBlock;
  final String pesan;
  ValidasiHasil({required this.valid, required this.totalBlock, required this.pesan});
}
