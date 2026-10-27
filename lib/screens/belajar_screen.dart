import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/game_service.dart';
import '../widgets/common.dart';

/// Tab Belajar (Ruang Belajar): Chatbot Geo (LLM) dan mini game Hitung Cepat.
class BelajarScreen extends StatefulWidget {
  const BelajarScreen({super.key});

  @override
  State<BelajarScreen> createState() => _BelajarScreenState();
}

class _BelajarScreenState extends State<BelajarScreen> {
  int _terbaik = 0;

  @override
  void initState() {
    super.initState();
    _muatSkor();
  }

  Future<void> _muatSkor() async {
    final v = await GameService.skorTerbaikLokal();
    if (mounted) setState(() => _terbaik = v);
  }

  Future<void> _buka(String route) async {
    await Navigator.pushNamed(context, route);
    _muatSkor(); // skor terbaik bisa berubah setelah bermain
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: 'Ruang Belajar',
        subtitle: 'Pilih cara belajar favoritmu',
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(color: AppColors.softCoral, borderRadius: BorderRadius.circular(12)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.emoji_events_rounded, size: 17, color: Color(0xFFD36F26)),
            const SizedBox(width: 4),
            Text('$_terbaik',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFD36F26))),
            const Text(' skor', style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
          ]),
        ),
      ),
      Expanded(
        child: ListView(padding: const EdgeInsets.all(18), children: [
          _hero(),
          const SizedBox(height: 18),
          _kartuAi(),
          const SizedBox(height: 14),
          _kartuGame(),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xFFBFCAD4)),
            ),
            child: const Row(children: [
              Icon(Icons.screen_rotation_rounded, color: AppColors.teal),
              SizedBox(width: 11),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Main dengan gerakan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                  SizedBox(height: 2),
                  Text('Miringkan HP ke kanan untuk "Benar", ke kiri untuk "Salah". Sensor akselerometer membaca gerakanmu.',
                      style: TextStyle(fontSize: 11.5, color: AppColors.muted, height: 1.4)),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    ]);
  }

  Widget _hero() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: AppColors.indigo, borderRadius: BorderRadius.circular(20)),
      child: Stack(children: [
        Positioned(
          right: -4,
          top: -36,
          child: Text('π',
              style: TextStyle(fontSize: 120, fontWeight: FontWeight.w800, color: Colors.white.withAlpha(18))),
        ),
        Padding(
          padding: const EdgeInsets.all(22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Eyebrow('PERSONAL LEARNING', icon: Icons.auto_awesome),
            const SizedBox(height: 10),
            const Text('Satu ruang, banyak cara\nuntuk jadi lebih pintar.',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, height: 1.3, color: Colors.white)),
            const SizedBox(height: 6),
            Text('Belajar kapan saja dengan teknologi yang terasa personal.',
                style: TextStyle(fontSize: 12.5, color: Colors.white.withAlpha(174))),
          ]),
        ),
      ]),
    );
  }

  Widget _kartuAi() {
    return _KartuFitur(
      color: AppColors.softTeal,
      onTap: () => _buka('/tutor'),
      child: Row(children: [
        Container(
          width: 88,
          height: 108,
          decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(18)),
          child: Stack(alignment: Alignment.center, children: [
            const Icon(Icons.smart_toy_outlined, size: 50, color: Colors.white),
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(color: AppColors.coral, borderRadius: BorderRadius.circular(6)),
                child: const Text('AI',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.slate)),
              ),
            ),
          ]),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Eyebrow('ASISTEN CERDAS 24/7', color: AppColors.teal),
            SizedBox(height: 6),
            Text('Chatbot Geo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink)),
            SizedBox(height: 6),
            Text('Tanyakan PR, pahami konsep langkah demi langkah, atau minta tips belajar.',
                style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.45)),
            SizedBox(height: 12),
            _Ajak('Mulai bertanya', AppColors.indigo),
          ]),
        ),
      ]),
    );
  }

  Widget _kartuGame() {
    return _KartuFitur(
      color: AppColors.slate,
      onTap: () => _buka('/game'),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Eyebrow('MINI GAME'),
            const SizedBox(height: 6),
            const Text('Hitung Cepat', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 6),
            const Text('Benar atau salah? Asah refleks matematikamu dalam 60 detik dan masuk papan peringkat.',
                style: TextStyle(fontSize: 12, color: Color(0xFFAEB7C6), height: 1.45)),
            const SizedBox(height: 9),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(color: Colors.white.withAlpha(26), borderRadius: BorderRadius.circular(5)),
              child: Text('BEST $_terbaik',
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
            const SizedBox(height: 12),
            const _Ajak('Mulai bermain', Colors.white),
          ]),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 95,
          height: 95,
          child: Stack(clipBehavior: Clip.none, children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.coral.withAlpha(102)),
              ),
              alignment: Alignment.center,
              child: const Text('42', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
            const Positioned(left: -5, top: 5, child: _Bulatan('×', AppColors.coral, AppColors.slate)),
            const Positioned(right: -4, bottom: 2, child: _Bulatan('÷', AppColors.teal, Colors.white)),
          ]),
        ),
      ]),
    );
  }
}

class _KartuFitur extends StatelessWidget {
  final Color color;
  final VoidCallback onTap;
  final Widget child;
  const _KartuFitur({required this.color, required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.all(18), child: child)),
    );
  }
}

class _Ajak extends StatelessWidget {
  final String teks;
  final Color warna;
  const _Ajak(this.teks, this.warna);

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(teks, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: warna)),
      const SizedBox(width: 2),
      Icon(Icons.chevron_right_rounded, size: 18, color: warna),
    ]);
  }
}

class _Bulatan extends StatelessWidget {
  final String teks;
  final Color bg, fg;
  const _Bulatan(this.teks, this.bg, this.fg);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 27,
      height: 27,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(teks, style: TextStyle(fontWeight: FontWeight.w800, color: fg)),
    );
  }
}
