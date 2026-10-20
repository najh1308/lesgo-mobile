import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/models.dart';

/// Notifikasi mobile (lokal, tanpa Firebase):
/// 1. langsung muncul saat pendaftaran berhasil,
/// 2. pengingat terjadwal 1 jam sebelum sesi pertama dimulai,
/// 3. dibatalkan otomatis jika pendaftaran dibatalkan.
class NotifikasiService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _siap = false;

  /// Notifikasi hanya didukung di Android dan iOS (tidak di Chrome/Windows).
  static bool get didukung =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  static const _detail = NotificationDetails(
    android: AndroidNotificationDetails(
      'lesgo_jadwal',
      'Jadwal Bimbel',
      channelDescription: 'Konfirmasi pendaftaran dan pengingat jadwal les',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  static Future<void> init() async {
    if (!didukung || _siap) return;
    try {
      tzdata.initializeTimeZones();
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );
      _siap = true;
    } catch (e) {
      debugPrint('Notifikasi gagal disiapkan: $e');
    }
  }

  /// Android 13+ wajib meminta izin notifikasi ke pengguna.
  static Future<void> mintaIzin() async {
    if (!_siap) return;
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (_) {}
  }

  static Future<void> tampilkan(int id, String judul, String isi) async {
    if (!_siap) return;
    try {
      await _plugin.show(id: id, title: judul, body: isi, notificationDetails: _detail);
    } catch (e) {
      debugPrint('Notifikasi gagal tampil: $e');
    }
  }

  /// Waktu sesi pertama dalam WIB (Asia/Jakarta), apa pun zona HP-nya.
  static tz.TZDateTime? _waktuSesi(Pendaftaran p) {
    final t = DateTime.tryParse(p.tanggalMulai);
    final jam = p.jamMulai.split(':');
    if (t == null || jam.length < 2) return null;
    return tz.TZDateTime(tz.getLocation('Asia/Jakarta'), t.year, t.month, t.day,
        int.tryParse(jam[0]) ?? 0, int.tryParse(jam[1]) ?? 0);
  }

  /// Dipanggil setelah pendaftaran berhasil.
  static Future<void> pendaftaranBerhasil(Pendaftaran p) async {
    if (!_siap) return;
    await tampilkan(100000 + p.id, 'Pendaftaran berhasil',
        '${p.namaProgram} di ${p.bimbelNama}. Mulai ${p.hari}, ${p.tanggalMulai} pukul ${p.jamMulai} WIB.');

    final sesi = _waktuSesi(p);
    if (sesi == null) return;
    final ingat = sesi.subtract(const Duration(hours: 1));
    if (!ingat.isAfter(tz.TZDateTime.now(tz.UTC))) return; // sudah lewat

    try {
      await _plugin.zonedSchedule(
        id: p.id,
        title: 'Les dimulai 1 jam lagi',
        body: '${p.namaProgram} di ${p.bimbelNama}, pukul ${p.jamMulai} WIB.',
        scheduledDate: ingat,
        notificationDetails: _detail,
        // Tidak perlu izin alarm tepat waktu; bisa bergeser beberapa menit.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('Pengingat gagal dijadwalkan: $e');
    }
  }

  static Future<void> batalkanPengingat(int pendaftaranId) async {
    if (!_siap) return;
    try {
      await _plugin.cancel(id: pendaftaranId);
    } catch (_) {}
  }
}
