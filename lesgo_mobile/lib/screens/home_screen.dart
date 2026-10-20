import 'dart:math';

import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_settings.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/bimbel_service.dart';
import '../services/location_service.dart';
import '../widgets/bimbel_card.dart';
import '../widgets/common.dart';
import 'main_shell.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  UserLocation? _loc;
  List<Bimbel> _items = [];
  bool _loading = true;
  String? _error;
  final _cari = TextEditingController();

  @override
  void initState() {
    super.initState();
    _muat();
    ShellController.refresh.addListener(_muat);
  }

  @override
  void dispose() {
    ShellController.refresh.removeListener(_muat);
    _cari.dispose();
    super.dispose();
  }

  Future<void> _muat() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final loc = await LocationService.current();
    try {
      final hasil = await BimbelService.list(
        lat: loc.lat,
        lng: loc.lng,
        sort: 'terdekat',
        perPage: 5,
        cacheKey: 'home',
      );
      if (!mounted) return;
      setState(() {
        _loc = loc;
        _items = hasil;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loc = loc;
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _kePencarian([String? q]) {
    ShellController.searchQuery.value = q;
    ShellController.tab.value = 1;
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

  /// Pengganti sementara fitur "goyang": ketuk untuk membuka bimbel acak.
  /// Nanti diganti dengan deteksi accelerometer.
  void _acak() {
    if (_items.isEmpty) {
      showMsg(context, 'Belum ada bimbel untuk direkomendasikan');
      return;
    }
    final b = _items[Random().nextInt(_items.length)];
    Navigator.pushNamed(context, '/detail', arguments: b.id);
  }

  @override
  Widget build(BuildContext context) {
    final nama = (Session.user?.nama ?? 'Teman').split(' ').first;
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _muat,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text.rich(TextSpan(children: [
                    const TextSpan(text: 'Halo, '),
                    TextSpan(text: '$nama!', style: const TextStyle(color: AppColors.primary)),
                  ]), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.ink)),
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.location_on, size: 18, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(_loc?.label ?? 'Mencari lokasi...',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink)),
                  ]),
                ]),
              ),
              IconButton(
                onPressed: () => showMsg(context, 'Notifikasi akan hadir di tahap berikutnya'),
                icon: const Icon(Icons.notifications_none, size: 28),
              ),
            ]),
            const SizedBox(height: 18),
            TextField(
              controller: _cari,
              textInputAction: TextInputAction.search,
              onSubmitted: (v) => _kePencarian(v.trim()),
              decoration: InputDecoration(
                hintText: 'Cari bimbel, mata pelajaran, atau lokasi',
                prefixIcon: const Icon(Icons.search, color: AppColors.muted),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward, color: AppColors.primary),
                  onPressed: () => _kePencarian(_cari.text.trim()),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _Pintasan(Icons.search, 'Cari Bimbel', 'Temukan bimbel terdekat untukmu', AppColors.primary, () => _kePencarian())),
              const SizedBox(width: 10),
              Expanded(child: _Pintasan(Icons.smart_toy_outlined, 'Tutor AI', 'Tanya soal, dapat penjelasan instan', AppColors.primary, () => ShellController.tab.value = 2)),
              const SizedBox(width: 10),
              Expanded(child: _Pintasan(Icons.calculate_outlined, 'Hitung Cepat', 'Hitung biaya & durasi belajar', AppColors.accent, () => ShellController.tab.value = 2)),
            ]),
            const SizedBox(height: 22),
            SectionTitle('Bimbel Terdekat',
                trailing: TextButton(onPressed: () => _kePencarian(), child: const Text('Lihat semua >'))),
            const SizedBox(height: 6),
            if (_loading)
              const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              SizedBox(height: 240, child: ErrorView(message: _error!, onRetry: _muat))
            else if (_items.isEmpty)
              const SizedBox(height: 200, child: EmptyView(icon: Icons.search_off, text: 'Belum ada bimbel di sekitarmu'))
            else
              ListenableBuilder(
                listenable: AppSettings.i,
                builder: (context, _) => Column(children: [
                  for (final b in _items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: BimbelCard(
                        bimbel: b,
                        onTap: () => Navigator.pushNamed(context, '/detail', arguments: b.id),
                        onFavorit: () => _favorit(b),
                      ),
                    ),
                ]),
              ),
            const SizedBox(height: 4),
            Material(
              color: AppColors.accent.withAlpha(40),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _acak,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(children: [
                    Icon(Icons.vibration, color: AppColors.accent, size: 30),
                    SizedBox(width: 14),
                    Expanded(
                      child: Text('Ketuk untuk rekomendasi acak',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink)),
                    ),
                    Icon(Icons.chevron_right, color: AppColors.accent),
                  ]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pintasan extends StatelessWidget {
  final IconData icon;
  final String judul, deskripsi;
  final Color warna;
  final VoidCallback onTap;
  const _Pintasan(this.icon, this.judul, this.deskripsi, this.warna, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Panel(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: warna.withAlpha(30),
          child: Icon(icon, color: warna),
        ),
        const SizedBox(height: 10),
        Text(judul, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.ink)),
        const SizedBox(height: 2),
        Text(deskripsi, maxLines: 3, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
      ]),
    );
  }
}
