import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_settings.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/bimbel_service.dart';
import '../services/pendaftaran_service.dart';
import '../widgets/bimbel_card.dart';
import '../widgets/common.dart';
import 'main_shell.dart';

class AktivitasScreen extends StatelessWidget {
  const AktivitasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Builder(
          builder: (context) => PageHeader(
            title: 'Aktivitas',
            subtitle: 'Pendaftaran dan jadwal belajarmu',
            trailing: SquareIconButton(
              Icons.calendar_month_outlined,
              tooltip: 'Jadwal',
              onTap: () => DefaultTabController.of(context).animateTo(1),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(18, 16, 18, 4),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: AppColors.softGrey, borderRadius: BorderRadius.circular(12)),
          child: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelPadding: EdgeInsets.symmetric(horizontal: 14),
            tabs: [
              Tab(height: 36, text: 'Pendaftaran'),
              Tab(height: 36, text: 'Jadwal'),
              Tab(height: 36, text: 'Favorit'),
              Tab(height: 36, text: 'Terverifikasi'),
            ],
          ),
        ),
        const Expanded(
          child: TabBarView(children: [
            _PendaftaranTab(),
            _JadwalTab(),
            _FavoritTab(),
            _BlockchainTab(),
          ]),
        ),
      ]),
    );
  }
}

/// Pola yang sama untuk tiap tab: muat data, tampilkan, dan muat ulang saat ada perubahan.
class _DaftarAsync<T> extends StatefulWidget {
  final Future<List<T>> Function() loader;
  final Widget Function(BuildContext, T, Future<void> Function() muatUlang) item;
  final String kosong;
  final IconData ikonKosong;
  final Widget? Function(BuildContext, List<T>)? header;
  const _DaftarAsync({
    required this.loader,
    required this.item,
    required this.kosong,
    required this.ikonKosong,
    this.header,
  });

  @override
  State<_DaftarAsync<T>> createState() => _DaftarAsyncState<T>();
}

class _DaftarAsyncState<T> extends State<_DaftarAsync<T>> {
  List<T> _data = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _muat();
    ShellController.refresh.addListener(_muat);
  }

  @override
  void dispose() {
    ShellController.refresh.removeListener(_muat);
    super.dispose();
  }

  Future<void> _muat() async {
    if (!mounted) return;
    setState(() {
      _loading = _data.isEmpty;
      _error = null;
    });
    try {
      final d = await widget.loader();
      if (!mounted) return;
      setState(() {
        _data = d;
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ErrorView(message: _error!, onRetry: _muat);
    return RefreshIndicator(
      onRefresh: _muat,
      child: _data.isEmpty
          ? ListView(children: [
              SizedBox(height: 320, child: EmptyView(icon: widget.ikonKosong, text: widget.kosong)),
            ])
          : ListenableBuilder(
              listenable: AppSettings.i,
              builder: (context, _) {
                final atas = widget.header?.call(context, _data);
                return ListView(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
                  children: [
                    if (atas != null) ...[atas, const SizedBox(height: 22)],
                    for (final d in _data)
                      Padding(padding: const EdgeInsets.only(bottom: 14), child: widget.item(context, d, _muat)),
                  ],
                );
              },
            ),
    );
  }
}

Color _warnaStatus(String s) {
  switch (s) {
    case 'aktif':
      return AppColors.success;
    case 'batal':
      return AppColors.danger;
    case 'selesai':
      return AppColors.muted;
    default:
      return AppColors.accent;
  }
}

class _PendaftaranTab extends StatelessWidget {
  const _PendaftaranTab();

  @override
  Widget build(BuildContext context) {
    return _DaftarAsync<Pendaftaran>(
      loader: PendaftaranService.list,
      kosong: 'Belum ada pendaftaran.\nCari bimbel dan daftar program pertamamu.',
      ikonKosong: Icons.assignment_outlined,
      header: (context, data) {
        final aktif = data.where((p) => p.status == 'aktif' || p.status == 'menunggu').toList()
          ..sort((a, b) => a.tanggalMulai.compareTo(b.tanggalMulai));
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (aktif.isNotEmpty) ...[
            _KelasBerikutnya(aktif.first),
            const SizedBox(height: 22),
          ],
          const SectionTitle('Riwayat pendaftaran'),
        ]);
      },
      item: (context, p, muatUlang) => Opacity(
        opacity: p.status == 'batal' || p.status == 'selesai' ? 0.7 : 1,
        child: Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              BimbelCover(seed: p.bimbelId, width: 56, height: 56, iconSize: 26,
                  borderRadius: BorderRadius.circular(13)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Pill(p.status[0].toUpperCase() + p.status.substring(1), color: _warnaStatus(p.status)),
                  const SizedBox(height: 5),
                  Text(p.bimbelNama, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  Text('${p.jenjang} · ${p.namaProgram}',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                ]),
              ),
            ]),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(
                border: Border.symmetric(horizontal: BorderSide(color: AppColors.line)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: _Meta('Jadwal',
                      '${p.hari}, ${TimeUtil.rentang(p.tanggalMulai, p.jamMulai, p.jamSelesai, AppSettings.i.zona)}'),
                ),
                Expanded(child: _Meta('Mulai', Fmt.tanggal(p.tanggalMulai))),
                Expanded(child: _Meta('Total', Fmt.harga(p.totalIdr), warna: AppColors.indigo)),
              ]),
            ),
            Material(
              color: AppColors.softTeal,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => DefaultTabController.of(context).animateTo(3),
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Row(children: [
                    IconBox(Icons.verified_user_outlined, bg: Colors.white, fg: AppColors.teal, size: 30),
                    SizedBox(width: 9),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Tercatat di blockchain',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                        Text('Ketuk untuk melihat & memvalidasi riwayat',
                            style: TextStyle(fontSize: 11, color: AppColors.muted)),
                      ]),
                    ),
                    Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.muted),
                  ]),
                ),
              ),
            ),
            if (p.status == 'aktif' || p.status == 'menunggu')
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _batal(context, p, muatUlang),
                  child: const Text('Batalkan pendaftaran', style: TextStyle(color: AppColors.danger)),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  Future<void> _batal(BuildContext context, Pendaftaran p, Future<void> Function() muatUlang) async {
    final ya = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Batalkan pendaftaran?'),
        content: Text('Pendaftaran di ${p.bimbelNama} akan dibatalkan. Pembatalan juga dicatat di riwayat terverifikasi.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Tidak')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Ya, batalkan')),
        ],
      ),
    );
    if (ya != true) return;
    try {
      await PendaftaranService.batal(p.id);
      ShellController.bump();
      if (context.mounted) showMsg(context, 'Pendaftaran dibatalkan');
    } on ApiException catch (e) {
      if (context.mounted) showMsg(context, e.message, error: true);
    }
  }
}

class _JadwalTab extends StatelessWidget {
  const _JadwalTab();

  Future<List<Pendaftaran>> _aktif() async {
    final semua = await PendaftaranService.list();
    final aktif = semua.where((p) => p.status == 'aktif' || p.status == 'menunggu').toList();
    aktif.sort((a, b) => a.tanggalMulai.compareTo(b.tanggalMulai));
    return aktif;
  }

  @override
  Widget build(BuildContext context) {
    return _DaftarAsync<Pendaftaran>(
      loader: _aktif,
      kosong: 'Belum ada jadwal kelas.',
      ikonKosong: Icons.event_busy_outlined,
      item: (context, p, _) => Panel(
        child: Row(children: [
          _KotakTanggal(p, terang: false),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.namaProgram, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
              const SizedBox(height: 2),
              Text(p.bimbelNama, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.schedule_rounded, size: 15, color: AppColors.teal),
                const SizedBox(width: 4),
                Flexible(
                  child: Text('${p.hari} · ${TimeUtil.rentang(p.tanggalMulai, p.jamMulai, p.jamSelesai, AppSettings.i.zona)}',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _FavoritTab extends StatelessWidget {
  const _FavoritTab();

  @override
  Widget build(BuildContext context) {
    return _DaftarAsync<Bimbel>(
      loader: BimbelService.favorit,
      kosong: 'Belum ada bimbel favorit.\nTandai bimbel dengan ikon hati.',
      ikonKosong: Icons.favorite_border_rounded,
      item: (context, b, muatUlang) => BimbelCard(
        bimbel: b,
        onTap: () => Navigator.pushNamed(context, '/detail', arguments: b.id),
        onFavorit: () async {
          try {
            await BimbelService.setFavorit(b.id, false);
            ShellController.bump();
          } on ApiException catch (e) {
            if (context.mounted) showMsg(context, e.message, error: true);
          }
        },
      ),
    );
  }
}

class _BlockchainTab extends StatefulWidget {
  const _BlockchainTab();

  @override
  State<_BlockchainTab> createState() => _BlockchainTabState();
}

class _BlockchainTabState extends State<_BlockchainTab> {
  List<BlockItem> _blocks = [];
  ValidasiHasil? _hasil;
  bool _loading = true;
  bool _validasi = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _muat();
    ShellController.refresh.addListener(_muat);
  }

  @override
  void dispose() {
    ShellController.refresh.removeListener(_muat);
    super.dispose();
  }

  Future<void> _muat() async {
    if (!mounted) return;
    setState(() {
      _loading = _blocks.isEmpty;
      _error = null;
    });
    try {
      final b = await PendaftaranService.blocks();
      if (!mounted) return;
      setState(() {
        _blocks = b;
        _hasil = null;
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

  Future<void> _cek() async {
    setState(() => _validasi = true);
    try {
      final h = await PendaftaranService.validasi();
      if (mounted) setState(() => _hasil = h);
    } on ApiException catch (e) {
      if (mounted) showMsg(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _validasi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ErrorView(message: _error!, onRetry: _muat);
    final valid = _hasil?.valid;
    final warna = valid == false ? AppColors.danger : AppColors.teal;
    final idxTerbaru = _blocks.fold<int>(-1, (m, b) => b.index > m ? b.index : m);
    final blokTerbaru = _blocks.where((b) => b.index == idxTerbaru);
    final terakhir = blokTerbaru.isEmpty ? null : blokTerbaru.first.createdAt;
    return RefreshIndicator(
      onRefresh: _muat,
      child: ListView(padding: const EdgeInsets.fromLTRB(18, 14, 18, 24), children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: valid == null ? Colors.white : warna.withAlpha(26),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: valid == null ? AppColors.line : warna.withAlpha(90)),
          ),
          child: Row(children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: valid == null ? AppColors.softBlue : warna,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                valid == false ? Icons.gpp_bad_outlined : Icons.verified_user_outlined,
                size: 30,
                color: valid == null ? AppColors.indigo : Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Eyebrow('STATUS INTEGRITAS', color: AppColors.muted),
                const SizedBox(height: 3),
                Text(
                  valid == null ? 'Siap divalidasi' : _hasil!.pesan,
                  style: TextStyle(
                      fontSize: 15.5, fontWeight: FontWeight.w800, color: valid == null ? AppColors.ink : warna),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_hasil?.totalBlock ?? _blocks.length} block'
                  '${terakhir != null ? ' · terakhir ${Fmt.tanggalJam(terakhir)}' : ''}',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                ),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        PrimaryButton(
          label: valid == true ? 'Validasi ulang' : 'Validasi seluruh rantai',
          icon: Icons.verified_outlined,
          onPressed: _cek,
          loading: _validasi,
        ),
        const SizedBox(height: 20),
        if (_blocks.isEmpty)
          const SizedBox(
              height: 220,
              child: EmptyView(icon: Icons.link_off, text: 'Belum ada block.\nBlock dibuat saat kamu mendaftar.')),
        for (var i = 0; i < _blocks.length; i++) _BlockTile(_blocks[i], terbaru: _blocks[i].index == idxTerbaru, terakhir: i == _blocks.length - 1),
      ]),
    );
  }
}

/// Satu block pada garis waktu rantai. Hash disembunyikan dan baru tampil
/// saat kartu diketuk ("Lihat detail").
class _BlockTile extends StatefulWidget {
  final BlockItem b;
  final bool terbaru, terakhir;
  const _BlockTile(this.b, {required this.terbaru, required this.terakhir});

  @override
  State<_BlockTile> createState() => _BlockTileState();
}

class _BlockTileState extends State<_BlockTile> {
  bool _buka = false;

  @override
  Widget build(BuildContext context) {
    final b = widget.b;
    final terbaru = widget.terbaru;
    final batal = b.event == 'BATAL';
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 30,
          child: Column(children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: terbaru ? AppColors.teal : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.teal, width: 2),
              ),
              alignment: Alignment.center,
              child: terbaru
                  ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                  : Text('${b.index}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.teal)),
            ),
            if (!widget.terakhir) Expanded(child: Container(width: 2, color: AppColors.softTeal)),
          ]),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Panel(
              onTap: () => setState(() => _buka = !_buka),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('BLOCK #${b.index}',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: AppColors.indigo)),
                  const Spacer(),
                  Pill(terbaru ? 'Terbaru' : 'Tercatat', color: terbaru ? AppColors.teal : AppColors.muted),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  Icon(batal ? Icons.cancel_outlined : Icons.how_to_reg_outlined,
                      size: 17, color: batal ? AppColors.danger : AppColors.teal),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                        batal
                            ? 'Pembatalan pendaftaran'
                            : (b.event.toUpperCase().contains('DAFTAR') ? 'Pendaftaran baru' : b.event),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                  ),
                ]),
                const SizedBox(height: 2),
                Text(Fmt.tanggalJam(b.createdAt), style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
                if (_buka) ...[
                  const SizedBox(height: 10),
                  _Hash('HASH SAAT INI', b.hash),
                  const SizedBox(height: 6),
                  _Hash('HASH SEBELUMNYA', b.prevHash),
                  const SizedBox(height: 6),
                  Text('Nonce: ${b.nonce}', style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
                ],
                const SizedBox(height: 8),
                Row(children: [
                  Text(_buka ? 'Sembunyikan detail' : 'Lihat detail',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.teal)),
                  Icon(_buka ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      size: 18, color: AppColors.teal),
                ]),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Hash lengkap (bisa panjang, dibungkus ke baris berikutnya).
class _Hash extends StatelessWidget {
  final String label, nilai;
  const _Hash(this.label, this.nilai);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(9)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppColors.muted)),
        const SizedBox(height: 3),
        Text(nilai.isEmpty ? '-' : nilai,
            style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace', color: AppColors.ink, height: 1.35)),
      ]),
    );
  }
}

/// Kartu biru "Kelas berikutnya" di atas riwayat pendaftaran.
class _KelasBerikutnya extends StatelessWidget {
  final Pendaftaran p;
  const _KelasBerikutnya(this.p);

  @override
  Widget build(BuildContext context) {
    final jam = TimeUtil.konversi(p.tanggalMulai, p.jamMulai, AppSettings.i.zona);
    return Material(
      color: AppColors.indigo,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.pushNamed(context, '/detail', arguments: p.bimbelId),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            _KotakTanggal(p, terang: true),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Eyebrow('KELAS BERIKUTNYA · $jam'),
                const SizedBox(height: 5),
                Text(p.namaProgram,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 2),
                Text(p.bimbelNama,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Color(0xFFC2CED8))),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white),
          ]),
        ),
      ),
    );
  }
}

/// Kotak tanggal (angka besar + bulan).
class _KotakTanggal extends StatelessWidget {
  final Pendaftaran p;
  final bool terang;
  const _KotakTanggal(this.p, {required this.terang});

  @override
  Widget build(BuildContext context) {
    final bagian = Fmt.tanggal(p.tanggalMulai).split(' ');
    return Container(
      width: 54,
      height: 60,
      decoration: BoxDecoration(
        color: terang ? Colors.white : AppColors.softBlue,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(bagian.first,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.indigo, height: 1.1)),
        if (bagian.length > 1)
          Text(bagian[1].toUpperCase(),
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.indigo)),
      ]),
    );
  }
}

class _Meta extends StatelessWidget {
  final String label, nilai;
  final Color warna;
  const _Meta(this.label, this.nilai, {this.warna = AppColors.ink});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
        const SizedBox(height: 3),
        Text(nilai, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: warna)),
      ]),
    );
  }
}
