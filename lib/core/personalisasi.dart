import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'format.dart';
import 'local_db.dart';

/// Profil personalisasi pengguna (peran, tujuan, mapel, estimasi biaya).
/// Disimpan di Hive per akun, lalu dipakai Beranda, Cari, dan Tutor AI.
class Personalisasi extends ChangeNotifier {
  static final Personalisasi i = Personalisasi._();
  Personalisasi._();

  static const peranOpsi = ['Pelajar SD', 'Pelajar SMP', 'Pelajar SMA', 'Mahasiswa', 'Orang tua'];
  static const jenjangAnakOpsi = ['SD', 'SMP', 'SMA', 'UTBK'];
  /// Pilihan tujuan (langkah 2) menyesuaikan peran dan jenjang yang dipilih di langkah 1.
  static List<String> tujuanUntuk(String? peran, Set<String> jenjangAnak) {
    switch (peran) {
      case 'Pelajar SD':
        return [
          'Membantu mengerjakan PR',
          'Menaikkan nilai',
          'Memahami materi dasar',
          'Mencari bimbel dekat rumah',
          'Belajar mandiri dengan Tutor AI',
        ];
      case 'Pelajar SMP':
        return [
          'Menaikkan nilai',
          'Persiapan ujian sekolah',
          'Persiapan masuk SMA favorit',
          'Memperdalam materi',
          'Mencari bimbel dekat rumah',
          'Belajar mandiri dengan Tutor AI',
        ];
      case 'Pelajar SMA':
        return [
          'Menaikkan nilai',
          'Persiapan ujian sekolah',
          'Persiapan UTBK',
          'Memperdalam materi',
          'Mencari bimbel dekat rumah',
          'Belajar mandiri dengan Tutor AI',
        ];
      case 'Mahasiswa':
        return [
          'Persiapan UTBK',
          'Mengulang materi dasar',
          'Belajar mata kuliah dasar',
          'Mencari bimbel dekat kampus',
          'Belajar mandiri dengan Tutor AI',
        ];
      case 'Orang tua':
        return [
          'Mencari bimbel untuk anak',
          'Membantu menaikkan nilai anak',
          'Persiapan ujian anak',
          if (jenjangAnak.contains('SMA') || jenjangAnak.contains('UTBK')) 'Persiapan UTBK anak',
          'Membandingkan biaya dan jadwal bimbel',
          'Memantau jadwal belajar anak',
        ];
    }
    return [];
  }
  static const mapelOpsi = [
    'Matematika',
    'Fisika',
    'Kimia',
    'Biologi',
    'Bahasa Inggris',
    'Bahasa Indonesia',
    'IPA',
  ];
  static const budgetOpsi = <(String, int?)>[
    ('Sampai Rp300.000', 300000),
    ('Sampai Rp500.000', 500000),
    ('Sampai Rp750.000', 750000),
    ('Fleksibel', null),
  ];

  int? _userId;
  bool sudahAtur = false; // sudah pernah melewati/mengisi halaman personalisasi
  bool budgetDipilih = false;
    String? peran;
  Set<String> jenjangAnak = {}; // khusus Orang tua: boleh lebih dari satu
  Set<String> tujuan = {};
  Set<String> mapel = {};
  int? budgetMax; // per bulan; null = fleksibel

  /// True jika pengguna benar-benar mengisi sesuatu (bukan sekadar melewati).
  bool get aktif => peran != null || tujuan.isNotEmpty || mapel.isNotEmpty || budgetDipilih;

  /// Jenjang yang dipakai untuk menyaring bimbel.
  /// Semua jenjang yang relevan untuk menyaring bimbel.
  Set<String> get jenjangSet {
    switch (peran) {
      case 'Pelajar SD':
        return {'SD'};
      case 'Pelajar SMP':
        return {'SMP'};
      case 'Pelajar SMA':
        return {'SMA'};
      case 'Orang tua':
        return jenjangAnak;
      case 'Mahasiswa':
        return tujuan.contains('Persiapan UTBK') ? {'UTBK'} : {};
    }
    return {};
  }

  /// Jenjang tunggal untuk filter server; null jika tidak ada atau lebih dari satu.
  String? get jenjang => jenjangSet.length == 1 ? jenjangSet.first : null;

  String get _kunci => 'personalisasi_$_userId';

  void _reset() {
    sudahAtur = false;
    budgetDipilih = false;
    peran = null;
    jenjangAnak = {};
    tujuan = {};
    mapel = {};
    budgetMax = null;
  }

  /// Dipanggil saat Beranda dibuka: muat profil milik akun yang sedang masuk.
  Future<void> muat(int? userId) async {
    _userId = userId;
    _reset();
    if (userId != null) {
      try {
        final raw = await LocalDb.getSetting(_kunci);
        if (raw != null) {
          final m = jsonDecode(raw) as Map<String, dynamic>;
          sudahAtur = true;
          peran = m['peran'] as String?;
          final ja = m['jenjang_anak']; // data lama berupa teks, data baru berupa daftar
          jenjangAnak = ja is List ? ja.map((e) => e.toString()).toSet() : (ja is String ? {ja} : <String>{});
          tujuan = ((m['tujuan'] ?? []) as List).map((e) => e.toString()).toSet();
          mapel = ((m['mapel'] ?? []) as List).map((e) => e.toString()).toSet();
          budgetDipilih = m['budget_dipilih'] == true;
          budgetMax = (m['budget_max'] as num?)?.toInt();
        }
      } catch (_) {}
    }
    notifyListeners();
  }

  Map<String, dynamic> toJson() => {
        'peran': peran,
        'jenjang_anak': jenjangAnak.toList(),
        'tujuan': tujuan.toList(),
        'mapel': mapel.toList(),
        'budget_dipilih': budgetDipilih,
        'budget_max': budgetMax,
      };

  Future<void> _simpan() async {
    if (_userId == null) return;
    try {
      await LocalDb.setSetting(_kunci, jsonEncode(toJson()));
    } catch (_) {}
  }

  Future<void> simpan({
    required String peran,
    required Set<String> jenjangAnak,
    required Set<String> tujuan,
    required Set<String> mapel,
    required int? budgetMax,
  }) async {
    this.peran = peran;
    this.jenjangAnak = peran == 'Orang tua' ? {...jenjangAnak} : {};
    this.tujuan = {...tujuan};
    this.mapel = {...mapel};
    this.budgetMax = budgetMax;
    budgetDipilih = true;
    sudahAtur = true;
    await _simpan();
    notifyListeners();
  }

  /// Pengguna menutup halaman tanpa mengisi: jangan ditanya lagi setiap membuka aplikasi.
  Future<void> tandaiDilewati() async {
    if (sudahAtur) return;
    sudahAtur = true;
    await _simpan();
  }

  /// Ringkasan singkat untuk ditampilkan di Beranda dan Profil.
  String get ringkasan {
    final bagian = <String>[
      if (peran != null) (peran == 'Orang tua' && jenjangAnak.isNotEmpty) ? 'Orang tua (${jenjangAnak.join(', ')})' : peran!,
      if (mapel.isNotEmpty) mapel.take(2).join(', ') + (mapel.length > 2 ? ' +${mapel.length - 2}' : ''),
      if (budgetMax != null) 'maks. ${Fmt.harga(budgetMax!)}',
    ];
    return bagian.join(' · ');
  }

  String get ringkasanBiaya => budgetMax == null ? 'fleksibel' : 'maks. ${Fmt.harga(budgetMax!)} per bulan';

  /// Teks profil untuk Tutor AI (bahasa Indonesia, apa adanya).
  String get untukAi {
    if (!aktif) return '';
    final b = <String>[];
    if (peran != null) {
      final anak = (peran == 'Orang tua' && jenjangAnak.isNotEmpty) ? ', anaknya di jenjang ${jenjangAnak.join(', ')}' : '';      b.add('peran: $peran$anak');
    }
    if (tujuan.isNotEmpty) b.add('tujuan memakai aplikasi: ${tujuan.join(', ')}');
    if (mapel.isNotEmpty) b.add('mata pelajaran diminati: ${mapel.join(', ')}');
    if (budgetDipilih) {
      b.add(budgetMax == null ? 'budget bimbel fleksibel' : 'budget bimbel maksimal Rp$budgetMax per bulan');
    }
    return b.join('; ');
  }
}