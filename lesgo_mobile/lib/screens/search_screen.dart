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
import 'main_shell.dart';

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
    ShellController.searchQuery.addListener(_dariBeranda);
    _muat();
  }

  @override
  void dispose() {
    ShellController.searchQuery.removeListener(_dariBeranda);
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  /// Kata kunci yang dikirim dari kolom pencarian di Beranda.
  void _dariBeranda() {
    final v = ShellController.searchQuery.value;
    if (v != null) {
      _q.text = v;
      ShellController.searchQuery.value = null;
    }
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

  Future<void> _pilih<T>(String judul, List<_Opsi<T>> opsi, ValueChanged<T?> onPilih) async {
    final hasil = await showModalBottomSheet<_Opsi<T>>(
      context: context,
      backgroundColor: Colors.white,
      builder: (c) => SafeArea(
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(16), children: [
          Text(judul, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final o in opsi)
            ListTile(title: Text(o.label), onTap: () => Navigator.pop(c, o)),
        ]),
      ),
    );
    if (hasil == null) return;
    setState(() => onPilih(hasil.nilai));
    _muat();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Text('Cari Bimbel',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.ink)),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 2, 20, 12),
          child: Text('Temukan bimbingan belajar terbaik sesuai kebutuhanmu',
              style: TextStyle(color: AppColors.muted)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: _q,
            onChanged: _tundaMuat,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _muat(),
            decoration: const InputDecoration(
              hintText: 'Cari nama bimbel, mata pelajaran, atau lokasi',
              prefixIcon: Icon(Icons.search, color: AppColors.muted),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 40,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 20), children: [
            for (final j in ['SD', 'SMP', 'SMA', 'UTBK'])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(j),
                  selected: _jenjang == j,
                  onSelected: (v) {
                    setState(() => _jenjang = v ? j : null);
                    _muat();
                  },
                ),
              ),
            _FilterChip('Mata pelajaran', _mapel != null, () => _pilih<String>('Mata pelajaran', const [
                  _Opsi('Semua', null),
                  _Opsi('Matematika', 'Matematika'),
                  _Opsi('Fisika', 'Fisika'),
                  _Opsi('Kimia', 'Kimia'),
                  _Opsi('Biologi', 'Biologi'),
                  _Opsi('Bahasa Inggris', 'Bahasa Inggris'),
                  _Opsi('Bahasa Indonesia', 'Bahasa Indonesia'),
                  _Opsi('IPA', 'IPA'),
                ], (v) => _mapel = v)),
            _FilterChip(_hargaMax == null ? 'Harga' : '≤ ${Fmt.harga(_hargaMax!)}', _hargaMax != null,
                () => _pilih<int>('Harga maksimal per bulan', const [
                      _Opsi('Semua', null),
                      _Opsi('Sampai Rp300.000', 300000),
                      _Opsi('Sampai Rp500.000', 500000),
                      _Opsi('Sampai Rp750.000', 750000),
                    ], (v) => _hargaMax = v)),
            _FilterChip(_ratingMin == null ? 'Rating' : '★ ${_ratingMin!.toStringAsFixed(1)}+', _ratingMin != null,
                () => _pilih<double>('Rating minimum', const [
                      _Opsi('Semua', null),
                      _Opsi('4,0 ke atas', 4.0),
                      _Opsi('4,5 ke atas', 4.5),
                    ], (v) => _ratingMin = v)),
            _FilterChip(_mode == null ? 'Online/Offline' : (_mode == 'online' ? 'Online' : 'Offline'), _mode != null,
                () => _pilih<String>('Mode belajar', const [
                      _Opsi('Semua', null),
                      _Opsi('Online', 'online'),
                      _Opsi('Offline', 'offline'),
                    ], (v) => _mode = v)),
            _FilterChip(_radius == null ? 'Jarak' : '≤ ${_radius!.toStringAsFixed(0)} km', _radius != null,
                () => _pilih<double>('Jarak maksimal', const [
                      _Opsi('Semua', null),
                      _Opsi('Sampai 2 km', 2),
                      _Opsi('Sampai 5 km', 5),
                      _Opsi('Sampai 10 km', 10),
                      _Opsi('Sampai 25 km', 25),
                    ], (v) => _radius = v)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
          child: Row(children: [
            const Text('Urutkan:', style: TextStyle(color: AppColors.muted)),
            const SizedBox(width: 8),
            for (final o in const {'terdekat': 'Terdekat', 'termurah': 'Termurah', 'rating': 'Rating'}.entries)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(o.value),
                  selected: _urut == o.key,
                  onSelected: (_) {
                    setState(() => _urut = o.key);
                    _muat();
                  },
                ),
              ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, icon: Icon(Icons.list), label: Text('Daftar')),
                ButtonSegment(value: true, icon: Icon(Icons.map_outlined), label: Text('Peta')),
              ],
              selected: {_peta},
              onSelectionChanged: (s) => setState(() => _peta = s.first),
            ),
          ),
        ),
        Expanded(child: _isi()),
      ]),
    );
  }

  Widget _isi() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ErrorView(message: _error!, onRetry: _muat);
    if (_items.isEmpty) {
      return const EmptyView(icon: Icons.search_off, text: 'Tidak ada bimbel yang cocok.\nCoba ubah kata kunci atau filter.');
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
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (c, i) => BimbelCard(
          bimbel: _items[i],
          onTap: () => Navigator.pushNamed(context, '/detail', arguments: _items[i].id),
          onFavorit: () => _favorit(_items[i]),
        ),
      ),
    );
  }

  Widget _petaView() {
    final pusat = _dipilih != null
        ? LatLng(_dipilih!.lat, _dipilih!.lng)
        : LatLng(_loc!.lat, _loc!.lng);
    return Column(children: [
      Expanded(
        child: BimbelMap(
          key: ValueKey('${_items.length}-${_dipilih?.id}'),
          items: _items,
          center: pusat,
          user: LatLng(_loc!.lat, _loc!.lng),
          selectedId: _dipilih?.id,
          onSelect: (b) => setState(() => _dipilih = b),
        ),
      ),
      if (_dipilih != null)
        Padding(
          padding: const EdgeInsets.all(12),
          child: BimbelCard(
            bimbel: _dipilih!,
            onTap: () => Navigator.pushNamed(context, '/detail', arguments: _dipilih!.id),
            onFavorit: () => _favorit(_dipilih!),
          ),
        ),
    ]);
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool aktif;
  final VoidCallback onTap;
  const _FilterChip(this.label, this.aktif, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(label),
        onPressed: onTap,
        backgroundColor: aktif ? AppColors.primary.withAlpha(30) : Colors.white,
        side: BorderSide(color: aktif ? AppColors.primary : AppColors.line),
        labelStyle: TextStyle(color: aktif ? AppColors.primary : AppColors.ink),
      ),
    );
  }
}
