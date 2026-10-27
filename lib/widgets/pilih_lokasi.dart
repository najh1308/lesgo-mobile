import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../services/location_service.dart';
import 'common.dart';

/// Kota populer sebagai pintasan cepat.
const _kotaPopuler = <(String, double, double)>[
  ('Jakarta', -6.2088, 106.8456),
  ('Bandung', -6.9175, 107.6191),
  ('Semarang', -6.9666, 110.4196),
  ('Yogyakarta', -7.7956, 110.3695),
  ('Surabaya', -7.2575, 112.7521),
  ('Malang', -7.9666, 112.6326),
  ('Medan', 3.5952, 98.6722),
  ('Makassar', -5.1477, 119.4327),
  ('Denpasar', -8.6705, 115.2126),
  ('Palembang', -2.9761, 104.7754),
];

/// Membuka pilihan lokasi: GPS, cari nama tempat, pilih di peta, atau kota populer.
/// Hasilnya langsung disimpan di [LocationService] sehingga Beranda & Cari memuat ulang sendiri.
Future<void> tampilPilihLokasi(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => const _PilihLokasiSheet(),
  );
}

class _PilihLokasiSheet extends StatefulWidget {
  const _PilihLokasiSheet();

  @override
  State<_PilihLokasiSheet> createState() => _PilihLokasiSheetState();
}

class _PilihLokasiSheetState extends State<_PilihLokasiSheet> {
  final _q = TextEditingController();
  Timer? _debounce;
  List<TempatHasil> _hasil = [];
  bool _mencari = false;
  bool _gpsLoading = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  void _tunda(String v) {
    _debounce?.cancel();
    if (v.trim().length < 3) {
      setState(() {
        _hasil = [];
        _error = null;
        _mencari = false;
      });
      return;
    }
    // Nominatim membatasi ±1 permintaan per detik, jadi pencarian ditunda.
    _debounce = Timer(const Duration(milliseconds: 700), _cari);
  }

  Future<void> _cari() async {
    setState(() {
      _mencari = true;
      _error = null;
    });
    try {
      final r = await LocationService.cariTempat(_q.text);
      if (!mounted) return;
      setState(() {
        _hasil = r;
        _mencari = false;
        if (r.isEmpty)
          _error = 'Tempat tidak ditemukan. Coba nama kota atau kecamatan.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _mencari = false;
        _error = 'Tidak bisa mencari lokasi. Periksa koneksi internet.';
      });
    }
  }

  Future<void> _pakai(double lat, double lng, String nama) async {
    await LocationService.setPilihan(lat, lng, nama);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _gps() async {
    setState(() => _gpsLoading = true);
    await LocationService.pakaiGps();
    if (!mounted) return;
    final dapat = LocationService.terakhir?.asli == true;
    Navigator.pop(context);
    if (!dapat) {
      showMsg(
        context,
        'GPS tidak tersedia atau izin ditolak. Memakai lokasi cadangan.',
        error: true,
      );
    }
  }

  Future<void> _dariPeta() async {
    final awal = await LocationService.current();
    if (!mounted) return;
    final dipilih = await Navigator.of(context).push<_TitikPeta>(
      MaterialPageRoute(
        builder: (_) => _PilihDiPeta(awal: LatLng(awal.lat, awal.lng)),
      ),
    );
    if (dipilih == null || !mounted) return;
    await _pakai(dipilih.titik.latitude, dipilih.titik.longitude, dipilih.nama);
  }

  @override
  Widget build(BuildContext context) {
    final pilihan = LocationService.pilihan;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.88,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Pilih lokasi',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                pilihan == null
                    ? 'Saat ini mengikuti lokasi GPS-mu. Pilih lokasi lain untuk mencari bimbel di sana.'
                    : 'Saat ini memakai: ${pilihan.label}',
                style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _q,
                onChanged: _tunda,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _cari(),
                decoration: InputDecoration(
                  hintText: 'Cari kota, kecamatan, kampus, atau alamat...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _mencari
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : (_q.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () {
                                  _q.clear();
                                  _tunda('');
                                },
                              )),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              for (final t in _hasil)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.place_outlined,
                    color: AppColors.indigo,
                  ),
                  title: Text(
                    t.nama,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: t.detail.isEmpty
                      ? null
                      : Text(
                          t.detail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                  onTap: () => _pakai(
                    t.lat,
                    t.lng,
                    t.detail.isEmpty
                        ? t.nama
                        : '${t.nama}, ${t.detail.split(',').first}',
                  ),
                ),
              if (_hasil.isEmpty) ...[
                const SizedBox(height: 6),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: _gpsLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                      : const Icon(
                          Icons.my_location_rounded,
                          color: AppColors.teal,
                        ),
                  title: const Text('Gunakan lokasi saya sekarang'),
                  subtitle: const Text('Ikuti GPS perangkat'),
                  trailing: pilihan == null
                      ? const Icon(Icons.check_circle, color: AppColors.teal)
                      : null,
                  onTap: _gpsLoading ? null : _gps,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.map_outlined,
                    color: AppColors.indigo,
                  ),
                  title: const Text('Pilih di peta'),
                  subtitle: const Text('Ketuk titik mana pun di peta'),
                  onTap: _dariPeta,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Kota populer',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final k in _kotaPopuler)
                      ActionChip(
                        label: Text(k.$1),
                        onPressed: () => _pakai(k.$2, k.$3, k.$1),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TitikPeta {
  final LatLng titik;
  final String nama;
  const _TitikPeta(this.titik, this.nama);
}

/// Halaman peta layar penuh: ketuk untuk menaruh pin, lalu konfirmasi.
class _PilihDiPeta extends StatefulWidget {
  final LatLng awal;
  const _PilihDiPeta({required this.awal});

  @override
  State<_PilihDiPeta> createState() => _PilihDiPetaState();
}

class _PilihDiPetaState extends State<_PilihDiPeta> {
  LatLng? _titik;
  String? _nama;
  bool _memuatNama = false;

  Future<void> _ketuk(LatLng p) async {
    setState(() {
      _titik = p;
      _nama = null;
      _memuatNama = true;
    });
    final n = await LocationService.namaDari(p.latitude, p.longitude);
    if (!mounted || _titik != p) return; // pin sudah dipindah lagi
    setState(() {
      _nama = n;
      _memuatNama = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final titik = _titik;
    return Scaffold(
      appBar: AppBar(title: const Text('Pilih di peta')),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: widget.awal,
              initialZoom: 13,
              onTap: (_, p) => _ketuk(p),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: Config.mapUserAgent,
              ),
              if (titik != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: titik,
                      width: 46,
                      height: 46,
                      alignment: Alignment.topCenter,
                      child: const Icon(
                        Icons.location_on,
                        size: 46,
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const Positioned(
            right: 6,
            bottom: 4,
            child: Text(
              '© OpenStreetMap',
              style: TextStyle(fontSize: 10, color: Colors.black54),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 14,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titik == null
                          ? 'Ketuk peta untuk menaruh pin lokasi'
                          : (_memuatNama
                                ? 'Mencari nama tempat...'
                                : (_nama ?? '')),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    PrimaryButton(
                      label: 'Gunakan lokasi ini',
                      icon: Icons.check_rounded,
                      onPressed: (titik == null || _memuatNama || _nama == null)
                          ? null
                          : () => Navigator.pop(
                              context,
                              _TitikPeta(titik, _nama!),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
