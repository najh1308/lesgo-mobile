import 'package:flutter/material.dart';

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
    try {
      await AuthService.me(); // memastikan token masih berlaku
      if (await Session.biometrikAktif() && await BiometricService.tersedia()) {
        final ok = await BiometricService.verifikasi('Verifikasi untuk masuk ke LesGo');
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
    return const Scaffold(
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.location_on, size: 72, color: AppColors.accent),
          SizedBox(height: 8),
          Text('LesGo',
              style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: AppColors.primary)),
          SizedBox(height: 24),
          CircularProgressIndicator(),
        ]),
      ),
    );
  }
}
