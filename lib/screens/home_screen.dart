import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

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

  // Sensor goyang (akselerometer): goyangkan HP untuk rekomendasi bimbel acak.
  StreamSubscription<UserAccelerometerEvent>? _sensor;
  DateTime _goyangTerakhir = DateTime.fromMillisecondsSinceEpoch(0);
  static const _batasGoyang = 14.0; // m/s², tanpa gravitasi

  @override
  void initState() {
    super.initState();
    _muat();
    ShellController.refresh.addListener(_muat);
    _sensor = userAccelerometerEventStream(samplingPeriod: SensorInterval.uiInterval).listen(
      _cekGoyang,
      onError: (_) {}, // perangkat tanpa sensor (mis. Chrome/emulator): fitur ketuk tetap jalan
      cancelOnError: true,
    );
  }

  @override
  void dispose() {
    ShellController.refresh.removeListener(_muat);
    _sensor?.cancel();
    _cari.dispose();
    super.dispose();
  }

  void _cekGoyang(UserAccelerometerEvent e) {
    // Hanya aktif saat Beranda sedang tampil.
    if (!mounted || ShellController.tab.value != 0) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    final kuat = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
    final now = DateTime.now();
    if (kuat > _batasGoyang && now.difference(_goyangTerakhir).inMilliseconds > 2500) {
      _goyangTerakhir = now;
      HapticFeedback.mediumImpact();
      _acak();
    }
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

  void _kePencarian({String? q, String? jenjang}) {
    ShellController.searchJenjang.value = jenjang;
    ShellController.searchQuery.value = q ?? '';
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

  /// Rekomendasi kejutan: buka bimbel acak dari daftar terdekat.
  void _acak() {
    if (_items.isEmpty) {
      showMsg(context, 'Belum ada bimbel untuk direkomendasikan');
      return;
    }
    final b = _items[Random().nextInt(_items.length)];
    Navigator.pushNamed(context, '/detail', arguments: b.id);
  }

  String get _salam {
    final j = DateTime.now().hour;
    if (j < 11) return 'Selamat pagi,';
    if (j < 15) return 'Selamat siang,';
    if (j < 18) return 'Selamat sore,';
    return 'Selamat malam,';
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light, // ikon status bar putih di atas header biru
      child: RefreshIndicator(
      onRefresh: _muat,
      edgeOffset: MediaQuery.paddingOf(context).top,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _hero(context),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _promo(),
              const SizedBox(height: 26),
              const SectionTitle('Pilih jenjangmu'),
              const SizedBox(height: 13),
              _jenjang(),
              const SizedBox(height: 26),
              _kartuGoyang(),
              const SizedBox(height: 26),
              SectionTitle('Bimbel terdekat', action: 'Lihat semua', onAction: () => _kePencarian()),
              const SizedBox(height: 13),
              _daftarTerdekat(),
              const SizedBox(height: 26),
              const SectionTitle('Belajar sesuai caramu'),
              const SizedBox(height: 13),
              Row(children: [
                Expanded(
                  child: _Pintasan(
                    icon: Icons.smart_toy_outlined,
                    bg: AppColors.softBlue,
                    fg: AppColors.indigo,
                    judul: 'Tutor AI',
                    sub: 'Tanya materi apa saja',
                    onTap: () => Navigator.pushNamed(context, '/tutor'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Pintasan(
                    icon: Icons.sports_esports_outlined,
                    bg: AppColors.softCoral,
                    fg: const Color(0xFFCF6F29),
                    judul: 'Hitung Cepat',
                    sub: 'Main & latih fokusmu',
                    onTap: () => Navigator.pushNamed(context, '/game'),
                  ),
                ),
              ]),
            ]),
          ),
        ],
      ),
      ),
    );
  }

  Widget _hero(BuildContext context) {
    final u = Session.user;
    final nama = (u?.nama ?? 'Teman').split(' ').first;
    return Container(
      padding: EdgeInsets.fromLTRB(18, MediaQuery.paddingOf(context).top + 16, 18, 20),
      decoration: const BoxDecoration(
        color: AppColors.indigo,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Brand(light: true),
          const Spacer(),
          SquareIconButton(
            Icons.notifications_none_rounded,
            light: true,
            dot: true,
            tooltip: 'Jadwal & pengingat',
            onTap: () => ShellController.tab.value = 3,
          ),
        ]),
        const SizedBox(height: 22),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_salam, style: TextStyle(fontSize: 12.5, color: Colors.white.withAlpha(200))),
              const SizedBox(height: 2),
              Text('Halo, $nama!',
                  style: const TextStyle(
                      fontSize: 25, fontWeight: FontWeight.w800, letterSpacing: -0.7, color: Colors.white)),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.location_on_outlined, size: 15, color: Colors.white.withAlpha(190)),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(_loc?.label ?? 'Mencari lokasi...',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: Colors.white.withAlpha(190))),
                ),
              ]),
            ]),
          ),
          GestureDetector(
            onTap: () => ShellController.tab.value = 4,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.coral,
                border: Border.all(color: Colors.white.withAlpha(72), width: 3),
                image: u?.foto == null ? null : DecorationImage(image: u!.foto!, fit: BoxFit.cover),
              ),
              alignment: Alignment.center,
              child: u?.foto != null
                  ? null
                  : Text(nama.isEmpty ? '?' : nama[0].toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.slate)),
            ),
          ),
        ]),
        const SizedBox(height: 18),
        Container(
          height: 50,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
          child: TextField(
            controller: _cari,
            textInputAction: TextInputAction.search,
            onSubmitted: (v) => _kePencarian(q: v.trim()),
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Cari bimbel, mapel, atau lokasi...',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: const EdgeInsets.symmetric(vertical: 15),
              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF8590A0), size: 21),
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_forward_rounded, color: AppColors.teal),
                onPressed: () => _kePencarian(q: _cari.text.trim()),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _promo() {
    return Container(
      height: 148,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: AppColors.slate, borderRadius: BorderRadius.circular(18)),
      child: Stack(children: [
        Positioned(
          right: 14,
          bottom: -6,
          child: Transform.rotate(
            angle: 0.14,
            child: Container(
              width: 110,
              height: 130,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.teal, AppColors.tealDark],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(60)),
              ),
              child: Stack(children: [
                const Positioned(
                  top: 14,
                  left: 16,
                  child: Text('π', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.coral)),
                ),
                const Positioned(
                  top: 40,
                  right: 12,
                  child: Text('✦', style: TextStyle(fontSize: 16, color: AppColors.coral)),
                ),
                Center(
                  child: Transform.rotate(
                    angle: -0.14,
                    child: const Text('A+',
                        style: TextStyle(fontSize: 33, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                ),
              ]),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 140, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Eyebrow('BELAJAR LEBIH DEKAT', icon: Icons.auto_awesome),
            const SizedBox(height: 10),
            const Text('Temukan bimbel terbaik\ndi sekitarmu',
                style: TextStyle(fontSize: 17.5, fontWeight: FontWeight.w800, height: 1.3, color: Colors.white)),
            const Spacer(),
            GestureDetector(
              onTap: () => _kePencarian(),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Text('Jelajahi sekarang',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.teal)),
                Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.teal),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _jenjang() {
    const data = [('SD', 'Kelas 1–6'), ('SMP', 'Kelas 7–9'), ('SMA', 'Kelas 10–12'), ('UTBK', 'Siap PTN')];
    return Row(children: [
      for (var i = 0; i < data.length; i++) ...[
        if (i > 0) const SizedBox(width: 9),
        Expanded(
          child: Material(
            color: i == 3 ? AppColors.softCoral : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: i == 3 ? const Color(0xFFFFD1AF) : AppColors.line),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _kePencarian(jenjang: data[i].$1),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
                child: Column(children: [
                  Text(data[i].$1,
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: i == 3 ? AppColors.coralDark : AppColors.indigo)),
                  const SizedBox(height: 3),
                  Text(data[i].$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
                ]),
              ),
            ),
          ),
        ),
      ],
    ]);
  }

  Widget _kartuGoyang() {
    return Material(
      color: AppColors.softTeal,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFA8DCD5)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _acak,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(children: [
            const IconBox(Icons.vibration_rounded, bg: AppColors.teal, fg: Colors.white, size: 40),
            const SizedBox(width: 11),
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Bingung pilih bimbel?',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.ink)),
                SizedBox(height: 2),
                Text('Goyangkan HP (atau ketuk) untuk rekomendasi kejutan',
                    style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(7)),
              child: const Text('COBA',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.teal)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _daftarTerdekat() {
    if (_loading) {
      return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) return SizedBox(height: 260, child: ErrorView(message: _error!, onRetry: _muat));
    if (_items.isEmpty) {
      return const SizedBox(height: 200, child: EmptyView(icon: Icons.search_off, text: 'Belum ada bimbel di sekitarmu'));
    }
    return ListenableBuilder(
      listenable: AppSettings.i,
      builder: (context, _) => Column(children: [
        for (var i = 0; i < _items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: BimbelCard(
              bimbel: _items[i],
              horizontal: i > 0,
              badge: i == 0 ? 'Paling dekat' : null,
              onTap: () => Navigator.pushNamed(context, '/detail', arguments: _items[i].id),
              onFavorit: () => _favorit(_items[i]),
            ),
          ),
      ]),
    );
  }
}

class _Pintasan extends StatelessWidget {
  final IconData icon;
  final Color bg, fg;
  final String judul, sub;
  final VoidCallback onTap;
  const _Pintasan({
    required this.icon,
    required this.bg,
    required this.fg,
    required this.judul,
    required this.sub,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            IconBox(icon, bg: bg, fg: fg, size: 38),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(judul, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.ink)),
                const SizedBox(height: 2),
                Text(sub,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.muted),
          ]),
        ),
      ),
    );
  }
}
