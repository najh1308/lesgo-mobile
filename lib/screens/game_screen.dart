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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hitung Cepat')),
      body: SafeArea(
        child: switch (_fase) {
          _Fase.awal => _layarAwal(),
          _Fase.main => _layarMain(),
          _Fase.selesai => _layarSelesai(),
        },
      ),
    );
  }

  Widget _layarAwal() {
    return ListView(padding: const EdgeInsets.all(24), children: [
      const Icon(Icons.calculate_rounded, size: 84, color: AppColors.accent),
      const SizedBox(height: 12),
      const Text('Benar atau salah?',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      const Text(
        'Kamu punya 60 detik. Tebak apakah hasil hitungan yang muncul benar. '
        'Soal makin sulit setiap 5 jawaban benar.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.muted, height: 1.4),
      ),
      const SizedBox(height: 20),
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _pakaiSensor,
            onChanged: (v) => setState(() => _pakaiSensor = v),
            title: const Text('Kontrol miring (sensor akselerometer)',
                style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('Miringkan HP ke kanan untuk Benar, ke kiri untuk Salah.'),
          ),
          const Text('Tombol Benar/Salah tetap bisa dipakai.',
              style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
        ]),
      ),
      const SizedBox(height: 12),
      Panel(
        child: Row(children: [
          const Icon(Icons.emoji_events_outlined, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(child: Text('Skor terbaikmu di HP ini: $_terbaik')),
        ]),
      ),
      const SizedBox(height: 24),
      PrimaryButton(label: 'Mulai', icon: Icons.play_arrow_rounded, onPressed: _mulai),
    ]);
  }

  Widget _layarMain() {
    final warnaWaktu = _sisa <= 10 ? AppColors.danger : AppColors.primary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      color: _kilat?.withAlpha(40) ?? Colors.transparent,
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        Row(children: [
          Pill('Level $_level'),
          const SizedBox(width: 8),
          Pill('Skor $_skor', color: AppColors.success),
          const Spacer(),
          Icon(Icons.timer_outlined, color: warnaWaktu),
          const SizedBox(width: 4),
          Text('$_sisa d', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: warnaWaktu)),
        ]),
        const SizedBox(height: 10),
        LinearProgressIndicator(value: _sisa / _durasi, color: warnaWaktu, minHeight: 6),
        const Spacer(),
        Text(_soal.teks,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w800, color: AppColors.ink)),
        const SizedBox(height: 8),
        if (_beruntun >= 3)
          Text('$_beruntun benar berturut-turut! +5 bonus',
              style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w700)),
        const Spacer(),
        if (_pakaiSensor) _indikatorMiring(),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => _jawab(false),
              icon: const Icon(Icons.close_rounded),
              label: const Text('Salah'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
              onPressed: () => _jawab(true),
              icon: const Icon(Icons.check_rounded),
              label: const Text('Benar'),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _indikatorMiring() {
    if (!_sensorAda) {
      return const Text('Menunggu sensor... (di Chrome/emulator mungkin tidak tersedia)',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: AppColors.muted));
    }
    // -1 = miring penuh ke kiri, 1 = penuh ke kanan.
    final posisi = (-_miringX / 9.8).clamp(-1.0, 1.0);
    return Column(children: [
      const Row(children: [
        Text('← Salah', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
        Spacer(),
        Text('Benar →', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 6),
      Container(
        height: 14,
        decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(8)),
        child: Align(
          alignment: Alignment(posisi, 0),
          child: Container(
            width: 26,
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
    ]);
  }

  Widget _layarSelesai() {
    final total = _benar + _salah;
    final akurasi = total == 0 ? 0 : (_benar * 100 / total).round();
    return ListView(padding: const EdgeInsets.all(24), children: [
      const Icon(Icons.emoji_events_rounded, size: 80, color: AppColors.accent),
      const SizedBox(height: 8),
      const Text('Waktu habis!',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      Text('$_skor poin',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: AppColors.primary)),
      Text('Benar $_benar · Salah $_salah · Akurasi $akurasi% · Level $_level',
          textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
      const SizedBox(height: 6),
      Text(
        switch (_terkirim) {
          null => 'Menyimpan skor...',
          true => 'Skor tersimpan di HP dan server.',
          false => 'Skor tersimpan di HP. Akan dikirim ke server saat online.',
        },
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
      ),
      const SizedBox(height: 20),
      const SectionTitle('Papan Peringkat'),
      const SizedBox(height: 8),
      if (_papan == null && _papanError == null)
        const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())),
      if (_papanError != null) Text(_papanError!, style: const TextStyle(color: AppColors.muted)),
      if (_papan != null && _papan!.isEmpty)
        const Text('Belum ada skor.', style: TextStyle(color: AppColors.muted)),
      if (_papan != null)
        for (final p in _papan!)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Panel(
              child: Row(children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: p.peringkat <= 3 ? AppColors.accent : AppColors.line,
                  child: Text('${p.peringkat}',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(p.nama, style: const TextStyle(fontWeight: FontWeight.w600))),
                Text('${p.skor}', style: const TextStyle(fontWeight: FontWeight.w800)),
              ]),
            ),
          ),
      const SizedBox(height: 20),
      PrimaryButton(label: 'Main lagi', icon: Icons.replay_rounded, onPressed: _mulai),
    ]);
  }
}
