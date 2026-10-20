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
    return SafeArea(
      child: DefaultTabController(
        length: 4,
        child: Column(children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Aktivitas',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.ink)),
            ),
          ),
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Pendaftaran'),
              Tab(text: 'Jadwal'),
              Tab(text: 'Favorit'),
              Tab(text: 'Riwayat Terverifikasi'),
            ],
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
      ),
    );
  }
}

/// Pola yang sama untuk tiap tab: muat data, tampilkan, dan muat ulang saat ada perubahan.
class _DaftarAsync<T> extends StatefulWidget {
  final Future<List<T>> Function() loader;
  final Widget Function(BuildContext, T, Future<void> Function() muatUlang) item;
  final String kosong;
  final IconData ikonKosong;
  const _DaftarAsync({required this.loader, required this.item, required this.kosong, required this.ikonKosong});

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
              builder: (context, _) => ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: _data.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (c, i) => widget.item(c, _data[i], _muat),
              ),
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
      item: (context, p, muatUlang) => Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(p.bimbelNama,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
            Pill(p.status[0].toUpperCase() + p.status.substring(1), color: _warnaStatus(p.status)),
          ]),
          const SizedBox(height: 4),
          Text(p.namaProgram, style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 6),
          Text('${p.hari}, ${Fmt.tanggal(p.tanggalMulai)} · ${TimeUtil.rentang(p.tanggalMulai, p.jamMulai, p.jamSelesai, AppSettings.i.zona)}',
              style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 6),
          Text(Fmt.harga(p.totalIdr),
              style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
          if (p.status == 'aktif' || p.status == 'menunggu')
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _batal(context, p, muatUlang),
                child: const Text('Batalkan', style: TextStyle(color: AppColors.danger)),
              ),
            ),
        ]),
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
          Container(
            width: 56,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(children: [
              Text(p.hari.length > 3 ? p.hari.substring(0, 3) : p.hari,
                  style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w700)),
              Text(Fmt.tanggal(p.tanggalMulai).split(' ').first,
                  style: const TextStyle(fontSize: 22, color: AppColors.primary, fontWeight: FontWeight.w800)),
            ]),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.namaProgram, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(p.bimbelNama, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
              const SizedBox(height: 4),
              Text(TimeUtil.rentang(p.tanggalMulai, p.jamMulai, p.jamSelesai, AppSettings.i.zona)),
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
      kosong: 'Belum ada bimbel favorit.\nTandai bimbel dengan ikon bookmark.',
      ikonKosong: Icons.bookmark_border,
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
    return RefreshIndicator(
      onRefresh: _muat,
      child: ListView(padding: const EdgeInsets.all(20), children: [
        const Text(
          'Setiap pendaftaran dan pembatalan dicatat sebagai block yang saling terhubung lewat hash. '
          'Jika ada data yang diubah, rantai menjadi tidak valid.',
          style: TextStyle(color: AppColors.muted, height: 1.4),
        ),
        const SizedBox(height: 12),
        PrimaryButton(label: 'Validasi Riwayat', icon: Icons.verified_outlined, onPressed: _cek, loading: _validasi),
        if (_hasil != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: (_hasil!.valid ? AppColors.success : AppColors.danger).withAlpha(25),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: [
              Icon(_hasil!.valid ? Icons.verified : Icons.warning_amber_rounded,
                  color: _hasil!.valid ? AppColors.success : AppColors.danger),
              const SizedBox(width: 10),
              Expanded(
                child: Text('${_hasil!.pesan} (${_hasil!.totalBlock} block diperiksa)',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
        ],
        const SizedBox(height: 16),
        if (_blocks.isEmpty)
          const SizedBox(height: 240, child: EmptyView(icon: Icons.link_off, text: 'Belum ada block.\nBlock dibuat saat kamu mendaftar.')),
        for (final b in _blocks)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('Block #${b.index}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(width: 8),
                  Pill(b.event, color: b.event == 'BATAL' ? AppColors.danger : AppColors.success),
                ]),
                const SizedBox(height: 8),
                _Hash('Hash', b.hash),
                _Hash('Hash sebelumnya', b.prevHash),
                const SizedBox(height: 4),
                Text('Nonce ${b.nonce} · ${Fmt.tanggalJam(b.createdAt)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ]),
            ),
          ),
      ]),
    );
  }
}

class _Hash extends StatelessWidget {
  final String label, nilai;
  const _Hash(this.label, this.nilai);

  @override
  Widget build(BuildContext context) {
    final singkat = nilai.length > 20 ? '${nilai.substring(0, 10)}...${nilai.substring(nilai.length - 8)}' : nilai;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(children: [
        SizedBox(width: 120, child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted))),
        Text(singkat, style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
      ]),
    );
  }
}
