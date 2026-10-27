import 'package:flutter/material.dart';

import '../core/personalisasi.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'main_shell.dart';

/// Pertanyaan personalisasi: tampil otomatis saat pertama kali masuk,
/// dan bisa dibuka lagi dari Profil untuk mengubah jawaban.
class PersonalisasiScreen extends StatefulWidget {
  const PersonalisasiScreen({super.key});

  @override
  State<PersonalisasiScreen> createState() => _PersonalisasiScreenState();
}

class _PersonalisasiScreenState extends State<PersonalisasiScreen> {
  static const _total = 4;
  int _langkah = 0;
  String? _peran;
  final Set<String> _jenjangAnak = {}, _tujuan = {}, _mapel = {};
  int? _budget;
  bool _budgetDipilih = false;
  bool _menyimpan = false;

  static const _ikonPeran = {
    'Pelajar SD': Icons.child_care_rounded,
    'Pelajar SMP': Icons.backpack_outlined,
    'Pelajar SMA': Icons.school_outlined,
    'Mahasiswa': Icons.local_library_outlined,
    'Orang tua': Icons.family_restroom_rounded,
  };

  @override
  void initState() {
    super.initState();
    final p = Personalisasi.i;
    _peran = p.peran;
    _jenjangAnak.addAll(p.jenjangAnak);
    _tujuan.addAll(p.tujuan);
    _mapel.addAll(p.mapel);
    _budget = p.budgetMax;
    _budgetDipilih = p.budgetDipilih;
  }

  bool get _valid {
    switch (_langkah) {
      case 0:
        return _peran != null && (_peran != 'Orang tua' || _jenjangAnak.isNotEmpty);
      case 1:
        return _tujuan.isNotEmpty;
      case 2:
        return _mapel.isNotEmpty;
      default:
        return _budgetDipilih;
    }
  }

  void _toggle(Set<String> s, String v) => setState(() => s.contains(v) ? s.remove(v) : s.add(v));

  Future<void> _lanjut() async {
    if (_langkah < _total - 1) {
      // Buang tujuan yang tidak ada lagi di pilihan peran/jenjang yang baru.
      if (_langkah == 0) _tujuan.retainAll(Personalisasi.tujuanUntuk(_peran, _jenjangAnak));
      setState(() => _langkah++);
      return;
    }
    setState(() => _menyimpan = true);
    await Personalisasi.i.simpan(
      peran: _peran!,
      jenjangAnak: _jenjangAnak,
      tujuan: _tujuan,
      mapel: _mapel,
      budgetMax: _budget,
    );
    ShellController.bump(); // Beranda memuat ulang rekomendasi
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final pertama = !Personalisasi.i.sudahAtur;
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        // Ditutup sebelum selesai: tandai agar tidak ditanya terus-menerus.
        if (didPop) Personalisasi.i.tandaiDilewati();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                if (_langkah > 0)
                  IconButton(
                    onPressed: () => setState(() => _langkah--),
                    icon: const Icon(Icons.arrow_back_rounded),
                  )
                else
                  const SizedBox(width: 48, height: 48),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(pertama ? 'Lewati' : 'Batal'),
                ),
              ]),
              Row(children: [
                for (var i = 0; i < _total; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      height: 5,
                      decoration: BoxDecoration(
                        color: i <= _langkah ? AppColors.teal : AppColors.line,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ]),
              const SizedBox(height: 22),
              Expanded(child: ListView(children: _isiLangkah())),
              const SizedBox(height: 10),
              PrimaryButton(
                label: _langkah == _total - 1 ? 'Selesai' : 'Lanjut',
                loading: _menyimpan,
                onPressed: _valid ? _lanjut : null,
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _judul(String eyebrow, String judul, String sub) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Eyebrow(eyebrow, color: AppColors.teal),
      const SizedBox(height: 8),
      Text(judul,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.6, height: 1.25)),
      const SizedBox(height: 6),
      Text(sub, style: const TextStyle(color: AppColors.muted, height: 1.45)),
      const SizedBox(height: 20),
    ]);
  }

  List<Widget> _isiLangkah() {
    final eyebrow = 'LANGKAH ${_langkah + 1} DARI $_total';
    switch (_langkah) {
      case 0:
        return [
          _judul(eyebrow, 'Kamu sebagai siapa?', 'Supaya rekomendasi bimbel dan Chatbot pas untukmu.'),
          for (final o in Personalisasi.peranOpsi)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _Tile(o,
                  icon: _ikonPeran[o], lebar: true, pilih: _peran == o, onTap: () => setState(() => _peran = o)),
            ),
          if (_peran == 'Orang tua') ...[
            const SizedBox(height: 10),
            const Text('Anakmu di jenjang apa?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 4),
            const Text('Boleh pilih lebih dari satu.', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final j in Personalisasi.jenjangAnakOpsi)
                _Tile(j, pilih: _jenjangAnak.contains(j), onTap: () => _toggle(_jenjangAnak, j)),
            ]),
          ],
        ];
      case 1:
        return [
          _judul(
              eyebrow,
              _peran == 'Orang tua' ? 'Apa yang ingin kamu capai untuk anakmu?' : 'Untuk apa kamu memakai GeoLearn?',
              'Pilihan disesuaikan dengan jawabanmu tadi. Boleh pilih lebih dari satu.'),
          Wrap(spacing: 8, runSpacing: 10, children: [
            for (final t in Personalisasi.tujuanUntuk(_peran, _jenjangAnak))
              _Tile(t, pilih: _tujuan.contains(t), onTap: () => _toggle(_tujuan, t)),
          ]),
        ];
      case 2:
        return [
          _judul(eyebrow, 'Mata pelajaran apa yang kamu minati?', 'Bimbel dengan mapel ini akan diprioritaskan.'),
          Wrap(spacing: 8, runSpacing: 10, children: [
            for (final m in Personalisasi.mapelOpsi)
              _Tile(m, pilih: _mapel.contains(m), onTap: () => _toggle(_mapel, m)),
          ]),
        ];
      default:
        return [
          _judul(eyebrow, 'Berapa estimasi biaya bimbel per bulan?',
              'Hanya untuk menyaring rekomendasi. Bisa diubah kapan saja di Profil.'),
          for (final o in Personalisasi.budgetOpsi)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _Tile(o.$1,
                  icon: Icons.payments_outlined,
                  lebar: true,
                  pilih: _budgetDipilih && _budget == o.$2,
                  onTap: () => setState(() {
                        _budget = o.$2;
                        _budgetDipilih = true;
                      })),
            ),
        ];
    }
  }
}

class _Tile extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool pilih, lebar;
  final VoidCallback onTap;
  const _Tile(this.label, {this.icon, this.lebar = false, required this.pilih, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tile = Material(
      color: pilih ? AppColors.softTeal : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: pilih ? AppColors.teal : AppColors.line, width: pilih ? 1.6 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(mainAxisSize: lebar ? MainAxisSize.max : MainAxisSize.min, children: [
            if (icon != null) ...[
              Icon(icon, size: 21, color: pilih ? AppColors.teal : AppColors.muted),
              const SizedBox(width: 11),
            ],
            Flexible(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 14, fontWeight: pilih ? FontWeight.w800 : FontWeight.w600, color: AppColors.ink)),
            ),
            if (lebar) const Spacer(),
            if (pilih) ...[
              const SizedBox(width: 8),
              const Icon(Icons.check_circle_rounded, size: 19, color: AppColors.teal),
            ],
          ]),
        ),
      ),
    );
    return lebar ? SizedBox(width: double.infinity, child: tile) : tile;
  }
}