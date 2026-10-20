import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api_client.dart';
import '../core/app_settings.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../widgets/common.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _biometrik = false;

  @override
  void initState() {
    super.initState();
    Session.biometrikAktif().then((v) {
      if (mounted) setState(() => _biometrik = v);
    });
  }

  Future<void> _ganti({String? uang, String? zona}) async {
    if (uang != null) AppSettings.i.setMataUang(uang);
    if (zona != null) AppSettings.i.setZona(zona);
    try {
      await AuthService.updateProfil(mataUang: uang, zona: zona);
    } on ApiException catch (e) {
      if (mounted) showMsg(context, e.message, error: true);
    }
  }

  Future<void> _fotoBaru() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1024);
    if (f == null) return;
    try {
      await AuthService.uploadFoto(f.path);
      if (mounted) {
        setState(() {});
        showMsg(context, 'Foto profil diperbarui');
      }
    } on ApiException catch (e) {
      if (mounted) showMsg(context, e.message, error: true);
    }
  }

  Future<void> _ubahData() async {
    final u = Session.user!;
    final nama = TextEditingController(text: u.nama);
    final hp = TextEditingController(text: u.noHp);
    final simpan = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Ubah data diri'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nama, decoration: const InputDecoration(labelText: 'Nama')),
          const SizedBox(height: 12),
          TextField(controller: hp, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Nomor HP')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Simpan')),
        ],
      ),
    );
    if (simpan != true) return;
    try {
      await AuthService.updateProfil(nama: nama.text.trim(), noHp: hp.text.trim());
      if (mounted) setState(() {});
    } on ApiException catch (e) {
      if (mounted) showMsg(context, e.message, error: true);
    }
  }

  Future<void> _ubahPassword() async {
    final lama = TextEditingController();
    final baru = TextEditingController();
    final simpan = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Ubah password'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: lama, obscureText: true, decoration: const InputDecoration(labelText: 'Password lama')),
          const SizedBox(height: 12),
          TextField(controller: baru, obscureText: true, decoration: const InputDecoration(labelText: 'Password baru')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Simpan')),
        ],
      ),
    );
    if (simpan != true) return;
    try {
      await AuthService.ubahPassword(lama.text, baru.text);
      if (mounted) showMsg(context, 'Password berhasil diubah');
    } on ApiException catch (e) {
      if (mounted) showMsg(context, e.message, error: true);
    }
  }

  Future<void> _toggleBiometrik(bool aktif) async {
    if (aktif) {
      if (!await BiometricService.tersedia()) {
        if (mounted) showMsg(context, 'Perangkat ini tidak mendukung biometrik', error: true);
        return;
      }
      final ok = await BiometricService.verifikasi('Verifikasi untuk mengaktifkan login sidik jari');
      if (!ok) return;
    }
    await Session.setBiometrik(aktif);
    if (mounted) setState(() => _biometrik = aktif);
  }

  Future<void> _logout() async {
    final ya = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Keluar dari LesGo?'),
        content: const Text('Kamu perlu masuk lagi dengan email dan password.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Keluar')),
        ],
      ),
    );
    if (ya != true) return;
    await AuthService.logout();
    if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/welcome', (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    final u = Session.user;
    if (u == null) return const SizedBox.shrink();
    return SafeArea(
      child: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('Profil', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.ink)),
        const SizedBox(height: 20),
        Center(
          child: Stack(children: [
            CircleAvatar(
              radius: 52,
              backgroundColor: AppColors.primary.withAlpha(30),
              backgroundImage: u.fotoUrl != null ? NetworkImage(u.fotoUrl!) : null,
              child: u.fotoUrl == null
                  ? Text(u.nama.isEmpty ? '?' : u.nama[0].toUpperCase(),
                      style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: AppColors.primary))
                  : null,
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: _fotoBaru,
                child: const CircleAvatar(
                  radius: 17,
                  backgroundColor: AppColors.primary,
                  child: Icon(Icons.camera_alt, size: 18, color: Colors.white),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Center(child: Text(u.nama, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
        Center(child: Text(u.email, style: const TextStyle(color: AppColors.muted))),
        Center(child: Text(u.noHp, style: const TextStyle(color: AppColors.muted))),
        const SizedBox(height: 4),
        Center(child: TextButton(onPressed: _ubahData, child: const Text('Ubah data diri'))),
        const SizedBox(height: 8),
        const SectionTitle('Pengaturan'),
        const SizedBox(height: 8),
        ListenableBuilder(
          listenable: AppSettings.i,
          builder: (context, _) {
            final s = AppSettings.i;
            return Panel(
              child: Column(children: [
                Row(children: [
                  const Icon(Icons.payments_outlined, color: AppColors.muted),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Mata uang')),
                  DropdownButton<String>(
                    value: s.mataUang,
                    underline: const SizedBox.shrink(),
                    items: [for (final m in const ['IDR', 'USD', 'EUR', 'JPY']) DropdownMenuItem(value: m, child: Text(m))],
                    onChanged: (v) => v == null ? null : _ganti(uang: v),
                  ),
                ]),
                const Divider(),
                Row(children: [
                  const Icon(Icons.public, color: AppColors.muted),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Zona waktu')),
                  DropdownButton<String>(
                    value: s.zona,
                    underline: const SizedBox.shrink(),
                    items: [for (final e in TimeUtil.zonaPilihan.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                    onChanged: (v) => v == null ? null : _ganti(zona: v),
                  ),
                ]),
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.fingerprint, color: AppColors.muted),
                  title: const Text('Login sidik jari'),
                  value: _biometrik,
                  onChanged: _toggleBiometrik,
                ),
              ]),
            );
          },
        ),
        const SizedBox(height: 16),
        Panel(
          padding: EdgeInsets.zero,
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Ubah password'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _ubahPassword,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.rate_review_outlined),
              title: const Text('Saran dan Kesan'),
              subtitle: const Text('Mata kuliah Pemrograman Aplikasi Mobile'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, '/saran'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.danger),
              title: const Text('Keluar', style: TextStyle(color: AppColors.danger)),
              onTap: _logout,
            ),
          ]),
        ),
      ]),
    );
  }
}
