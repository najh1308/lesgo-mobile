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
  String _metode = 'transfer';
  bool _loading = false;

  Future<void> _simpanPreferensi({String? uang, String? zona}) async {
    try {
      await AuthService.updateProfil(mataUang: uang, zona: zona);
    } catch (_) {
      // Preferensi tetap berlaku di layar walau gagal disimpan ke server.
    }
  }

  Future<void> _konfirmasi() async {
    if (_jadwal == null) {
      showMsg(context, 'Pilih jadwal terlebih dahulu', error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      final p = await PendaftaranService.daftar(
        programId: widget.program.id,
        jadwalId: _jadwal!.id,
        metodeBayar: _metode,
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

  @override
  Widget build(BuildContext context) {
    final p = widget.program;
    return Scaffold(
      appBar: AppBar(title: const Text('Pilih Jadwal dan Daftar')),
      body: ListenableBuilder(
        listenable: AppSettings.i,
        builder: (context, _) {
          final s = AppSettings.i;
          return ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 28), children: [
            Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.detail.nama, style: const TextStyle(color: AppColors.muted)),
                const SizedBox(height: 4),
                Text(p.nama, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('${p.jenjang} · ${p.mapel} · ${p.mode == 'online' ? 'Online' : 'Offline'} · ${p.durasiMinggu} minggu',
                    style: const TextStyle(color: AppColors.muted)),
              ]),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: s.zona,
                  decoration: const InputDecoration(labelText: 'Zona waktu'),
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
                  value: s.mataUang,
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
            ]),
            if (s.mataUang != 'IDR')
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Kurs ${s.kursTanggal != null ? 'per ${Fmt.tanggal(s.kursTanggal!)}' : '(perkiraan)'}'
                  ' · sumber: ${s.kursSumber}. Pembayaran tetap dalam rupiah.',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ),
            const SizedBox(height: 18),
            const SectionTitle('Pilih jadwal'),
            const SizedBox(height: 8),
            for (final j in p.jadwal) _jadwalTile(j, s.zona),
            const SizedBox(height: 14),
            const SectionTitle('Metode pembayaran'),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              for (final m in const {'transfer': 'Transfer', 'e-wallet': 'E-wallet', 'tunai': 'Tunai'}.entries)
                ChoiceChip(
                  label: Text(m.value),
                  selected: _metode == m.key,
                  onSelected: (_) => setState(() => _metode = m.key),
                ),
            ]),
            const SizedBox(height: 18),
            Panel(
              child: Row(children: [
                const Expanded(child: Text('Total', style: TextStyle(fontWeight: FontWeight.w600))),
                Text(Fmt.harga(p.hargaIdr),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primary)),
              ]),
            ),
            const SizedBox(height: 16),
            PrimaryButton(label: 'Konfirmasi Pendaftaran', onPressed: _konfirmasi, loading: _loading),
          ]);
        },
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
          color: dipilih ? AppColors.primary.withAlpha(20) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: penuh ? null : () => setState(() => _jadwal = j),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: dipilih ? AppColors.primary : AppColors.line, width: dipilih ? 1.6 : 1),
              ),
              child: Row(children: [
                Icon(dipilih ? Icons.check_circle : Icons.circle_outlined,
                    color: dipilih ? AppColors.primary : AppColors.muted),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${j.hari}, ${Fmt.tanggal(j.tanggalMulai)}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(TimeUtil.rentang(j.tanggalMulai, j.jamMulai, j.jamSelesai, zona)),
                    Text('Jam asli: ${j.jamMulai} - ${j.jamSelesai} WIB',
                        style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ]),
                ),
                Pill(penuh ? 'Penuh' : 'Sisa ${j.sisa}', color: penuh ? AppColors.danger : AppColors.success),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
