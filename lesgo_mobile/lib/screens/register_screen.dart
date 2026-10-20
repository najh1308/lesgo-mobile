import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';
import '../widgets/common.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nama = TextEditingController();
  final _email = TextEditingController();
  final _hp = TextEditingController();
  final _pass = TextEditingController();
  final _konfirmasi = TextEditingController();
  Map<String, String> _err = {};
  bool _loading = false;

  @override
  void dispose() {
    for (final c in [_nama, _email, _hp, _pass, _konfirmasi]) {
      c.dispose();
    }
    super.dispose();
  }

  bool _validasi() {
    final e = <String, String>{};
    if (_nama.text.trim().isEmpty) e['nama'] = 'Nama wajib diisi';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim())) {
      e['email'] = 'Format email tidak valid';
    }
    if (!RegExp(r'^[0-9+]{9,15}$').hasMatch(_hp.text.trim())) e['no_hp'] = 'Nomor HP tidak valid';
    if (_pass.text.length < 6) e['password'] = 'Password minimal 6 karakter';
    if (_konfirmasi.text != _pass.text) e['konfirmasi'] = 'Konfirmasi password tidak sama';
    setState(() => _err = e);
    return e.isEmpty;
  }

  Future<void> _daftar() async {
    if (!_validasi()) return;
    setState(() => _loading = true);
    try {
      await AuthService.register(
        nama: _nama.text.trim(),
        email: _email.text.trim(),
        noHp: _hp.text.trim(),
        password: _pass.text,
      );
      if (!mounted) return;
      showMsg(context, 'Akun berhasil dibuat. Silakan masuk.');
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _err = e.errors.map((k, v) => MapEntry(k, v.toString())));
      showMsg(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Buat Akun Baru',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: 6),
            const Text('Daftar untuk mulai menemukan bimbel terbaik untukmu.',
                style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 24),
            AppField(controller: _nama, hint: 'Nama', icon: Icons.person_outline, errorText: _err['nama']),
            const SizedBox(height: 12),
            AppField(
                controller: _email,
                hint: 'Email',
                icon: Icons.mail_outline,
                keyboard: TextInputType.emailAddress,
                errorText: _err['email']),
            const SizedBox(height: 12),
            AppField(
                controller: _hp,
                hint: 'Nomor HP',
                icon: Icons.phone_outlined,
                keyboard: TextInputType.phone,
                errorText: _err['no_hp']),
            const SizedBox(height: 12),
            AppField(
                controller: _pass,
                hint: 'Password',
                icon: Icons.lock_outline,
                password: true,
                errorText: _err['password']),
            const SizedBox(height: 12),
            AppField(
                controller: _konfirmasi,
                hint: 'Konfirmasi Password',
                icon: Icons.lock_outline,
                password: true,
                errorText: _err['konfirmasi']),
            const SizedBox(height: 20),
            PrimaryButton(label: 'Daftar', onPressed: _daftar, loading: _loading),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('Sudah punya akun? '),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Text('Login di sini',
                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
