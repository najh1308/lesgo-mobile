import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../core/api_client.dart';
import '../core/theme.dart';
import '../services/game_service.dart';
import '../widgets/common.dart';

/// Mini game "Hitung Cepat": tebak apakah hasil hitungan benar atau salah dalam 60 detik.
/// Jawab dengan tombol, atau miringkan HP (sensor akselerometer):
/// miring ke kanan = Benar, miring ke kiri = Salah.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

enum _Fase { awal, main, selesai }

class _Soal {
  final String teks;
  final bool benar;
  const _Soal(this.teks, this.benar);
}

class _GameScreenState extends State<GameScreen> {
  static const _durasi = 60;
  static const _batasMiring = 4.5; // m/s², kira-kira miring 27 derajat
  static const _batasNetral = 2.0;

  final _rnd = Random();
  _Fase _fase = _Fase.awal;
  Timer? _timer;
  StreamSubscription<AccelerometerEvent>? _sensor;

  int _sisa = _durasi, _skor = 0, _benar = 0, _salah = 0, _beruntun = 0;
  int _nomorSoal = 0; // menentukan warna latar tiap soal
  _Soal _soal = const _Soal('', true);
  Color? _kilat; // warna kilasan setelah menjawab

  bool _pakaiSensor = true;
  bool _sensorAda = false;
  bool _siapMiring = true; // HP harus kembali tegak sebelum jawaban miring berikutnya
  double _miringX = 0;

  int _terbaik = 0;
  bool? _terkirim;
  List<PeringkatItem>? _papan;
  String? _papanError;

  int get _level => min(5, 1 + _benar ~/ 5);

  @override
  void initState() {
    super.initState();
    GameService.skorTerbaikLokal().then((v) {
      if (mounted) setState(() => _terbaik = v);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sensor?.cancel();
    super.dispose();
  }

  // ---------- Soal ----------

  _Soal _buatSoal() {
    int a, b, hasil;
    String op;
    int acak(int lo, int hi) => lo + _rnd.nextInt(hi - lo + 1);
    switch (_level) {
      case 1:
        a = acak(1, 10);
        b = acak(1, 10);
        op = '+';
        break;
      case 2:
        a = acak(5, 20);
        b = acak(1, a);
        op = _rnd.nextBool() ? '+' : '−';
        break;
      case 3:
        a = acak(2, 9);
        b = acak(2, 9);
        op = '×';
        break;
      case 4:
        b = acak(2, 9);
        if (_rnd.nextBool()) {
          a = b * acak(2, 9);
          op = '÷';
        } else {
          op = _rnd.nextBool() ? '+' : '−';
          a = acak(11, 50);
          b = op == '+' ? acak(11, 50) : acak(2, a);
        }
        break;
      default:
        a = acak(6, 15);
        b = acak(6, 12);
        op = '×';
    }
    switch (op) {
      case '+':
        hasil = a + b;
        break;
      case '−':
        hasil = a - b;
        break;
      case '÷':
        hasil = a ~/ b;
        break;
      default:
        hasil = a * b;
    }

    final tampilBenar = _rnd.nextBool();
    var tampil = hasil;
    if (!tampilBenar) {
      const geser = [-10, -2, -1, 1, 2, 10];
      do {
        tampil = hasil + geser[_rnd.nextInt(geser.length)];
      } while (tampil < 0 || tampil == hasil);
    }
    return _Soal('$a $op $b = $tampil', tampilBenar);
  }

  // ---------- Alur permainan ----------

  void _mulai() {
    setState(() {
      _fase = _Fase.main;
      _sisa = _durasi;
      _skor = _benar = _salah = _beruntun = 0;
      _terkirim = null;
      _papan = null;
      _papanError = null;
      _siapMiring = true;
      _soal = _buatSoal();
      _nomorSoal++;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_sisa <= 1) {
        _selesai();
      } else {
        setState(() => _sisa--);
      }
    });
    _nyalakanSensor();
  }

  void _nyalakanSensor() {
    _sensor?.cancel();
    if (!_pakaiSensor) return;
    _sensor = accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval).listen(
      (e) {
        if (_fase != _Fase.main) return;
        if (!_sensorAda) setState(() => _sensorAda = true);
        setState(() => _miringX = e.x);
        if (!_siapMiring) {
          if (e.x.abs() < _batasNetral) _siapMiring = true;
          return;
        }
        // Android: miring ke kanan membuat nilai x negatif.
        if (e.x < -_batasMiring) {
          _siapMiring = false;
          _jawab(true);
        } else if (e.x > _batasMiring) {
          _siapMiring = false;
          _jawab(false);
        }
      },
      onError: (_) {
        if (mounted) setState(() => _sensorAda = false);
      },
      cancelOnError: true,
    );
  }

  void _jawab(bool tebakanBenar) {
    if (_fase != _Fase.main) return;
    final tepat = tebakanBenar == _soal.benar;
    HapticFeedback.lightImpact();
    setState(() {
      if (tepat) {
        _benar++;
        _beruntun++;
        _skor += 10 * _level + (_beruntun >= 3 ? 5 : 0); // bonus jika 3x benar berturut-turut
        _kilat = AppColors.success;
      } else {
        _salah++;
        _beruntun = 0;
        _kilat = AppColors.danger;
      }
      _soal = _buatSoal();
      _nomorSoal++;
    });
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _kilat = null);
    });
  }

  Future<void> _selesai() async {
    _timer?.cancel();
    _sensor?.cancel();
    setState(() {
      _sisa = 0;
      _fase = _Fase.selesai;
      if (_skor > _terbaik) _terbaik = _skor;
    });
    final ok = await GameService.simpanSkor(
        skor: _skor, level: _level, benar: _benar, salah: _salah, durasi: _durasi);
    if (!mounted) return;
    setState(() => _terkirim = ok);
    try {
      final papan = await GameService.leaderboard();
      if (mounted) setState(() => _papan = papan);
    } on ApiException catch (e) {
      if (mounted) setState(() => _papanError = e.message);
    }
  }

  // ---------- Tampilan ----------

  static const _gelap = AppColors.slate;

  /// Warna latar yang bergantian setiap soal baru. Semua cukup gelap
  /// agar teks putih tetap mudah dibaca.
  static const _warnaSoal = [
    Color(0xFF1D2A44), // slate
    Color(0xFF0F4C81), // indigo
    Color(0xFF0B5E57), // teal tua
    Color(0xFF4A2D6B), // ungu
    Color(0xFF7A3B1D), // oranye bata
    Color(0xFF16506E), // biru laut
    Color(0xFF6B2340), // merah marun
    Color(0xFF2F5130), // hijau daun
  ];

  Color get _latar => _fase == _Fase.main ? _warnaSoal[_nomorSoal % _warnaSoal.length] : _gelap;
  static const _redup = Color(0xFF98A5B6);

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _gelap,
        body: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
          color: _latar,
          child: SafeArea(
          child: Column(children: [
            _kepala(),
            Expanded(
              child: switch (_fase) {
                _Fase.awal => _layarAwal(),
                _Fase.main => _layarMain(),
                _Fase.selesai => _layarSelesai(),
              },
            ),
          ]),
          ),
        ),
      ),
    );
  }

  /// Baris atas: tombol tutup, level + progres waktu, dan skor terbaik.
  Widget _kepala() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 12, 15, 8),
      child: Row(children: [
        Material(
          color: Colors.white.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.maybePop(context),
            child: const SizedBox(width: 40, height: 40, child: Icon(Icons.close_rounded, color: Colors.white)),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_fase == _Fase.awal ? 'HITUNG CEPAT' : 'LEVEL $_level',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.coral)),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: _fase == _Fase.main ? _sisa / _durasi : (_fase == _Fase.awal ? 1 : 0),
                minHeight: 5,
                color: _sisa <= 10 && _fase == _Fase.main ? AppColors.coral : AppColors.teal,
                backgroundColor: Colors.white.withAlpha(26),
              ),
            ),
          ]),
        ),
        const SizedBox(width: 15),
        Row(children: [
          const Icon(Icons.emoji_events_rounded, size: 16, color: AppColors.coral),
          const SizedBox(width: 3),
          Text('$_terbaik', style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
        ]),
      ]),
    );
  }

  Widget _kartuGelap({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(13),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: child,
    );
  }

  Widget _layarAwal() {
    return ListView(padding: const EdgeInsets.fromLTRB(24, 20, 24, 24), children: [
      Center(
        child: SizedBox(
          width: 130,
          height: 130,
          child: Stack(clipBehavior: Clip.none, children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.coral.withAlpha(102)),
              ),
              alignment: Alignment.center,
              child: const Text('6×7', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
            Positioned(left: 0, top: 8, child: _bulat('+', AppColors.coral, AppColors.slate)),
            Positioned(right: 0, bottom: 6, child: _bulat('÷', AppColors.teal, Colors.white)),
          ]),
        ),
      ),
      const SizedBox(height: 22),
      const Text('Benar atau salah?',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: Colors.white)),
      const SizedBox(height: 8),
      const Text(
        'Kamu punya 60 detik. Tebak apakah hasil hitungan yang muncul benar. '
        'Soal makin sulit setiap 5 jawaban benar.',
        textAlign: TextAlign.center,
        style: TextStyle(color: _redup, height: 1.5),
      ),
      const SizedBox(height: 24),
      _kartuGelap(
        child: Row(children: [
          const Icon(Icons.screen_rotation_rounded, color: AppColors.teal),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Kontrol miring (akselerometer)',
                  style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
              SizedBox(height: 2),
              Text('Miring kanan = Benar, miring kiri = Salah. Tombol tetap bisa dipakai.',
                  style: TextStyle(fontSize: 12, color: _redup, height: 1.4)),
            ]),
          ),
          Switch(value: _pakaiSensor, onChanged: (v) => setState(() => _pakaiSensor = v)),
        ]),
      ),
      const SizedBox(height: 28),
      PrimaryButton(label: 'Mulai bermain', icon: Icons.play_arrow_rounded, onPressed: _mulai),
    ]);
  }

  Widget _bulat(String t, Color bg, Color fg) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(t, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: fg)),
    );
  }

  Widget _layarMain() {
    final warnaWaktu = _sisa <= 10 ? AppColors.coral : AppColors.teal;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      color: _kilat?.withAlpha(45) ?? Colors.transparent,
      child: Column(children: [
        Container(
          height: 54,
          color: Colors.white.withAlpha(10),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _angka('SKOR', '$_skor'),
            _angka('BENAR', '$_benar'),
            _angka('COMBO', _beruntun >= 3 ? '×$_beruntun' : '-'),
          ]),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Column(children: [
              SizedBox(
                width: 104,
                height: 104,
                child: Stack(fit: StackFit.expand, children: [
                  CircularProgressIndicator(
                    value: _sisa / _durasi,
                    strokeWidth: 7,
                    color: warnaWaktu,
                    backgroundColor: Colors.white.withAlpha(26),
                    strokeCap: StrokeCap.round,
                  ),
                  Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_sisa.toString().padLeft(2, '0'),
                          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white)),
                      const Text('DETIK',
                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: _redup, letterSpacing: 0.8)),
                    ]),
                  ),
                ]),
              ),
              const Spacer(),
              const Text('Apakah hasil ini benar?', style: TextStyle(color: _redup)),
              const SizedBox(height: 8),
              FittedBox(
                child: Text(_soal.teks,
                    style: const TextStyle(fontSize: 46, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
              const SizedBox(height: 8),
              if (_beruntun >= 3)
                Text('$_beruntun benar berturut-turut! +5 bonus',
                    style: const TextStyle(color: AppColors.teal, fontWeight: FontWeight.w800)),
              const Spacer(),
              if (_pakaiSensor) _indikatorMiring(),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: _tombolJawab('Salah', Icons.close_rounded, AppColors.danger, () => _jawab(false))),
                const SizedBox(width: 12),
                Expanded(child: _tombolJawab('Benar', Icons.check_rounded, AppColors.teal, () => _jawab(true))),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _angka(String label, String nilai) {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(label, style: const TextStyle(fontSize: 10, color: _redup, fontWeight: FontWeight.w700)),
      const SizedBox(height: 2),
      Text(nilai, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
    ]);
  }

  Widget _tombolJawab(String label, IconData icon, Color warna, VoidCallback onTap) {
    return Material(
      color: warna,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          height: 64,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
          ]),
        ),
      ),
    );
  }

  Widget _indikatorMiring() {
    if (!_sensorAda) {
      return const Text('Menunggu sensor... (di Chrome/emulator mungkin tidak tersedia)',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: _redup));
    }
    // -1 = miring penuh ke kiri, 1 = penuh ke kanan.
    final posisi = (-_miringX / 9.8).clamp(-1.0, 1.0);
    return _kartuGelap(
      child: Column(children: [
        const Row(children: [
          Text('← Salah', style: TextStyle(color: Color(0xFFFF8A8E), fontWeight: FontWeight.w800, fontSize: 12.5)),
          Spacer(),
          Icon(Icons.screen_rotation_rounded, size: 16, color: _redup),
          Spacer(),
          Text('Benar →', style: TextStyle(color: AppColors.teal, fontWeight: FontWeight.w800, fontSize: 12.5)),
        ]),
        const SizedBox(height: 8),
        Container(
          height: 12,
          decoration: BoxDecoration(color: Colors.white.withAlpha(26), borderRadius: BorderRadius.circular(8)),
          child: Align(
            alignment: Alignment(posisi, 0),
            child: Container(
              width: 28,
              decoration: BoxDecoration(color: AppColors.coral, borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _layarSelesai() {
    final total = _benar + _salah;
    final akurasi = total == 0 ? 0 : (_benar * 100 / total).round();
    return ListView(padding: const EdgeInsets.fromLTRB(24, 16, 24, 24), children: [
      const Icon(Icons.emoji_events_rounded, size: 72, color: AppColors.coral),
      const SizedBox(height: 8),
      const Text('Waktu habis!',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
      const SizedBox(height: 4),
      Text('$_skor poin',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: AppColors.teal)),
      const SizedBox(height: 14),
      _kartuGelap(
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _angka('BENAR', '$_benar'),
          _angka('SALAH', '$_salah'),
          _angka('AKURASI', '$akurasi%'),
          _angka('LEVEL', '$_level'),
        ]),
      ),
      const SizedBox(height: 8),
      Text(
        switch (_terkirim) {
          null => 'Menyimpan skor...',
          true => 'Skor tersimpan di HP dan server.',
          false => 'Skor tersimpan di HP. Akan dikirim ke server saat online.',
        },
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, color: _redup),
      ),
      const SizedBox(height: 22),
      const Text('Papan Peringkat', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
      const SizedBox(height: 10),
      if (_papan == null && _papanError == null)
        const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())),
      if (_papanError != null) Text(_papanError!, style: const TextStyle(color: _redup)),
      if (_papan != null && _papan!.isEmpty) const Text('Belum ada skor.', style: TextStyle(color: _redup)),
      if (_papan != null)
        for (final p in _papan!)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _kartuGelap(
              child: Row(children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: p.peringkat <= 3 ? AppColors.coral : Colors.white.withAlpha(26),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text('${p.peringkat}',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, color: p.peringkat <= 3 ? AppColors.slate : Colors.white)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(p.nama, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                ),
                Text('${p.skor}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.teal)),
              ]),
            ),
          ),
      const SizedBox(height: 20),
      PrimaryButton(label: 'Main lagi', icon: Icons.replay_rounded, onPressed: _mulai),
    ]);
  }
}
