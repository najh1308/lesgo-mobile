import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../widgets/common.dart';

/// Tab Belajar: Tutor AI (LLM) dan mini game Hitung Cepat.
class BelajarScreen extends StatelessWidget {
  const BelajarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('Belajar',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.ink)),
        const SizedBox(height: 4),
        const Text('Teman belajarmu di LesGo', style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 20),
        _Kartu(
          icon: Icons.smart_toy_outlined,
          warna: AppColors.primary,
          judul: 'Tutor AI',
          label: 'AI',
          teks: 'Tanya soal dan dapatkan penjelasan langkah demi langkah.',
          onTap: () => Navigator.pushNamed(context, '/tutor'),
        ),
        const SizedBox(height: 14),
        _Kartu(
          icon: Icons.calculate_outlined,
          warna: AppColors.accent,
          judul: 'Hitung Cepat',
          label: 'Game',
          teks: 'Benar atau salah? Jawab dengan memiringkan HP. Ada papan peringkat.',
          onTap: () => Navigator.pushNamed(context, '/game'),
        ),
      ]),
    );
  }
}

class _Kartu extends StatelessWidget {
  final IconData icon;
  final Color warna;
  final String judul, teks, label;
  final VoidCallback onTap;
  const _Kartu({
    required this.icon,
    required this.warna,
    required this.judul,
    required this.teks,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Panel(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: Row(children: [
        CircleAvatar(radius: 30, backgroundColor: warna.withAlpha(30), child: Icon(icon, size: 30, color: warna)),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(judul, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              Pill(label, color: warna),
            ]),
            const SizedBox(height: 4),
            Text(teks, style: const TextStyle(color: AppColors.muted)),
          ]),
        ),
        const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
      ]),
    );
  }
}
