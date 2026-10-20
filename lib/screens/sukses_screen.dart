import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/app_settings.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import 'main_shell.dart';

class SuksesScreen extends StatelessWidget {
  final Pendaftaran pendaftaran;
  const SuksesScreen({super.key, required this.pendaftaran});

  @override
  Widget build(BuildContext context) {
    final p = pendaftaran;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const Spacer(),
            const CircleAvatar(
              radius: 48,
              backgroundColor: Color(0x1A16A34A),
              child: Icon(Icons.check_circle, size: 72, color: AppColors.success),
            ),
            const SizedBox(height: 18),
            const Text('Pendaftaran Berhasil!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: 6),
            const Text('Pendaftaranmu sudah tercatat dan diamankan di riwayat terverifikasi.',
                textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 22),
            ListenableBuilder(
              listenable: AppSettings.i,
              builder: (context, _) => Panel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.bimbelNama, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(p.namaProgram),
                  const Divider(height: 22),
                  Text('${p.hari}, ${Fmt.tanggal(p.tanggalMulai)}'),
                  Text(TimeUtil.rentang(p.tanggalMulai, p.jamMulai, p.jamSelesai, AppSettings.i.zona)),
                  const SizedBox(height: 8),
                  Text('Total ${Fmt.harga(p.totalIdr)} · ${p.metodeBayar}',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
                ]),
              ),
            ),
            const Spacer(),
            PrimaryButton(
              label: 'Lihat Aktivitas',
              onPressed: () {
                ShellController.tab.value = 3;
                Navigator.popUntil(context, (r) => r.settings.name == '/home');
              },
            ),
          ]),
        ),
      ),
    );
  }
}
