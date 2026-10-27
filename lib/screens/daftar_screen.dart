import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_settings.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/pendaftaran_service.dart';
import '../widgets/common.dart';
import 'main_shell.dart';

class DaftarArgs {
  final BimbelDetail detail;
  final Program program;
  const DaftarArgs(this.detail, this.program);
}

/// Pilih jadwal, lihat harga dan jam dalam mata uang/zona waktu pilihan, lalu konfirmasi.
class DaftarScreen extends StatefulWidget {
  final BimbelDetail detail;
  final Program program;
  const DaftarScreen({super.key, required this.detail, required this.program});

  @override
  State<DaftarScreen> createState() => _DaftarScreenState();
}

class _DaftarScreenState extends State<DaftarScreen> {
  Jadwal? _jadwal;
  DateTime? _mulai; // tanggal mulai kelas yang dipilih pengguna
  String _metode = 'transfer';
  bool _loading = false;

  /// Nomor hari (Senin=1 ... Minggu=7) dari nama hari jadwal; null jika tidak dikenali.
  static int? _nomorHari(String hari) {
    final h = hari.toLowerCase();
    if (h.contains('senin')) return DateTime.monday;
    if (h.contains('selasa')) return DateTime.tuesday;
    if (h.contains('rabu')) return DateTime.wednesday;
    if (h.contains('kamis')) return DateTime.thursday;
    if (h.contains('jum')) return DateTime.friday;
    if (h.contains('sabtu')) return DateTime.saturday;
    if (h.contains('minggu') || h.contains('ahad')) return DateTime.sunday;
    return null;
  }

  static DateTime _besok() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day + 1);
  }

  static bool _cocokHari(Jadwal j, DateTime d) {
    final w = _nomorHari(j.hari);
    return w == null || d.weekday == w;
  }

  /// Tanggal terdekat (mulai besok) yang jatuh pada hari kelas [j].
  static DateTime _tanggalTerdekat(Jadwal j) {
    var d = _besok();
    final w = _nomorHari(j.hari);
    if (w == null) return d;
    while (d.weekday != w) {
      d = DateTime(d.year, d.month, d.day + 1);
    }
    return d;
  }

  void _pilihJadwal(Jadwal j) {
    setState(() {
      _jadwal = j;
      // Tanggal yang sudah dipilih tetap dipakai jika hari kelasnya sama.
      if (_mulai == null || !_cocokHari(j, _mulai!))
        _mulai = _tanggalTerdekat(j);
    });
  }

  /// Pengguna memilih sendiri kapan kelas dimulai (hari mengikuti jadwal yang dipilih).
  Future<void> _pilihTanggal() async {
    final j = _jadwal;
    if (j == null) return;
    final awal = _besok();
    final w = _nomorHari(j.hari);
    final dipilih = await showDatePicker(
      context: context,
      initialDate: (_mulai != null && !_mulai!.isBefore(awal))
          ? _mulai!
          : _tanggalTerdekat(j),
      firstDate: awal,
      lastDate: DateTime(awal.year + 1, awal.month, awal.day),
      selectableDayPredicate: (d) => _cocokHari(j, d),
      helpText: w == null
          ? 'Pilih tanggal mulai'
          : 'Pilih tanggal mulai (kelas hari ${j.hari})',
    );
    if (dipilih != null && mounted) setState(() => _mulai = dipilih);
  }

  Future<void> _simpanPreferensi({String? uang, String? zona}) async {
    try {
      await AuthService.updateProfil(mataUang: uang, zona: zona);
    } catch (_) {
      // Preferensi tetap berlaku di layar walau gagal disimpan ke server.
    }
  }

  Future<void> _konfirmasi() async {
    if (_jadwal == null || _mulai == null) {
      showMsg(
        context,
        'Pilih jadwal dan tanggal mulai terlebih dahulu',
        error: true,
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final p = await PendaftaranService.daftar(
        programId: widget.program.id,
        jadwalId: _jadwal!.id,
        metodeBayar: _metode,
        tanggalMulai: _mulai!,
      );
      ShellController.bump();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/sukses', arguments: p);
    } on ApiException catch (e) {
      if (mounted) showMsg(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static const _metodeOpsi = [
    ('transfer', 'Transfer bank', Icons.account_balance_outlined),
    ('e-wallet', 'E-wallet', Icons.account_balance_wallet_outlined),
    ('tunai', 'Tunai di tempat', Icons.payments_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final p = widget.program;
    return Scaffold(
      appBar: AppBar(title: const Text('Konfirmasi pendaftaran')),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
            child: ListenableBuilder(
              listenable: AppSettings.i,
              builder: (context, _) => PrimaryButton(
                label: _jadwal == null
                    ? 'Pilih jadwal dulu'
                    : 'Daftar · ${Fmt.harga(p.hargaIdr)}',
                icon: Icons.lock_outline_rounded,
                onPressed: _konfirmasi,
                loading: _loading,
              ),
            ),
          ),
        ),
      ),
      body: ListenableBuilder(
        listenable: AppSettings.i,
        builder: (context, _) {
          final s = AppSettings.i;
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
            children: [
              _Langkah(sekarang: _jadwal == null ? 1 : 2),
              const SizedBox(height: 18),
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        BimbelCover(
                          seed: widget.detail.id,
                          width: 54,
                          height: 54,
                          iconSize: 24,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.detail.nama,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                p.nama,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    _Baris('Jenjang & mapel', '${p.jenjang} · ${p.mapel}'),
                    _Baris('Mode', p.mode == 'online' ? 'Online' : 'Offline'),
                    _Baris('Durasi', '${p.durasiMinggu} minggu'),
                    if (_jadwal != null && _mulai != null)
                      _Baris(
                        'Mulai kelas',
                        '${_jadwal!.hari}, ${Fmt.tanggal(Fmt.iso(_mulai!))}',
                      ),
                    _Baris(
                      'Zona waktu',
                      TimeUtil.zonaPilihan[s.zona] ?? s.zona,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: s.zona,
                      decoration: const InputDecoration(
                        labelText: 'Zona waktu',
                      ),
                      items: [
                        for (final e in TimeUtil.zonaPilihan.entries)
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        s.setZona(v);
                        _simpanPreferensi(zona: v);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: s.mataUang,
                      decoration: const InputDecoration(labelText: 'Mata uang'),
                      items: [
                        for (final m in const ['IDR', 'USD', 'EUR', 'JPY'])
                          DropdownMenuItem(value: m, child: Text(m)),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        s.setMataUang(v);
                        _simpanPreferensi(uang: v);
                      },
                    ),
                  ),
                ],
              ),
              if (s.mataUang != 'IDR')
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Kurs ${s.kursTanggal != null ? 'per ${Fmt.tanggal(s.kursTanggal!)}' : '(perkiraan)'}'
                    ' · sumber: ${s.kursSumber}. Pembayaran tetap dalam rupiah.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              const SizedBox(height: 22),
              const SectionTitle('Pilih jadwal'),
              const SizedBox(height: 12),
              for (final j in p.jadwal) _jadwalTile(j, s.zona),
              if (_jadwal != null && _mulai != null) ...[
                const SizedBox(height: 8),
                const SectionTitle('Kapan mulai?'),
                const SizedBox(height: 12),
                _kartuTanggal(p),
              ],
              const SizedBox(height: 14),
              const SectionTitle('Metode pembayaran'),
              const SizedBox(height: 12),
              for (final m in _metodeOpsi) _metodeTile(m.$1, m.$2, m.$3),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.softBlue,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _Baris('Biaya program', Fmt.harga(p.hargaIdr)),
                    const Divider(height: 20),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Total pembayaran',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Text(
                          Fmt.harga(p.hargaIdr),
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: AppColors.indigo,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    size: 18,
                    color: AppColors.teal,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pendaftaranmu akan dicatat di riwayat terverifikasi (blockchain lokal GeoLearn).',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _metodeTile(String kode, String label, IconData icon) {
    final dipilih = _metode == kode;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: dipilih ? AppColors.softTeal : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: dipilih ? AppColors.teal : AppColors.line,
            width: dipilih ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => _metode = kode),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                IconBox(
                  icon,
                  size: 36,
                  bg: dipilih ? Colors.white : AppColors.softBlue,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                _Centang(dipilih),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Kartu tanggal mulai: ketuk untuk membuka kalender dan mengganti tanggal.
  Widget _kartuTanggal(Program p) {
    final j = _jadwal!;
    final mulai = _mulai!;
    final sesi = p.durasiMinggu < 1 ? 1 : p.durasiMinggu;
    final terakhir = DateTime(
      mulai.year,
      mulai.month,
      mulai.day + 7 * (sesi - 1),
    );
    return Material(
      color: AppColors.softTeal,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.teal, width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _pilihTanggal,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const IconBox(
                Icons.event_rounded,
                size: 42,
                bg: Colors.white,
                fg: AppColors.teal,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mulai kelas',
                      style: TextStyle(fontSize: 11.5, color: AppColors.muted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${j.hari}, ${Fmt.tanggal(Fmt.iso(mulai))}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$sesi pertemuan mingguan · sesi terakhir ${Fmt.tanggal(Fmt.iso(terakhir))}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.muted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Ubah',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.teal,
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.teal,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _jadwalTile(Jadwal j, String zona) {
    final penuh = j.sisa <= 0;
    final dipilih = _jadwal?.id == j.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Opacity(
        opacity: penuh ? 0.5 : 1,
        child: Material(
          color: dipilih ? AppColors.softTeal : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: dipilih ? AppColors.teal : AppColors.line,
              width: dipilih ? 1.5 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: penuh ? null : () => _pilihJadwal(j),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  _Centang(dipilih),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Setiap ${j.hari}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          TimeUtil.rentang(
                            dipilih && _mulai != null
                                ? Fmt.iso(_mulai!)
                                : j.tanggalMulai,
                            j.jamMulai,
                            j.jamSelesai,
                            zona,
                          ),
                          style: const TextStyle(fontSize: 13),
                        ),
                        Text(
                          'Jam asli: ${j.jamMulai} - ${j.jamSelesai} WIB',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Pill(
                    penuh ? 'Penuh' : 'Sisa ${j.sisa}',
                    color: penuh ? AppColors.danger : AppColors.teal,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Centang extends StatelessWidget {
  final bool aktif;
  const _Centang(this.aktif);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: aktif ? AppColors.teal : Colors.white,
        border: Border.all(
          color: aktif ? AppColors.teal : AppColors.line,
          width: 2,
        ),
      ),
      child: aktif
          ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
          : null,
    );
  }
}

class _Baris extends StatelessWidget {
  final String label, nilai;
  const _Baris(this.label, this.nilai);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              nilai,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Penanda langkah: 1 pilih jadwal, 2 pembayaran, 3 selesai.
class _Langkah extends StatelessWidget {
  final int sekarang;
  const _Langkah({required this.sekarang});

  @override
  Widget build(BuildContext context) {
    const label = ['Jadwal', 'Pembayaran', 'Selesai'];
    return Row(
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                color: i < sekarang ? AppColors.teal : AppColors.line,
              ),
            ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < sekarang - 1
                      ? AppColors.teal
                      : (i == sekarang - 1 ? AppColors.indigo : Colors.white),
                  border: Border.all(
                    color: i <= sekarang - 1
                        ? Colors.transparent
                        : AppColors.line,
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: i < sekarang - 1
                    ? const Icon(
                        Icons.check_rounded,
                        size: 15,
                        color: Colors.white,
                      )
                    : Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: i == sekarang - 1
                              ? Colors.white
                              : AppColors.muted,
                        ),
                      ),
              ),
              const SizedBox(height: 4),
              Text(
                label[i],
                style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
