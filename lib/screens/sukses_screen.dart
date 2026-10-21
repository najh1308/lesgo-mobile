import 'package:flutter/material.dart';

import '../core/app_settings.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import 'main_shell.dart';

class SuksesScreen extends StatelessWidget {
  final Pendaftaran pendaftaran;
  const SuksesScreen({super.key, required this.pendaftaran});

  void _keTab(BuildContext context, int tab) {
    ShellController.tab.value = tab;
    Navigator.popUntil(context, (r) => r.settings.name == '/home');
  }

  @override
  Widget build(BuildContext context) {
    final p = pendaftaran;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(24, 12, 24, 24), children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(onPressed: () => _keTab(context, 0), icon: const Icon(Icons.close_rounded)),
          ),
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: AppColors.teal,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.softTeal, width: 10),
              ),
              child: const Icon(Icons.check_rounded, size: 44, color: Colors.white),
            ),
          ),
          const SizedBox(height: 20),
          const Center(child: Eyebrow('PENDAFTARAN BERHASIL', color: AppColors.teal)),
          const SizedBox(height: 8),
          const Text('Selamat, kelasmu\nsudah siap!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.7, height: 1.2)),
          const SizedBox(height: 8),
          const Text('Pendaftaranmu sudah tercatat dan diamankan di riwayat terverifikasi.',
              textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, height: 1.5)),
          const SizedBox(height: 24),
          ListenableBuilder(
            listenable: AppSettings.i,
            builder: (context, _) => Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.line),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Eyebrow('KELAS PERTAMA', color: AppColors.muted),
                  const Spacer(),
                  Text('#GL-${p.id.toString().padLeft(5, '0')}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.indigo)),
                ]),
                const SizedBox(height: 6),
                Text(p.namaProgram, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                _Baris(Icons.calendar_today_outlined, '${p.hari}, ${Fmt.tanggal(p.tanggalMulai)}'),
                _Baris(Icons.schedule_rounded,
                    TimeUtil.rentang(p.tanggalMulai, p.jamMulai, p.jamSelesai, AppSettings.i.zona)),
                _Baris(Icons.location_on_outlined, p.bimbelNama),
                const Divider(height: 22),
                Row(children: [
                  Text('Total · ${p.metodeBayar}', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                  const Spacer(),
                  Text(Fmt.harga(p.totalIdr),
                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.indigo, fontSize: 15)),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 26),
          PrimaryButton(label: 'Lihat aktivitas', onPressed: () => _keTab(context, 3)),
          const SizedBox(height: 6),
          TextButton(onPressed: () => _keTab(context, 0), child: const Text('Kembali ke beranda')),
        ]),
      ),
    );
  }
}

class _Baris extends StatelessWidget {
  final IconData icon;
  final String teks;
  const _Baris(this.icon, this.teks);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Icon(icon, size: 17, color: AppColors.teal),
        const SizedBox(width: 8),
        Expanded(child: Text(teks, style: const TextStyle(fontSize: 13.5))),
      ]),
    );
  }
}
