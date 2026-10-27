import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../core/api_client.dart';
import '../core/app_settings.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/bimbel_service.dart';
import '../services/location_service.dart';
import '../widgets/bimbel_card.dart';
import '../widgets/bimbel_map.dart';
import '../widgets/common.dart';
import '../widgets/pilih_lokasi.dart';
import 'main_shell.dart';
import '../core/personalisasi.dart';

class _Opsi<T> {
  final String label;
  final T? nilai;
  const _Opsi(this.label, this.nilai);
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _q = TextEditingController();
  Timer? _debounce;

  String? _jenjang, _mapel, _mode;
  int? _hargaMax;
  double? _ratingMin, _radius;
  String _urut = 'terdekat';
  bool _peta = false;

  List<Bimbel> _items = [];
  bool _loading = true;
  String? _error;
  UserLocation? _loc;
  Bimbel? _dipilih;

  @override
  void initState() {
    super.initState();
    _isiDariPersonalisasi();
    Personalisasi.i.addListener(_personalisasiBerubah);
    ShellController.searchQuery.addListener(_dariBeranda);
    LocationService.berubah.addListener(_lokasiBerubah);
    _muat();
  }

  /// Lokasi diganti (dari Beranda atau dari tab ini): ambil lokasi baru lalu muat ulang.
  void _lokasiBerubah() {
    _loc = null;
    _muat();
  }

  /// Filter awal mengikuti jawaban personalisasi (bisa direset lewat tombol reset filter).
  void _isiDariPersonalisasi() {
    final p = Personalisasi.i;
    if (!p.aktif) return;
    _jenjang = p.jenjang;
    _hargaMax = p.budgetMax;
    _mapel = p.mapel.length == 1 ? p.mapel.first : null;
  }

  void _personalisasiBerubah() {
    _isiDariPersonalisasi();
    _muat();
  }

  @override
  void dispose() {
    Personalisasi.i.removeListener(_personalisasiBerubah);
    ShellController.searchQuery.removeListener(_dariBeranda);
    LocationService.berubah.removeListener(_lokasiBerubah);
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  /// Kata kunci yang dikirim dari kolom pencarian di Beranda.
  void _dariBeranda() {
    final v = ShellController.searchQuery.value;
    if (v == null) return; // reset internal, abaikan
    _q.text = v;
    _jenjang = ShellController.searchJenjang.value;
    ShellController.searchJenjang.value = null;
    ShellController.searchQuery.value = null;
    _muat();
  }

  void _tundaMuat(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), _muat);
  }

  Future<void> _muat() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    _loc ??= await LocationService.current();
    try {
      final hasil = await BimbelService.list(
        lat: _loc!.lat,
        lng: _loc!.lng,
        q: _q.text.trim(),
        jenjang: _jenjang,
        mapel: _mapel,
        mode: _mode,
        hargaMax: _hargaMax,
        ratingMin: _ratingMin,
        radius: _radius,
        sort: _urut,
      );
      if (!mounted) return;
      setState(() {
        _items = hasil;
        _dipilih = null;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _favorit(Bimbel b) async {
    final baru = !b.isFavorit;
    setState(() => b.isFavorit = baru);
    try {
      await BimbelService.setFavorit(b.id, baru);
      ShellController.bump();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => b.isFavorit = !baru);
      showMsg(context, e.message, error: true);
    }
  }

  Future<void> _pilih<T>(
    String judul,
    List<_Opsi<T>> opsi,
    ValueChanged<T?> onPilih,
  ) async {
    final hasil = await showModalBottomSheet<_Opsi<T>>(
      context: context,
      backgroundColor: Colors.white,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              judul,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            for (final o in opsi)
              ListTile(title: Text(o.label), onTap: () => Navigator.pop(c, o)),
          ],
        ),
      ),
    );
    if (hasil == null) return;
    setState(() => onPilih(hasil.nilai));
    _muat();
  }

  static const _labelUrut = {
    'terdekat': 'Terdekat',
    'termurah': 'Termurah',
    'rating': 'Rating tertinggi',
  };

  void _pilihMapel() => _pilih<String>('Mata pelajaran', const [
    _Opsi('Semua', null),
    _Opsi('Matematika', 'Matematika'),
    _Opsi('Fisika', 'Fisika'),
    _Opsi('Kimia', 'Kimia'),
    _Opsi('Biologi', 'Biologi'),
    _Opsi('Bahasa Inggris', 'Bahasa Inggris'),
    _Opsi('Bahasa Indonesia', 'Bahasa Indonesia'),
    _Opsi('IPA', 'IPA'),
  ], (v) => _mapel = v);

  void _pilihHarga() => _pilih<int>('Harga maksimal per bulan', const [
    _Opsi('Semua', null),
    _Opsi('Sampai Rp300.000', 300000),
    _Opsi('Sampai Rp500.000', 500000),
    _Opsi('Sampai Rp750.000', 750000),
  ], (v) => _hargaMax = v);

  void _pilihRating() => _pilih<double>('Rating minimum', const [
    _Opsi('Semua', null),
    _Opsi('4,0 ke atas', 4.0),
    _Opsi('4,5 ke atas', 4.5),
  ], (v) => _ratingMin = v);

  void _pilihMode() => _pilih<String>('Mode belajar', const [
    _Opsi('Semua', null),
    _Opsi('Online', 'online'),
    _Opsi('Offline', 'offline'),
  ], (v) => _mode = v);

  void _pilihJarak() => _pilih<double>('Jarak maksimal', const [
    _Opsi('Semua', null),
    _Opsi('Sampai 2 km', 2),
    _Opsi('Sampai 5 km', 5),
    _Opsi('Sampai 10 km', 10),
    _Opsi('Sampai 25 km', 25),
  ], (v) => _radius = v);

  void _pilihUrut() => _pilih<String>('Urutkan hasil', [
    for (final e in _labelUrut.entries) _Opsi(e.value, e.key),
  ], (v) => _urut = v ?? 'terdekat');

  bool get _adaFilter =>
      _jenjang != null ||
      _mapel != null ||
      _hargaMax != null ||
      _ratingMin != null ||
      _mode != null ||
      _radius != null;

  void _resetFilter() {
    setState(() {
      _jenjang = _mapel = _mode = null;
      _hargaMax = null;
      _ratingMin = _radius = null;
    });
    _muat();
  }

  /// Panel filter lengkap (tombol di samping kolom pencarian).
  Future<void> _panelFilter() async {
    final aksi = await showModalBottomSheet<VoidCallback>(
      context: context,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          children: [
            const Row(
              children: [
                IconBox(Icons.tune_rounded, size: 40),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Filter pencarian',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Temukan bimbel yang paling sesuai.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final f in [
              (
                'Mata pelajaran',
                _mapel ?? 'Semua',
                Icons.menu_book_outlined,
                _pilihMapel,
              ),
              (
                'Harga maksimal',
                _hargaMax == null ? 'Semua' : Fmt.harga(_hargaMax!),
                Icons.payments_outlined,
                _pilihHarga,
              ),
              (
                'Rating minimum',
                _ratingMin == null ? 'Semua' : '${Fmt.rating(_ratingMin!)}+',
                Icons.star_outline_rounded,
                _pilihRating,
              ),
              (
                'Mode belajar',
                _mode == null
                    ? 'Semua'
                    : (_mode == 'online' ? 'Online' : 'Offline'),
                Icons.wifi_rounded,
                _pilihMode,
              ),
              (
                'Jarak maksimal',
                _radius == null ? 'Semua' : '${_radius!.toStringAsFixed(0)} km',
                Icons.route_outlined,
                _pilihJarak,
              ),
              ('Urutkan', _labelUrut[_urut]!, Icons.sort_rounded, _pilihUrut),
            ])
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: IconBox(f.$3, size: 36),
                title: Text(
                  f.$1,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      f.$2,
                      style: const TextStyle(
                        color: AppColors.teal,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.muted,
                    ),
                  ],
                ),
                onTap: () => Navigator.pop(c, f.$4),
              ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.pop(c, _resetFilter),
              child: const Text('Hapus semua filter'),
            ),
          ],
        ),
      ),
    );
    aksi?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeader(
          title: 'Temukan bimbel',
          subtitle: 'Belajar terbaik, di sekitar kamu',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: TextField(
                    controller: _q,
                    onChanged: _tundaMuat,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _muat(),
                    style: const TextStyle(fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Cari bimbel atau mata pelajaran',
                      contentPadding: EdgeInsets.zero,
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: AppColors.muted,
                        size: 21,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Material(
                color: AppColors.indigo,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _panelFilter,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Icon(Icons.tune_rounded, color: Colors.white),
                        if (_adaFilter)
                          Positioned(
                            right: 10,
                            top: 10,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.coral,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
            children: [
              _Chip('Semua', !_adaFilter, _resetFilter),
              for (final j in ['SD', 'SMP', 'SMA'])
                _Chip(j, _jenjang == j, () {
                  setState(() => _jenjang = _jenjang == j ? null : j);
                  _muat();
                }),
              _Chip(_mapel ?? 'Mapel', _mapel != null, _pilihMapel),
              _Chip(
                _ratingMin == null
                    ? 'Rating 4,5+'
                    : 'Rating ${Fmt.rating(_ratingMin!)}+',
                _ratingMin != null,
                () {
                  if (_ratingMin != null) {
                    setState(() => _ratingMin = null);
                    _muat();
                  } else {
                    _pilihRating();
                  }
                },
              ),
              _Chip(
                _mode == null
                    ? 'Online/Offline'
                    : (_mode == 'online' ? 'Online' : 'Offline'),
                _mode != null,
                _pilihMode,
              ),
              _Chip(
                _hargaMax == null ? 'Harga' : '≤ ${Fmt.harga(_hargaMax!)}',
                _hargaMax != null,
                _pilihHarga,
              ),
              _Chip(
                _radius == null
                    ? 'Jarak'
                    : '≤ ${_radius!.toStringAsFixed(0)} km',
                _radius != null,
                _pilihJarak,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
            decoration: BoxDecoration(
              color: AppColors.softBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.my_location_rounded,
                  size: 17,
                  color: AppColors.indigo,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'Cari di sekitar: '),
                        TextSpan(
                          text: _loc?.label ?? 'mencari...',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.indigo,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => tampilPilihLokasi(context),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Ubah', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _pilihUrut,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _loading
                            ? 'Mencari...'
                            : '${_items.length} bimbel ditemukan',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            'Diurutkan: ${_labelUrut[_urut]}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.muted,
                            ),
                          ),
                          const Icon(
                            Icons.expand_more_rounded,
                            size: 16,
                            color: AppColors.muted,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SegmentToggle(
                labels: const ['List', 'Peta'],
                index: _peta ? 1 : 0,
                onChanged: (i) => setState(() => _peta = i == 1),
              ),
            ],
          ),
        ),
        Expanded(child: _isi()),
      ],
    );
  }

  Widget _isi() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ErrorView(message: _error!, onRetry: _muat);
    if (_items.isEmpty) {
      return const EmptyView(
        icon: Icons.search_off,
        text: 'Tidak ada bimbel yang cocok.\nCoba ubah kata kunci atau filter.',
      );
    }
    return ListenableBuilder(
      listenable: AppSettings.i,
      builder: (context, _) => _peta ? _petaView() : _daftarView(),
    );
  }

  Widget _daftarView() {
    return RefreshIndicator(
      onRefresh: _muat,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
        itemCount: _items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (c, i) => BimbelCard(
          bimbel: _items[i],
          onTap: () =>
              Navigator.pushNamed(context, '/detail', arguments: _items[i].id),
          onFavorit: () => _favorit(_items[i]),
        ),
      ),
    );
  }

  Widget _petaView() {
    final pusat = _dipilih != null
        ? LatLng(_dipilih!.lat, _dipilih!.lng)
        : LatLng(_loc!.lat, _loc!.lng);
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BimbelMap(
                key: ValueKey('${_items.length}-${_dipilih?.id}'),
                items: _items,
                center: pusat,
                user: LatLng(_loc!.lat, _loc!.lng),
                selectedId: _dipilih?.id,
                onSelect: (b) => setState(() => _dipilih = b),
              ),
            ),
          ),
        ),
        if (_dipilih != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
            child: BimbelCard(
              bimbel: _dipilih!,
              onTap: () => Navigator.pushNamed(
                context,
                '/detail',
                arguments: _dipilih!.id,
              ),
              onFavorit: () => _favorit(_dipilih!),
            ),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool aktif;
  final VoidCallback onTap;
  const _Chip(this.label, this.aktif, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: aktif ? AppColors.softTeal : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: aktif ? AppColors.teal : AppColors.line),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: aktif ? FontWeight.w700 : FontWeight.w500,
                  color: aktif ? AppColors.teal : AppColors.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
