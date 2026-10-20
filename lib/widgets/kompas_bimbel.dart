import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../core/theme.dart';
import '../services/location_service.dart';
import 'common.dart';

/// Kompas yang menunjuk ke arah bimbel.
/// Sensor magnetometer memberi arah utara, sensor akselerometer dipakai untuk
/// koreksi kemiringan HP, dan GPS (LBS) memberi posisi pengguna.
class KompasBimbel extends StatefulWidget {
  final double lat, lng;
  const KompasBimbel({super.key, required this.lat, required this.lng});

  @override
  State<KompasBimbel> createState() => _KompasBimbelState();
}

class _KompasBimbelState extends State<KompasBimbel> {
  StreamSubscription<MagnetometerEvent>? _magSub;
  StreamSubscription<AccelerometerEvent>? _accSub;
  Timer? _cekSensor;

  List<double>? _gravitasi; // x, y, z terakhir dari akselerometer
  double? _azimut; // arah HP terhadap utara magnetik (derajat)
  double _sinHalus = 0, _cosHalus = 1; // untuk menghaluskan gerakan jarum
  double? _bearing; // arah dari pengguna ke bimbel (derajat dari utara)
  bool _lokasiAsli = false;
  bool _tidakAda = false;

  @override
  void initState() {
    super.initState();
    _hitungBearing();
    _accSub = accelerometerEventStream(samplingPeriod: SensorInterval.uiInterval).listen(
      (e) => _gravitasi = [e.x, e.y, e.z],
      onError: (_) => _gagal(),
      cancelOnError: true,
    );
    _magSub = magnetometerEventStream(samplingPeriod: SensorInterval.uiInterval).listen(
      _onMagnet,
      onError: (_) => _gagal(),
      cancelOnError: true,
    );
    // Jika 3 detik tidak ada data, anggap HP tidak punya sensor (misalnya di Chrome).
    _cekSensor = Timer(const Duration(seconds: 3), () {
      if (_azimut == null) _gagal();
    });
  }

  @override
  void dispose() {
    _magSub?.cancel();
    _accSub?.cancel();
    _cekSensor?.cancel();
    super.dispose();
  }

  void _gagal() {
    if (mounted && _azimut == null) setState(() => _tidakAda = true);
  }

  Future<void> _hitungBearing() async {
    final loc = await LocationService.current();
    final p1 = loc.lat * pi / 180, p2 = widget.lat * pi / 180;
    final dl = (widget.lng - loc.lng) * pi / 180;
    final y = sin(dl) * cos(p2);
    final x = cos(p1) * sin(p2) - sin(p1) * cos(p2) * cos(dl);
    if (!mounted) return;
    setState(() {
      _bearing = (atan2(y, x) * 180 / pi + 360) % 360;
      _lokasiAsli = loc.asli;
    });
  }

  /// Rumus yang sama dengan SensorManager.getRotationMatrix di Android:
  /// H = E x A (arah timur), M = A x H (arah utara), azimut = atan2(Hy, My).
  void _onMagnet(MagnetometerEvent e) {
    final g = _gravitasi;
    if (g == null) return;
    final ax = g[0], ay = g[1], az = g[2];
    final ex = e.x, ey = e.y, ez = e.z;
    var hx = ey * az - ez * ay, hy = ez * ax - ex * az, hz = ex * ay - ey * ax;
    final normH = sqrt(hx * hx + hy * hy + hz * hz);
    if (normH < 0.1) return; // HP dekat logam atau posisi tidak valid
    hx /= normH;
    hy /= normH;
    hz /= normH;
    final normA = sqrt(ax * ax + ay * ay + az * az);
    final nax = ax / normA, naz = az / normA;
    final my = naz * hx - nax * hz;
    final az0 = atan2(hy, my);

    // Low-pass filter pada sin/cos agar jarum tidak bergetar.
    const k = 0.15;
    _sinHalus = _sinHalus * (1 - k) + sin(az0) * k;
    _cosHalus = _cosHalus * (1 - k) + cos(az0) * k;
    final deg = (atan2(_sinHalus, _cosHalus) * 180 / pi + 360) % 360;
    _cekSensor?.cancel();
    if (mounted) setState(() => _azimut = deg);
  }

  static String _arahMataAngin(double d) {
    const nama = ['Utara', 'Timur Laut', 'Timur', 'Tenggara', 'Selatan', 'Barat Daya', 'Barat', 'Barat Laut'];
    return nama[((d + 22.5) % 360 ~/ 45)];
  }

  @override
  Widget build(BuildContext context) {
    final bearing = _bearing;
    return Panel(
      child: Row(children: [
        SizedBox(width: 92, height: 92, child: _jarum()),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Kompas ke Bimbel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            if (bearing != null)
              Text('Bimbel ada di arah ${_arahMataAngin(bearing)} (${bearing.round()}°) dari '
                  '${_lokasiAsli ? 'lokasimu' : 'lokasi cadangan'}.'),
            const SizedBox(height: 4),
            Text(
              _tidakAda
                  ? 'Sensor magnetometer tidak tersedia di perangkat ini. Coba di HP Android.'
                  : 'Pegang HP mendatar. Jauhkan dari magnet atau logam. Jika jarum melenceng, gerakkan HP membentuk angka 8.',
              style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _jarum() {
    final az = _azimut, bearing = _bearing;
    if (_tidakAda || az == null || bearing == null) {
      return CircleAvatar(
        backgroundColor: AppColors.line,
        child: _tidakAda
            ? const Icon(Icons.explore_off_outlined, color: AppColors.muted, size: 36)
            : const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    final sudut = (bearing - az) * pi / 180;
    return Stack(alignment: Alignment.center, children: [
      Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primary.withAlpha(18),
          border: Border.all(color: AppColors.primary.withAlpha(60), width: 2),
        ),
      ),
      // Huruf U menunjukkan utara.
      Transform.rotate(
        angle: -az * pi / 180,
        child: const Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.only(top: 2),
            child: Text('U', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.danger)),
          ),
        ),
      ),
      Transform.rotate(
        angle: sudut,
        child: const Icon(Icons.navigation_rounded, size: 52, color: AppColors.primary),
      ),
    ]);
  }
}
