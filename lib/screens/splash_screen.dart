import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api_client.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../services/kurs_service.dart';
import '../widgets/common.dart';

/// Cek session saat aplikasi dibuka: belum login ke Welcome, sudah login ke Beranda
/// (dengan verifikasi biometrik jika diaktifkan).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _mulai();
  }

  Future<void> _mulai() async {
    setState(() => _error = null);
    await Session.load();
    KursService.muat(); // tidak ditunggu, jalan di latar belakang
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    if (Session.token == null) {
      Navigator.pushReplacementNamed(context, '/welcome');
      return;
    }
    if (await Session.terkunci()) {
      // Sudah "keluar" dengan login sidik jari aktif: masuk lagi lewat halaman login.
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    try {
      await AuthService.me(); // memastikan token masih berlaku
      if (await Session.biometrikAktif() && await BiometricService.tersedia()) {
        final ok = await BiometricService.verifikasi('Tempelkan sidik jari untuk masuk ke GeoLearn');
        if (!mounted) return;
        if (!ok) {
          Navigator.pushReplacementNamed(context, '/login');
          return;
        }
      }
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.status == 401) return; // ApiClient sudah mengarahkan ke halaman login
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(body: ErrorView(message: _error!, onRetry: _mulai));
    }
    return const AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.indigo,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            BrandMark(light: true, size: 84),
            SizedBox(height: 18),
            Text('GeoLearn',
                style: TextStyle(fontSize: 38, fontWeight: FontWeight.w800, letterSpacing: -1, color: Colors.white)),
            SizedBox(height: 6),
            Text('Belajar lebih dekat', style: TextStyle(fontSize: 15, color: Color(0xFFB9CAD9))),
            SizedBox(height: 36),
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.6, color: AppColors.teal),
            ),
          ]),
        ),
      ),
    );
  }
}
