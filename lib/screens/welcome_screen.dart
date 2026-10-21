import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import '../widgets/common.dart';

/// Halaman pembuka GeoLearn dengan tombol "Mulai".
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.indigo,
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, top + 20, 24, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Brand(light: true),
                Expanded(
                  child: Center(
                    child: SizedBox(
                      width: 250,
                      height: 250,
                      child: Stack(alignment: Alignment.center, children: [
                        Container(
                          width: 230,
                          height: 230,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withAlpha(30)),
                          ),
                        ),
                        Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withAlpha(18)),
                        ),
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(30)),
                          child: const Icon(Icons.location_on_rounded, size: 54, color: Colors.white),
                        ),
                        const Positioned(top: 18, left: 34, child: _Bulat('π', AppColors.coral, AppColors.slate)),
                        const Positioned(bottom: 30, right: 20, child: _Bulat('A+', Colors.white, AppColors.indigo)),
                        const Positioned(top: 54, right: 14, child: _Ikon(Icons.menu_book_rounded)),
                        const Positioned(bottom: 26, left: 24, child: _Ikon(Icons.school_rounded)),
                      ]),
                    ),
                  ),
                ),
              ]),
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(24, 28, 24, MediaQuery.paddingOf(context).bottom + 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Eyebrow('BELAJAR LEBIH DEKAT', color: AppColors.teal, icon: Icons.auto_awesome),
              const SizedBox(height: 10),
              const Text('Temukan bimbel terbaik\ndi sekitarmu',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.7, height: 1.2)),
              const SizedBox(height: 8),
              const Text(
                'Cari bimbel terdekat, daftar kelas, belajar bareng Tutor AI, dan asah otak lewat mini game.',
                style: TextStyle(color: AppColors.muted, height: 1.5),
              ),
              const SizedBox(height: 24),
              PrimaryButton(label: 'Mulai', onPressed: () => Navigator.pushReplacementNamed(context, '/login')),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Bulat extends StatelessWidget {
  final String teks;
  final Color bg, fg;
  const _Bulat(this.teks, this.bg, this.fg);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(teks, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: fg)),
    );
  }
}

class _Ikon extends StatelessWidget {
  final IconData icon;
  const _Ikon(this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: Colors.white.withAlpha(30), borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, size: 22, color: Colors.white),
    );
  }
}
