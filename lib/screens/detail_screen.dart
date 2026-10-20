import 'package:flutter/material.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Bimbel'),
        actions: [
          if (_d != null)
            IconButton(
              onPressed: _favorit,
              icon: Icon(_d!.isFavorit ? Icons.bookmark : Icons.bookmark_border,
                  color: _d!.isFavorit ? AppColors.primary : AppColors.muted),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorView(message: _error!, onRetry: _muat)
              : ListenableBuilder(listenable: AppSettings.i, builder: (c, _) => _isi(_d!)),
    );
  }

  Widget _isi(BimbelDetail d) {
    return ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 28), children: [
      Container(
        height: 120,
        decoration: BoxDecoration(
          color: AppColors.primary.withAlpha(20),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Center(child: Icon(Icons.school_rounded, size: 64, color: AppColors.primary)),
      ),
      const SizedBox(height: 14),
      Text(d.nama, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.ink)),
      const SizedBox(height: 6),
      Wrap(spacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.star_rounded, color: AppColors.accent, size: 20),
          Text(' ${Fmt.rating(d.rating)} (${d.jumlahReview} review)'),
        ]),
        if (d.jarakKm != null)
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.location_on, color: AppColors.muted, size: 18),
            Text(Fmt.jarak(d.jarakKm)),
          ]),
      ]),
      const SizedBox(height: 12),
      Text(d.deskripsi, style: const TextStyle(color: AppColors.muted, height: 1.4)),
      const SizedBox(height: 14),
      _Info(Icons.place_outlined, '${d.alamat}, ${d.kota}'),
      _Info(Icons.access_time, d.jamBuka),
      _Info(Icons.phone_outlined, d.kontak),
      const SizedBox(height: 10),
      ClipRRect(
        borderRadius: BorderRadius.circular(16),
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
      const SizedBox(height: 10),
      OutlinedButton.icon(onPressed: _rute, icon: const Icon(Icons.directions), label: const Text('Lihat Rute')),
      const SizedBox(height: 12),
      KompasBimbel(lat: d.lat, lng: d.lng),
      const SizedBox(height: 22),
      const SectionTitle('Program'),
      const SizedBox(height: 8),
      if (d.program.isEmpty) const EmptyView(icon: Icons.menu_book_outlined, text: 'Belum ada program'),
      for (final p in d.program) _ProgramCard(detail: d, program: p),
      const SizedBox(height: 14),
      SectionTitle('Review', trailing: TextButton(onPressed: _tulisReview, child: const Text('Tulis review'))),
      if (_review.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text('Belum ada review.', style: TextStyle(color: AppColors.muted)),
        ),
      for (final r in _review.take(5))
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(r.nama, style: const TextStyle(fontWeight: FontWeight.w700))),
                const Icon(Icons.star_rounded, color: AppColors.accent, size: 18),
                Text(' ${r.rating}'),
              ]),
              if (r.komentar.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(r.komentar, style: const TextStyle(color: AppColors.muted)),
              ],
            ]),
          ),
        ),
    ]);
  }
}

class _Info extends StatelessWidget {
  final IconData icon;
  final String teks;
  const _Info(this.icon, this.teks);

  @override
  Widget build(BuildContext context) {
    if (teks.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: AppColors.muted),
        const SizedBox(width: 8),
        Expanded(child: Text(teks)),
      ]),
    );
  }
}

class _ProgramCard extends StatelessWidget {
  final BimbelDetail detail;
  final Program program;
  const _ProgramCard({required this.detail, required this.program});

  @override
  Widget build(BuildContext context) {
    final p = program;
    final zona = AppSettings.i.zona;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p.nama, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 4, children: [
            Pill(p.jenjang),
            Pill(p.mode == 'online' ? 'Online' : 'Offline',
                color: p.mode == 'online' ? AppColors.success : AppColors.accent),
            Pill('${p.durasiMinggu} minggu', color: AppColors.muted),
          ]),
          const SizedBox(height: 6),
          Text(p.mapel, style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 8),
          for (final j in p.jadwal.take(2))
            Text('${j.hari}, ${TimeUtil.rentang(j.tanggalMulai, j.jamMulai, j.jamSelesai, zona)}',
                style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: Text('${Fmt.harga(p.hargaIdr)}/bulan',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.primary)),
            ),
            SizedBox(
              width: 140,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(42)),
                onPressed: p.jadwal.isEmpty
                    ? null
                    : () => Navigator.pushNamed(context, '/daftar', arguments: DaftarArgs(detail, p)),
                child: const Text('Pilih Program'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
