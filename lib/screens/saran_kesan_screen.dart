import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class SaranKesanScreen extends StatefulWidget {
  const SaranKesanScreen({super.key});

  @override
  State<SaranKesanScreen> createState() => _SaranKesanScreenState();
}

class _SaranKesanScreenState extends State<SaranKesanScreen> {
  final _saran = TextEditingController();
  final _kesan = TextEditingController();
  List<Map<String, dynamic>> _riwayat = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  void dispose() {
    _saran.dispose();
    _kesan.dispose();
    super.dispose();
  }

  Future<void> _muat() async {
    try {
      final data = await ApiClient.rpcAuth('api_saran_kesan_list') as List;
      if (mounted) setState(() => _riwayat = data.map((e) => Map<String, dynamic>.from(e)).toList());
    } on ApiException {
      // Riwayat bersifat tambahan; abaikan jika gagal dimuat.
    }
  }

  Future<void> _kirim() async {
    if (_saran.text.trim().isEmpty || _kesan.text.trim().isEmpty) {
      showMsg(context, 'Saran dan kesan wajib diisi', error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      await ApiClient.rpcAuth('api_saran_kesan_kirim', {'p_saran': _saran.text.trim(), 'p_kesan': _kesan.text.trim()});
      _saran.clear();
      _kesan.clear();
      if (mounted) showMsg(context, 'Terima kasih, saran dan kesan terkirim');
      await _muat();
    } on ApiException catch (e) {
      if (mounted) showMsg(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saran dan Kesan')),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 28), children: [
        const Text('Mata kuliah Pemrograman Aplikasi Mobile', style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 16),
        const Text('Saran', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        AppField(controller: _saran, hint: 'Tulis saranmu', icon: Icons.lightbulb_outline, maxLines: 4),
        const SizedBox(height: 14),
        const Text('Kesan', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        AppField(controller: _kesan, hint: 'Tulis kesanmu', icon: Icons.favorite_border, maxLines: 4),
        const SizedBox(height: 18),
        PrimaryButton(label: 'Kirim', onPressed: _kirim, loading: _loading),
        const SizedBox(height: 24),
        if (_riwayat.isNotEmpty) const SectionTitle('Riwayat'),
        const SizedBox(height: 8),
        for (final r in _riwayat)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(Fmt.tanggalJam(r['created_at'].toString()), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                const SizedBox(height: 6),
                Text('Saran: ${r['saran']}'),
                const SizedBox(height: 4),
                Text('Kesan: ${r['kesan']}'),
              ]),
            ),
          ),
      ]),
    );
  }
}
