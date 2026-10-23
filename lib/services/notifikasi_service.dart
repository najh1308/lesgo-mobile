import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/app_settings.dart';
import '../core/format.dart';
import '../models/models.dart';

/// Notifikasi lokal (tanpa Firebase) yang dijadwalkan di sistem operasi,
/// sehingga tetap muncul walau aplikasi sedang ditutup:
/// 1. konfirmasi langsung saat pendaftaran berhasil,
/// 2. pengingat 1 hari dan 1 jam sebelum SETIAP sesi mingguan,
/// 3. dibatalkan otomatis jika pendaftaran dibatalkan atau pengguna keluar,
/// 4. disinkronkan ulang tiap aplikasi dibuka (HP baru, instal ulang, ganti zona waktu).
class NotifikasiService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _siap = false;

  /// iOS hanya menyimpan 64 notifikasi terjadwal, jadi dibatasi dan diisi ulang
  /// setiap aplikasi dibuka (jendela bergulir).
  static const _maksTotal = 60;
  static const _maksPerPendaftaran = 40;
  static const _payloadAktivitas = 'aktivitas';

  /// Diset true saat notifikasi diketuk; dibaca MainShell untuk membuka tab Aktivitas.
  static bool bukaAktivitasMenunggu = false;
  static final ValueNotifier<int> sinyalBukaAktivitas = ValueNotifier<int>(0);

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
      category: AndroidNotificationCategory.reminder,
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
        onDidReceiveNotificationResponse: _saatDiketuk,
      );
      _siap = true;

      // Aplikasi dibuka dari kondisi mati lewat ketukan notifikasi.
      final awal = await _plugin.getNotificationAppLaunchDetails();
      if (awal?.didNotificationLaunchApp == true &&
          awal?.notificationResponse?.payload == _payloadAktivitas) {
        bukaAktivitasMenunggu = true;
      }
    } catch (e) {
      debugPrint('Notifikasi gagal disiapkan: $e');
    }
  }

  static void _saatDiketuk(NotificationResponse r) {
    if (r.payload != _payloadAktivitas) return;
    bukaAktivitasMenunggu = true;
    sinyalBukaAktivitas.value++;
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
      await _plugin.show(
        id: id,
        title: judul,
        body: isi,
        notificationDetails: _detail,
        payload: _payloadAktivitas,
      );
    } catch (e) {
      debugPrint('Notifikasi gagal tampil: $e');
    }
  }

  static String _dua(int n) => n.toString().padLeft(2, '0');

  /// Waktu sesi pertama dalam WIB (Asia/Jakarta), apa pun zona HP-nya.
  static tz.TZDateTime? _waktuSesi(Pendaftaran p) {
    final t = DateTime.tryParse(p.tanggalMulai);
    final jam = p.jamMulai.split(':');
    if (t == null || jam.length < 2) return null;
    return tz.TZDateTime(tz.getLocation('Asia/Jakarta'), t.year, t.month, t.day,
        int.tryParse(jam[0]) ?? 0, int.tryParse(jam[1]) ?? 0);
  }

  /// Susun semua pengingat yang masih di masa depan untuk satu pendaftaran.
  /// Sesi berulang tiap minggu selama durasi program.
  /// ID = idPendaftaran*1000 + nomorSesi*2 (+1 untuk pengingat H-1), 999 = konfirmasi.
  static List<_Pengingat> _susun(Pendaftaran p) {
    final awal = _waktuSesi(p);
    if (awal == null) return [];
    final sekarang = tz.TZDateTime.now(tz.UTC);
    final zona = AppSettings.i.zona; // jam di notifikasi mengikuti zona pilihan pengguna
    final jumlah = p.durasiMinggu < 1 ? 1 : (p.durasiMinggu > 90 ? 90 : p.durasiMinggu);

    final hasil = <_Pengingat>[];
    for (var k = 0; k < jumlah; k++) {
      final sesi = awal.add(Duration(days: 7 * k));
      final tgl = '${sesi.year}-${_dua(sesi.month)}-${_dua(sesi.day)}';
      final jam = TimeUtil.konversi(tgl, p.jamMulai, zona);
      final dasar = p.id * 1000 + k * 2;

      final satuJam = sesi.subtract(const Duration(hours: 1));
      if (satuJam.isAfter(sekarang)) {
        hasil.add(_Pengingat(dasar, satuJam, 'Les dimulai 1 jam lagi',
            '${p.namaProgram} di ${p.bimbelNama}, pukul $jam.'));
      }
      final satuHari = sesi.subtract(const Duration(days: 1));
      if (satuHari.isAfter(sekarang)) {
        hasil.add(_Pengingat(dasar + 1, satuHari, 'Besok ada kelas',
            '${p.namaProgram} di ${p.bimbelNama}, besok pukul $jam.'));
      }
    }
    hasil.sort((a, b) => a.waktu.compareTo(b.waktu));
    return hasil;
  }

  /// Pakai alarm tepat waktu bila diizinkan (Android 12+), jika tidak
  /// jatuh ke mode hemat daya yang bisa bergeser beberapa menit.
  static Future<AndroidScheduleMode> _modeJadwal() async {
    try {
      final ok = await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.canScheduleExactNotifications();
      if (ok == true) return AndroidScheduleMode.exactAllowWhileIdle;
    } catch (_) {}
    return AndroidScheduleMode.inexactAllowWhileIdle;
  }

  static Future<void> _jadwalkan(List<_Pengingat> daftar) async {
    final mode = await _modeJadwal();
    for (final r in daftar) {
      try {
        await _plugin.zonedSchedule(
          id: r.id,
          title: r.judul,
          body: r.isi,
          scheduledDate: r.waktu,
          notificationDetails: _detail,
          androidScheduleMode: mode,
          payload: _payloadAktivitas,
        );
      } catch (e) {
        debugPrint('Pengingat gagal dijadwalkan: $e');
      }
    }
  }

  /// Dipanggil setelah pendaftaran berhasil.
  static Future<void> pendaftaranBerhasil(Pendaftaran p) async {
    if (!_siap) return;
    await tampilkan(p.id * 1000 + 999, 'Pendaftaran berhasil',
        '${p.namaProgram} di ${p.bimbelNama}. Mulai ${p.hari}, ${p.tanggalMulai} pukul ${p.jamMulai} WIB. '
        'Pengingat jadwal sudah diaktifkan.');
    await _jadwalkan(_susun(p).take(_maksPerPendaftaran).toList());
  }

  /// Samakan semua pengingat di HP dengan daftar pendaftaran terbaru dari server.
  /// Aman dipanggil berulang: pengingat lama dihapus lalu dijadwalkan ulang.
  static Future<void> sinkronkan(List<Pendaftaran> semua) async {
    if (!_siap) return;
    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final r in pending) {
        await _plugin.cancel(id: r.id);
      }
    } catch (_) {}

    final semuaPengingat = <_Pengingat>[];
    for (final p in semua) {
      if (p.status != 'aktif' && p.status != 'menunggu') continue;
      semuaPengingat.addAll(_susun(p).take(_maksPerPendaftaran));
    }
    semuaPengingat.sort((a, b) => a.waktu.compareTo(b.waktu));
    await _jadwalkan(semuaPengingat.take(_maksTotal).toList());
  }

  /// Hapus semua pengingat milik satu pendaftaran (saat dibatalkan).
  static Future<void> batalkanPengingat(int pendaftaranId) async {
    if (!_siap) return;
    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final r in pending) {
        if (r.id ~/ 1000 == pendaftaranId) await _plugin.cancel(id: r.id);
      }
    } catch (_) {}
  }

  /// Dipakai saat logout supaya pengingat satu akun tidak muncul di akun lain.
  static Future<void> batalkanSemua() async {
    if (!_siap) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }
}

class _Pengingat {
  final int id;
  final tz.TZDateTime waktu;
  final String judul, isi;
  const _Pengingat(this.id, this.waktu, this.judul, this.isi);
}