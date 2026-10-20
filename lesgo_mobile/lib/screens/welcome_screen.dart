import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../widgets/common.dart';

/// Halaman pembuka dengan tombol "Mulai" (sesuai desain).
/// Ganti ilustrasi ikon di bawah dengan gambar dari Canva/Figma jika sudah diekspor ke assets/.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(children: [
            const Spacer(),
            const Text('LesGo',
                style: TextStyle(fontSize: 52, fontWeight: FontWeight.w800, color: AppColors.primary)),
            const SizedBox(height: 8),
            const Text('Temukan bimbel terbaik di dekatmu',
                style: TextStyle(fontSize: 17, color: AppColors.muted)),
            const SizedBox(height: 40),
            SizedBox(
              height: 220,
              child: Stack(alignment: Alignment.center, children: [
                Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(18),
                    shape: BoxShape.circle,
                  ),
                ),
                const Positioned(left: 24, bottom: 40, child: Icon(Icons.menu_book_rounded, size: 52, color: AppColors.muted)),
                const Positioned(right: 24, bottom: 40, child: Icon(Icons.edit_rounded, size: 52, color: AppColors.muted)),
                const Positioned(top: 10, child: Icon(Icons.school_rounded, size: 60, color: AppColors.muted)),
                const Icon(Icons.location_on, size: 100, color: AppColors.primary),
              ]),
            ),
            const Spacer(),
            PrimaryButton(label: 'Mulai', onPressed: () => Navigator.pushReplacementNamed(context, '/login')),
            const SizedBox(height: 32),
          ]),
        ),
      ),
    );
  }
}
