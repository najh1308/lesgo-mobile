import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api_client.dart';
import '../core/app_settings.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';
import '../services/bimbel_service.dart';
import '../services/biometric_service.dart';
import '../services/game_service.dart';
import '../services/pendaftaran_service.dart';
import '../widgets/common.dart';
import 'main_shell.dart';
import '../core/personalisasi.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _biometrik = false;
  int? _kelasAktif, _favorit, _skor;

  @override
  void initState() {
    super.initState();
    Session.biometrikAktif().then((v) {
      if (mounted) setState(() => _biometrik = v);
    });
    _muatStatistik();
    ShellController.refresh.addListener(_muatStatistik);
  }

  @override
  void dispose() {
    ShellController.refresh.removeListener(_muatStatistik);
    super.dispose();
  }

  /// Angka ringkas di kartu statistik. Kalau gagal dimuat, tampil "-".
  Future<void> _muatStatistik() async {
    try {
      final p = await PendaftaranService.list();
      if (mounted) setState(() => _kelasAktif = p.where((e) => e.status == 'aktif' || e.status == 'menunggu').length);
    } catch (_) {}
    try {
      final f = await BimbelService.favorit();
      if (mounted) setState(() => _favorit = f.length);
    } catch (_) {}
    try {
      final s = await GameService.skorTerbaikLokal();
      if (mounted) setState(() => _skor = s);
    } catch (_) {}
  }

  Future<void> _pilihSheet(String judul, Map<String, String> opsi, String sekarang, ValueChanged<String> onPilih) async {
    final v = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(18, 0, 18, 18), children: [
          Text(judul, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          for (final e in opsi.entries)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(e.value, style: const TextStyle(fontWeight: FontWeight.w600)),
              trailing: e.key == sekarang ? const Icon(Icons.check_circle_rounded, color: AppColors.teal) : null,
              onTap: () => Navigator.pop(c, e.key),
            ),
        ]),
      ),
    );
    if (v != null) onPilih(v);
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
    // Diperkecil agar muat disimpan di database (sekitar 20-60 KB).
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 400, maxHeight: 400);
    if (f == null) return;
    try {
      await AuthService.uploadFoto(await f.readAsBytes());
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
      if (!await BiometricService.adaYangTerdaftar()) {
        if (mounted) {
          showMsg(context, 'Belum ada sidik jari terdaftar. Tambahkan dulu di Pengaturan HP > Keamanan.', error: true);
        }
        return;
      }
      final ok = await BiometricService.verifikasi('Tempelkan sidik jari untuk mengaktifkan login');
      if (!ok) {
        final e = BiometricService.errorTerakhir;
        if (e != null && mounted) showMsg(context, e, error: true);
        return;
      }
    }
    await Session.setBiometrik(aktif);
    if (!mounted) return;
    setState(() => _biometrik = aktif);
    showMsg(context, aktif
        ? 'Login sidik jari aktif. Saat keluar, kamu bisa masuk lagi cukup dengan sidik jari.'
        : 'Login sidik jari dinonaktifkan');
  }

  Future<void> _logout() async {
    final ya = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Keluar dari GeoLearn?'),
        content: Text(_biometrik
            ? 'Kamu bisa masuk lagi cukup dengan sidik jari.'
            : 'Kamu perlu masuk lagi dengan email dan password.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Keluar')),
        ],
      ),
    );
    if (ya != true) return;
    await AuthService.logout();
    if (mounted) Navigator.pushNamedAndRemoveUntil(context, _biometrik ? '/login' : '/welcome', (r) => false);
  }

  static const _namaUang = {
    'IDR': 'IDR (Rp) · Rupiah',
    'USD': 'USD (\$) · Dolar AS',
    'EUR': 'EUR (€) · Euro',
    'JPY': 'JPY (¥) · Yen',
  };

  @override
  Widget build(BuildContext context) {
    final u = Session.user;
    if (u == null) return const SizedBox.shrink();
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ListView(padding: EdgeInsets.zero, children: [
        _header(context, u.nama, u.email, u.noHp, u.foto),
        Transform.translate(
          offset: const Offset(0, -26),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Container(
              height: 74,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: kShadow),
              child: Row(children: [
                _Stat('${_kelasAktif ?? '-'}', 'Kelas aktif', () => ShellController.tab.value = 3),
                const VerticalDivider(width: 1, indent: 18, endIndent: 18),
                _Stat('${_favorit ?? '-'}', 'Favorit', () => ShellController.tab.value = 3),
                const VerticalDivider(width: 1, indent: 18, endIndent: 18),
                _Stat('${_skor ?? '-'}', 'Skor terbaik', () => Navigator.pushNamed(context, '/game')),
              ]),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
          child: ListenableBuilder(
            listenable: Listenable.merge([AppSettings.i, Personalisasi.i]),
            builder: (context, _) {
              final s = AppSettings.i;
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SectionTitle('Pengaturan akun'),
                const SizedBox(height: 13),
                _MenuGrup(children: [
                _Menu(Icons.tune_rounded, 'Personalisasi',
                      Personalisasi.i.aktif ? Personalisasi.i.ringkasan : 'Atur peran, mapel, dan estimasi biaya',
                      onTap: () => Navigator.pushNamed(context, '/personalisasi')),
                  _Menu(Icons.person_outline_rounded, 'Data diri', 'Nama dan nomor HP', onTap: _ubahData),
                  _Menu(Icons.lock_outline_rounded, 'Ubah password', 'Ganti kata sandi akun', onTap: _ubahPassword),
                  _Menu(Icons.fingerprint_rounded, 'Login sidik jari', _biometrik ? 'Aktif' : 'Nonaktif',
                      trailing: Switch(value: _biometrik, onChanged: _toggleBiometrik),
                      onTap: () => _toggleBiometrik(!_biometrik)),
                ]),
                const SizedBox(height: 16),
                const SectionTitle('Preferensi'),
                const SizedBox(height: 13),
                _MenuGrup(children: [
                  _Menu(Icons.account_balance_wallet_outlined, 'Mata uang', _namaUang[s.mataUang] ?? s.mataUang,
                      onTap: () => _pilihSheet('Mata uang', _namaUang, s.mataUang, (v) => _ganti(uang: v))),
                  _Menu(Icons.public_rounded, 'Zona waktu', TimeUtil.zonaPilihan[s.zona] ?? s.zona,
                      onTap: () => _pilihSheet('Zona waktu', TimeUtil.zonaPilihan, s.zona, (v) => _ganti(zona: v))),
                  _Menu(Icons.rate_review_outlined, 'Saran & kesan', 'Mata kuliah Pemrograman Aplikasi Mobile',
                      onTap: () => Navigator.pushNamed(context, '/saran')),
                ]),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: _logout,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: Color(0xFFF6C9CB)),
                  ),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Keluar dari akun'),
                ),
                const SizedBox(height: 14),
                const Center(
                  child: Text('GeoLearn v1.0', style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
                ),
              ]);
            },
          ),
        ),
      ]),
    );
  }

  Widget _header(BuildContext context, String nama, String email, String noHp, ImageProvider? foto) {
    return Container(
      padding: EdgeInsets.fromLTRB(18, MediaQuery.paddingOf(context).top + 14, 18, 48),
      color: AppColors.indigo,
      child: Column(children: [
        const Row(children: [
          Brand(light: true, size: 16),
          Expanded(
            child: Text('Profil',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
          SizedBox(width: 110), // penyeimbang lebar logo agar judul tetap di tengah
        ]),
        const SizedBox(height: 18),
        Stack(clipBehavior: Clip.none, children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.coral,
              border: Border.all(color: Colors.white.withAlpha(51), width: 4),
              image: foto == null ? null : DecorationImage(image: foto, fit: BoxFit.cover),
            ),
            alignment: Alignment.center,
            child: foto != null
                ? null
                : Text(_inisial(nama),
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.slate)),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: GestureDetector(
              onTap: _fotoBaru,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.teal,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.indigo, width: 2),
                ),
                child: const Icon(Icons.camera_alt_rounded, size: 15, color: Colors.white),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Text(nama, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 3),
        Text(email, style: const TextStyle(fontSize: 12.5, color: Color(0xFFCBD9E5))),
        if (noHp.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: Colors.white.withAlpha(26), borderRadius: BorderRadius.circular(12)),
            child: Text(noHp, style: const TextStyle(fontSize: 11.5, color: Colors.white)),
          ),
        ],
      ]),
    );
  }

  String _inisial(String nama) {
    final k = nama.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (k.isEmpty) return '?';
    return (k.first[0] + (k.length > 1 ? k[1][0] : '')).toUpperCase();
  }
}

class _Stat extends StatelessWidget {
  final String angka, label;
  final VoidCallback onTap;
  const _Stat(this.angka, this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(angka, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.indigo)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        ]),
      ),
    );
  }
}

class _MenuGrup extends StatelessWidget {
  final List<Widget> children;
  const _MenuGrup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(17),
        side: const BorderSide(color: AppColors.line),
      ),
      child: Column(children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          children[i],
        ],
      ]),
    );
  }
}

class _Menu extends StatelessWidget {
  final IconData icon;
  final String judul, sub;
  final VoidCallback? onTap;
  final Widget? trailing;
  const _Menu(this.icon, this.judul, this.sub, {this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          IconBox(icon, size: 36),
          const SizedBox(width: 11),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(judul, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
            ]),
          ),
          trailing ?? const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ]),
      ),
    );
  }
}
