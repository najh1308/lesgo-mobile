import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../core/config.dart';
import '../core/local_db.dart';

/// Asal koordinat yang sedang dipakai aplikasi.
enum SumberLokasi {
  gps, // posisi asli dari GPS
  pilihan, // dipilih sendiri oleh pengguna (cari tempat / peta / kota populer)
  cadangan, // GPS tidak tersedia, memakai lokasi default
}

class UserLocation {
  final double lat, lng;
  final SumberLokasi sumber;

  /// Nama tempat untuk lokasi pilihan (mis. "Bandung, Jawa Barat").
  final String? nama;

  const UserLocation(this.lat, this.lng, this.sumber, {this.nama});

  /// true = posisi asli dari GPS.
  bool get asli => sumber == SumberLokasi.gps;

  /// true = lokasi yang dipilih sendiri oleh pengguna.
  bool get pilihan => sumber == SumberLokasi.pilihan;

  String get label {
    switch (sumber) {
      case SumberLokasi.gps:
        return 'Lokasi saya';
      case SumberLokasi.pilihan:
        return (nama == null || nama!.trim().isEmpty)
            ? 'Lokasi pilihan'
            : nama!;
      case SumberLokasi.cadangan:
        return Config.defaultLokasiLabel;
    }
  }
}

/// Hasil pencarian nama tempat.
class TempatHasil {
  final String nama;
  final String detail;
  final double lat, lng;
  const TempatHasil(this.nama, this.detail, this.lat, this.lng);
}

/// LBS: menentukan lokasi acuan pengguna.
/// Urutan prioritas: lokasi yang dipilih sendiri -> GPS -> lokasi cadangan.
class LocationService {
  static const _cadangan = UserLocation(
    Config.defaultLat,
    Config.defaultLng,
    SumberLokasi.cadangan,
  );
  static const _kunciPilihan = 'lokasi_pilihan';

  /// Posisi GPS terakhir yang berhasil didapat.
  static UserLocation? terakhir;

  /// Lokasi yang dipilih sendiri oleh pengguna. null = ikuti GPS.
  static UserLocation? pilihan;

  /// Naik setiap kali lokasi acuan berubah, supaya Beranda dan Cari memuat ulang.
  static final ValueNotifier<int> berubah = ValueNotifier<int>(0);

  /// Lokasi acuan tanpa meminta GPS lagi (null jika belum ada).
  static UserLocation? get aktif => pilihan ?? terakhir;

  /// Dipanggil sekali saat aplikasi dibuka: memulihkan lokasi pilihan yang tersimpan.
  static Future<void> muatTersimpan() async {
    try {
      final raw = await LocalDb.getSetting(_kunciPilihan);
      if (raw == null || raw.isEmpty) return;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      pilihan = UserLocation(
        (m['lat'] as num).toDouble(),
        (m['lng'] as num).toDouble(),
        SumberLokasi.pilihan,
        nama: m['nama'] as String?,
      );
    } catch (_) {}
  }

  /// Pakai lokasi yang dipilih pengguna (dari pencarian, peta, atau kota populer).
  static Future<void> setPilihan(double lat, double lng, String nama) async {
    pilihan = UserLocation(lat, lng, SumberLokasi.pilihan, nama: nama);
    try {
      await LocalDb.setSetting(
        _kunciPilihan,
        jsonEncode({'lat': lat, 'lng': lng, 'nama': nama}),
      );
    } catch (_) {}
    berubah.value++;
  }

  /// Kembali mengikuti GPS (menghapus lokasi pilihan).
  static Future<void> pakaiGps() async {
    pilihan = null;
    try {
      await LocalDb.setSetting(_kunciPilihan, '');
    } catch (_) {}
    await _ambilGps();
    berubah.value++;
  }

  static Future<UserLocation> current() async {
    final p = pilihan;
    if (p != null) return p;
    return _ambilGps();
  }

  static Future<UserLocation> _ambilGps() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled())
        return terakhir ?? _cadangan;
      var izin = await Geolocator.checkPermission();
      if (izin == LocationPermission.denied) {
        izin = await Geolocator.requestPermission();
      }
      if (izin == LocationPermission.denied ||
          izin == LocationPermission.deniedForever) {
        return terakhir ?? _cadangan;
      }
      final pos = await Geolocator.getCurrentPosition().timeout(
        const Duration(seconds: 10),
      );
      return terakhir = UserLocation(
        pos.latitude,
        pos.longitude,
        SumberLokasi.gps,
      );
    } catch (_) {
      return terakhir ?? _cadangan;
    }
  }

  // ---------- Geocoding (OpenStreetMap Nominatim, gratis tanpa API key) ----------

  static const _host = 'nominatim.openstreetmap.org';
  static const _header = {
    'User-Agent': Config.mapUserAgent,
    'Accept-Language': 'id',
  };

  /// Mencari tempat berdasarkan nama (kota, kecamatan, sekolah, alamat, dst.).
  static Future<List<TempatHasil>> cariTempat(String query) async {
    final q = query.trim();
    if (q.length < 3) return [];
    final uri = Uri.https(_host, '/search', {
      'q': q,
      'format': 'jsonv2',
      'limit': '8',
      'addressdetails': '1',
      'countrycodes': 'id',
    });
    final res = await http
        .get(uri, headers: _header)
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200)
      throw Exception('Pencarian lokasi gagal (${res.statusCode}).');
    final data = jsonDecode(res.body) as List;
    return data.map((e) {
      final m = e as Map<String, dynamic>;
      final penuh = (m['display_name'] as String? ?? '')
          .split(',')
          .map((s) => s.trim())
          .toList();
      final nama = (m['name'] as String?)?.isNotEmpty == true
          ? m['name'] as String
          : penuh.first;
      final detail = penuh.skip(1).take(3).join(', ');
      return TempatHasil(
        nama,
        detail,
        double.parse(m['lat'] as String),
        double.parse(m['lon'] as String),
      );
    }).toList();
  }

  /// Nama tempat dari koordinat (dipakai saat pengguna menandai titik di peta).
  static Future<String> namaDari(double lat, double lng) async {
    try {
      final uri = Uri.https(_host, '/reverse', {
        'lat': '$lat',
        'lon': '$lng',
        'format': 'jsonv2',
        'zoom': '14',
        'addressdetails': '1',
      });
      final res = await http
          .get(uri, headers: _header)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final m = jsonDecode(res.body) as Map<String, dynamic>;
        final a = (m['address'] as Map?)?.cast<String, dynamic>() ?? {};
        final bagian = <String>[
          for (final k in [
            'suburb',
            'village',
            'neighbourhood',
            'city_district',
            'town',
            'city',
            'county',
            'state',
          ])
            if (a[k] is String && (a[k] as String).isNotEmpty) a[k] as String,
        ];
        if (bagian.isNotEmpty) return bagian.take(2).join(', ');
        final dn = m['display_name'] as String?;
        if (dn != null && dn.isNotEmpty)
          return dn.split(',').take(2).join(',').trim();
      }
    } catch (_) {}
    return 'Titik di peta (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})';
  }
}
