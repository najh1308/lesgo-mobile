import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/session.dart';
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
  bool _bisaSidikJari = false; // token tersimpan + login sidik jari aktif

  @override
  void initState() {
    super.initState();
    _cekSidikJari();
  }

  /// Jika sebelumnya login sidik jari diaktifkan, langsung tawarkan verifikasi.
  Future<void> _cekSidikJari() async {
    await Session.load();
    final bisa = Session.token != null && await Session.biometrikAktif() && await BiometricService.tersedia();
    if (!mounted) return;
    setState(() => _bisaSidikJari = bisa);
    if (bisa) _sidikJari();
  }

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
    if (await Session.biometrikAktif() || !await BiometricService.adaYangTerdaftar()) return;
    if (!mounted) return;
    final ya = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Aktifkan login sidik jari?'),
        content: const Text('Lain kali kamu bisa masuk lebih cepat cukup dengan sidik jari.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF00A896),
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
            child: const Text('Nanti'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF00A896),
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
            child: const Text('Aktifkan'),
          ),
        ],
      ),
    );
    if (ya == true && await BiometricService.verifikasi('Tempelkan sidik jari untuk mengaktifkan login')) {
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
    final ok = await BiometricService.verifikasi('Tempelkan sidik jari untuk masuk ke GeoLearn');
    if (!mounted) return;
    if (!ok) {
      final e = BiometricService.errorTerakhir;
      if (e != null) showMsg(context, e, error: true);
      return;
    }
    try {
      await AuthService.me();
      await Session.bukaKunci();
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } on ApiException catch (e) {
      if (mounted) showMsg(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // ubah warna latar halaman ini di sini
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Align(alignment: Alignment.centerLeft, child: Brand()),
            const SizedBox(height: 40),
            const Text('Selamat datang\nkembali!',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    height: 1.2,
                    color: Color(0xFF1D2A44))),
            const SizedBox(height: 8),
            const Text('Masuk untuk lanjut belajar bersama GeoLearn.', style: TextStyle(color: Color(0xFF6F7B8F))),
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
            const SizedBox(height: 22),
            PrimaryButton(label: 'Masuk', onPressed: _masuk, loading: _loading),
            const SizedBox(height: 16),
            const Row(children: [
              Expanded(child: Divider(color: Color(0xFFE6EBF0), height: 1)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('atau', style: TextStyle(fontSize: 12, color: Color(0xFF6F7B8F))),
              ),
              Expanded(child: Divider(color: Color(0xFFE6EBF0), height: 1)),
            ]),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _sidikJari,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0F4C81),
                backgroundColor: _bisaSidikJari ? const Color(0xFFE4F7F4) : Colors.white,
                minimumSize: const Size.fromHeight(52),
                side: BorderSide(color: _bisaSidikJari ? const Color(0xFF00A896) : const Color(0xFFE6EBF0)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              icon: const Icon(Icons.fingerprint_rounded, color: Color(0xFF00A896)),
              label: const Text('Masuk dengan sidik jari'),
            ),
            const SizedBox(height: 28),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('Belum punya akun? ', style: TextStyle(color: Color(0xFF6F7B8F))),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/register'),
                child: const Text('Daftar sekarang',
                    style: TextStyle(color: Color(0xFF00A896), fontWeight: FontWeight.w800)),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
