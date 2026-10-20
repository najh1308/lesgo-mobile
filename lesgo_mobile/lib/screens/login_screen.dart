import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../widgets/common.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _masuk() async {
    final email = _email.text.trim();
    final pass = _pass.text;
    if (email.isEmpty || pass.isEmpty) {
      showMsg(context, 'Email dan password wajib diisi', error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      await AuthService.login(email, pass);
      if (!mounted) return;
      await _tawarkanBiometrik();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } on ApiException catch (e) {
      if (mounted) showMsg(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Setelah login pertama, tawarkan login sidik jari untuk pembukaan berikutnya.
  Future<void> _tawarkanBiometrik() async {
    if (await Session.biometrikAktif() || !await BiometricService.tersedia()) return;
    if (!mounted) return;
    final ya = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Aktifkan login sidik jari?'),
        content: const Text('Lain kali kamu bisa masuk lebih cepat dengan sidik jari atau wajah.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Nanti')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Aktifkan')),
        ],
      ),
    );
    if (ya == true && await BiometricService.verifikasi('Verifikasi untuk mengaktifkan login sidik jari')) {
      await Session.setBiometrik(true);
    }
  }

  Future<void> _sidikJari() async {
    if (Session.token == null || !await Session.biometrikAktif()) {
      if (mounted) {
        showMsg(context, 'Masuk dengan email dan password dulu, lalu aktifkan sidik jari di menu Profil.');
      }
      return;
    }
    if (!await BiometricService.tersedia()) {
      if (mounted) showMsg(context, 'Perangkat ini tidak mendukung biometrik', error: true);
      return;
    }
    final ok = await BiometricService.verifikasi('Verifikasi untuk masuk ke LesGo');
    if (!ok || !mounted) return;
    try {
      await AuthService.me();
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } on ApiException catch (e) {
      if (mounted) showMsg(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SizedBox(height: 16),
            const Icon(Icons.location_on, size: 56, color: AppColors.accent),
            const Center(
              child: Text('LesGo',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.primary)),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text('Masuk ke LesGo',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.ink)),
            ),
            const SizedBox(height: 28),
            AppField(controller: _email, hint: 'Email', icon: Icons.mail_outline, keyboard: TextInputType.emailAddress),
            const SizedBox(height: 14),
            AppField(
              controller: _pass,
              hint: 'Password',
              icon: Icons.lock_outline,
              password: true,
              onSubmitted: (_) => _masuk(),
            ),
            const SizedBox(height: 20),
            PrimaryButton(label: 'Masuk', onPressed: _masuk, loading: _loading),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _sidikJari,
              icon: const Icon(Icons.fingerprint),
              label: const Text('Masuk dengan sidik jari'),
            ),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('Belum punya akun? '),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/register'),
                child: const Text('Daftar',
                    style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700)),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
