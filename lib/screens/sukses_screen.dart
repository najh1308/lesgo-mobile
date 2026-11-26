import 'package:flutter/material.dart';

import '../core/app_settings.dart';
import '../core/format.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import 'main_shell.dart';
import '../services/notifikasi_service.dart';

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
      backgroundColor: Colors.white, // ubah warna latar halaman ini di sini
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(24, 12, 24, 24), children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              onPressed: () => _keTab(context, 0),
              icon: const Icon(Icons.close_rounded, color: Color(0xFF1D2A44)),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: const Color(0xFF00A896),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE4F7F4), width: 10),
              ),
              child: const Icon(Icons.check_rounded, size: 44, color: Colors.white),
            ),
          ),
          const SizedBox(height: 20),
          const Center(child: Eyebrow('PENDAFTARAN BERHASIL', color: Color(0xFF00A896))),
          const SizedBox(height: 8),
          const Text('Selamat, kelasmu\nsudah siap!',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.7,
                  height: 1.2,
                  color: Color(0xFF1D2A44))),
          const SizedBox(height: 8),
          const Text('Pendaftaranmu sudah tercatat dan diamankan di riwayat terverifikasi.',
              textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF6F7B8F), height: 1.5)),
          const SizedBox(height: 24),
          ListenableBuilder(
            listenable: AppSettings.i,
            builder: (context, _) => Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE6EBF0)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Eyebrow('KELAS PERTAMA', color: Color(0xFF6F7B8F)),
                  const Spacer(),
                  Text('#GL-${p.id.toString().padLeft(5, '0')}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F4C81))),
                ]),
                const SizedBox(height: 6),
                Text(p.namaProgram,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF1D2A44))),
                const SizedBox(height: 12),
                _Baris(Icons.calendar_today_outlined, '${p.hari}, ${Fmt.tanggal(p.tanggalMulai)}'),
                _Baris(Icons.schedule_rounded,
                    TimeUtil.rentang(p.tanggalMulai, p.jamMulai, p.jamSelesai, AppSettings.i.zona)),
                _Baris(Icons.location_on_outlined, p.bimbelNama),
                const Divider(height: 22, color: Color(0xFFE6EBF0)),
                Row(children: [
                  Text('Total · ${p.metodeBayar}', style: const TextStyle(color: Color(0xFF6F7B8F), fontSize: 13)),
                  const Spacer(),
                  Text(Fmt.harga(p.totalIdr),
                      style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F4C81), fontSize: 15)),
                ]),
              ]),
            ),
          ),
                    if (NotifikasiService.didukung) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFE4F7F4), borderRadius: BorderRadius.circular(14)),
              child: const Row(children: [
                Icon(Icons.notifications_active_outlined, size: 20, color: Color(0xFF00A896)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Pengingat aktif: kamu akan diberi notifikasi 1 hari dan 1 jam sebelum setiap sesi, '
                    'bahkan saat aplikasi ditutup.',
                    style: TextStyle(fontSize: 12.5, height: 1.45, color: Color(0xFF1D2A44)),
                  ),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 26),
          PrimaryButton(label: 'Lihat aktivitas', onPressed: () => _keTab(context, 3)),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => _keTab(context, 0),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF00A896),
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
            child: const Text('Kembali ke beranda'),
          ),
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
        Icon(icon, size: 17, color: const Color(0xFF00A896)),
        const SizedBox(width: 8),
        Expanded(child: Text(teks, style: const TextStyle(fontSize: 13.5, color: Color(0xFF1D2A44)))),
      ]),
    );
  }
}
