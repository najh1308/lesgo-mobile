import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api_client.dart';
import '../core/app_settings.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/bimbel_service.dart';
import '../services/location_service.dart';
import '../widgets/bimbel_map.dart';
import '../widgets/common.dart';
import '../widgets/kompas_bimbel.dart';
import 'daftar_screen.dart';
import 'main_shell.dart';

class DetailScreen extends StatefulWidget {
  final int bimbelId;
  const DetailScreen({super.key, required this.bimbelId});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  BimbelDetail? _d;
  List<Review> _review = [];
  bool _loading = true;
  String? _error;
  final _programKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final loc = await LocationService.current();
    try {
      final d = await BimbelService.detail(widget.bimbelId, lat: loc.lat, lng: loc.lng);
      final r = await BimbelService.reviews(widget.bimbelId);
      if (!mounted) return;
      setState(() {
        _d = d;
        _review = r;
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

  Future<void> _favorit() async {
    final d = _d!;
    final baru = !d.isFavorit;
    setState(() => d.isFavorit = baru);
    try {
      await BimbelService.setFavorit(d.id, baru);
      ShellController.bump();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => d.isFavorit = !baru);
      showMsg(context, e.message, error: true);
    }
  }

  /// Membuka aplikasi peta di HP dengan rute ke bimbel (tanpa API key).
  Future<void> _rute() async {
    final d = _d!;
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${d.lat},${d.lng}');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) showMsg(context, 'Tidak dapat membuka aplikasi peta', error: true);
  }

  Future<void> _tulisReview() async {
    int rating = 5;
    final komentar = TextEditingController();
    final kirim = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: const Text('Tulis Review'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  onPressed: () => setD(() => rating = i),
                  icon: Icon(i <= rating ? Icons.star_rounded : Icons.star_border_rounded,
                      color: AppColors.accent, size: 32),
                ),
            ]),
            TextField(
              controller: komentar,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Ceritakan pengalamanmu'),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Kirim')),
          ],
        ),
      ),
    );
    if (kirim != true) return;
    try {
      await BimbelService.tambahReview(widget.bimbelId, rating, komentar.text.trim());
      if (!mounted) return;
      showMsg(context, 'Review tersimpan');
      _muat();
    } on ApiException catch (e) {
      if (mounted) showMsg(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail bimbel')),
        body: _loading ? const Center(child: CircularProgressIndicator()) : ErrorView(message: _error!, onRetry: _muat),
      );
    }
    final d = _d!;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: ListenableBuilder(listenable: AppSettings.i, builder: (c, _) => _isi(d)),
        bottomNavigationBar: ListenableBuilder(listenable: AppSettings.i, builder: (c, _) => _cta(d)),
      ),
    );
  }

  int? get _hargaTermurah {
    final p = _d!.program;
    if (p.isEmpty) return null;
    return p.map((e) => e.hargaIdr).reduce((a, b) => a < b ? a : b);
  }

  void _pilihProgram() {
    final d = _d!;
    final bisa = d.program.where((p) => p.jadwal.isNotEmpty).toList();
    if (bisa.length == 1) {
      Navigator.pushNamed(context, '/daftar', arguments: DaftarArgs(d, bisa.first));
      return;
    }
    final ctx = _programKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
    }
  }

  Widget _cta(BimbelDetail d) {
    final h = _hargaTermurah;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
          child: Row(children: [
            Expanded(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Mulai dari', style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
                Text.rich(
                  TextSpan(children: [
                    TextSpan(
                      text: h == null ? '-' : Fmt.harga(h),
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.indigo),
                    ),
                    const TextSpan(text: ' /bulan', style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ]),
            ),
            SizedBox(
              width: 170,
              child: PrimaryButton(
                label: 'Pilih program',
                onPressed: d.program.any((p) => p.jadwal.isNotEmpty) ? _pilihProgram : null,
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _isi(BimbelDetail d) {
    final top = MediaQuery.paddingOf(context).top;
    final modeSet = {for (final p in d.program) p.mode};
    final modeLabel = modeSet.length > 1
        ? 'Hybrid'
        : modeSet.isEmpty
            ? '-'
            : (modeSet.first == 'online' ? 'Online' : 'Offline');
    return ListView(padding: EdgeInsets.zero, children: [
      SizedBox(
        height: 250 + top,
        child: Stack(fit: StackFit.expand, children: [
          BimbelCover(seed: d.id, fotoUrl: d.foto, iconSize: 72, avatar: true),
          Positioned(
            left: 16,
            top: top + 10,
            child: _TombolBulat(Icons.arrow_back_rounded, () => Navigator.maybePop(context)),
          ),
          Positioned(
            right: 16,
            top: top + 10,
            child: _TombolBulat(
              d.isFavorit ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              _favorit,
              warna: d.isFavorit ? AppColors.danger : AppColors.ink,
            ),
          ),
        ]),
      ),
      Transform.translate(
        offset: const Offset(0, -22),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (d.kota.isNotEmpty) Pill(d.kota),
                  const SizedBox(height: 8),
                  Text(d.nama,
                      style: const TextStyle(
                          fontSize: 23, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: AppColors.ink)),
                  const SizedBox(height: 5),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(Icons.location_on_outlined, size: 16, color: AppColors.muted),
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(d.alamat, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
                    ),
                  ]),
                ]),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(color: AppColors.softCoral, borderRadius: BorderRadius.circular(12)),
                child: Column(children: [
                  RatingText(Fmt.rating(d.rating), size: 16),
                  const SizedBox(height: 2),
                  Text('${d.jumlahReview} ulasan', style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
                ]),
              ),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              _InfoCepat(Icons.route_outlined, d.jarakKm == null ? '-' : Fmt.jarak(d.jarakKm), 'dari lokasimu'),
              const SizedBox(width: 9),
              _InfoCepat(Icons.schedule_rounded, 'Jam buka', d.jamBuka.isEmpty ? '-' : d.jamBuka),
              const SizedBox(width: 9),
              _InfoCepat(Icons.menu_book_outlined, modeLabel, '${d.program.length} program'),
            ]),
            const SizedBox(height: 24),
            const SectionTitle('Tentang bimbel'),
            const SizedBox(height: 8),
            Text(d.deskripsi, style: const TextStyle(color: AppColors.muted, height: 1.55, fontSize: 13.5)),
            const SizedBox(height: 12),
            if (d.kontak.trim().isNotEmpty) _Kontak(d.kontak),
            const SizedBox(height: 18),
            SectionTitle('Lokasi & arah', action: 'Lihat rute', onAction: _rute),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                height: 170,
                child: BimbelMap(
                  items: [
                    Bimbel(
                      id: d.id, nama: d.nama, alamat: d.alamat, kota: d.kota, lat: d.lat, lng: d.lng,
                      rating: d.rating, hargaMulai: 0, jenjang: const [], mode: const [], mapel: '',
                    )
                  ],
                  center: LatLng(d.lat, d.lng),
                  zoom: 15,
                  interactive: false,
                ),
              ),
            ),
            const SizedBox(height: 12),
            KompasBimbel(lat: d.lat, lng: d.lng),
            const SizedBox(height: 24),
            SectionTitle('Program tersedia', key: _programKey),
            const SizedBox(height: 12),
            if (d.program.isEmpty) const EmptyView(icon: Icons.menu_book_outlined, text: 'Belum ada program'),
            for (var i = 0; i < d.program.length; i++) _ProgramCard(detail: d, program: d.program[i], unggulan: i == 0),
            const SizedBox(height: 10),
            SectionTitle('Ulasan', action: 'Tulis ulasan', onAction: _tulisReview),
            const SizedBox(height: 12),
            if (_review.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('Belum ada ulasan.', style: TextStyle(color: AppColors.muted)),
              ),
            for (final r in _review.take(5))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Panel(
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    CircleAvatar(
                      radius: 17,
                      backgroundColor: AppColors.softBlue,
                      child: Text(r.nama.isEmpty ? '?' : r.nama[0].toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.indigo)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(r.nama, style: const TextStyle(fontWeight: FontWeight.w700))),
                          RatingText('${r.rating}', size: 12.5),
                        ]),
                        if (r.komentar.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(r.komentar, style: const TextStyle(color: AppColors.muted, fontSize: 13, height: 1.45)),
                        ],
                      ]),
                    ),
                  ]),
                ),
              ),
          ]),
        ),
      ),
    ]);
  }
}

class _TombolBulat extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color warna;
  const _TombolBulat(this.icon, this.onTap, {this.warna = AppColors.ink});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 42, height: 42, child: Icon(icon, size: 21, color: warna)),
      ),
    );
  }
}

class _InfoCepat extends StatelessWidget {
  final IconData icon;
  final String judul, sub;
  const _InfoCepat(this.icon, this.judul, this.sub);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(children: [
          Icon(icon, size: 21, color: AppColors.teal),
          const SizedBox(height: 5),
          Text(judul,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 1),
          Text(sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
        ]),
      ),
    );
  }
}

class _ProgramCard extends StatelessWidget {
  final BimbelDetail detail;
  final Program program;
  final bool unggulan;
  const _ProgramCard({required this.detail, required this.program, this.unggulan = false});

  @override
  Widget build(BuildContext context) {
    final p = program;
    final zona = AppSettings.i.zona;
    final sisa = p.jadwal.fold<int>(0, (t, j) => t + (j.sisa > 0 ? j.sisa : 0));
    final bisa = p.jadwal.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: unggulan ? AppColors.softTeal : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: unggulan ? const Color(0xFFA8DCD5) : AppColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: bisa ? () => Navigator.pushNamed(context, '/daftar', arguments: DaftarArgs(detail, p)) : null,
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Eyebrow(
                    '${p.jenjang} · ${p.mode == 'online' ? 'ONLINE' : 'OFFLINE'} · ${p.durasiMinggu} MINGGU'.toUpperCase(),
                    color: AppColors.teal,
                  ),
                ),
                if (bisa)
                  Pill(sisa > 0 ? 'Sisa $sisa kursi' : 'Penuh',
                      color: sisa > 0 ? AppColors.coralDark : AppColors.danger),
              ]),
              const SizedBox(height: 6),
              Text(p.nama, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              if (p.mapel.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(p.mapel, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
              ],
              const SizedBox(height: 8),
              for (final j in p.jadwal.take(2))
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(children: [
                    const Icon(Icons.schedule_rounded, size: 14, color: AppColors.muted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text('${j.hari}, ${TimeUtil.rentang(j.tanggalMulai, j.jamMulai, j.jamSelesai, zona)}',
                          style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                    ),
                  ]),
                ),
              const SizedBox(height: 10),
              Row(children: [
                Text(Fmt.harga(p.hargaIdr),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.indigo)),
                const Text(' / bulan', style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
                const Spacer(),
                Text(bisa ? 'Pilih' : 'Belum ada jadwal',
                    style: TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w800, color: bisa ? AppColors.teal : AppColors.muted)),
                if (bisa) const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.teal),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Nomor HP bimbel dengan tombol Telepon dan WhatsApp.
class _Kontak extends StatelessWidget {
  final String nomor;
  const _Kontak(this.nomor);

  /// '0812-5550-0101' -> '081255500101'
  String get _angka => nomor.replaceAll(RegExp(r'[^0-9+]'), '');

  /// Format internasional untuk WhatsApp: 0812... -> 62812...
  String get _wa {
    final a = _angka.replaceFirst('+', '');
    return a.startsWith('0') ? '62${a.substring(1)}' : a;
  }

  Future<void> _buka(BuildContext context, Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) showMsg(context, 'Tidak dapat membuka aplikasi', error: true);
  }

  @override
  Widget build(BuildContext context) {
    return Panel(
      shadow: false,
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      child: Row(children: [
        const IconBox(Icons.phone_outlined, size: 36, bg: AppColors.softTeal, fg: AppColors.teal),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Kontak bimbel', style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
            Text(nomor, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
          ]),
        ),
        IconButton(
          tooltip: 'Telepon',
          onPressed: () => _buka(context, Uri(scheme: 'tel', path: _angka)),
          icon: const Icon(Icons.call_rounded, color: AppColors.indigo),
        ),
        IconButton(
          tooltip: 'WhatsApp',
          onPressed: () => _buka(context, Uri.parse('https://wa.me/$_wa')),
          icon: const Icon(Icons.chat_rounded, color: AppColors.teal),
        ),
      ]),
    );
  }
}
