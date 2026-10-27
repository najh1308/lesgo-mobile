import 'app_settings.dart';

/// Pemformatan angka, harga (dengan konversi mata uang), dan tanggal.
class Fmt {
  static String _grup(int n, String sep) {
    final s = n.abs().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(sep);
      b.write(s[i]);
    }
    return (n < 0 ? '-' : '') + b.toString();
  }

  static String rupiah(int v) => 'Rp${_grup(v, '.')}';

  /// Harga dasar selalu rupiah; ditampilkan sesuai mata uang pilihan pengguna.
  static String harga(int idr) {
    final s = AppSettings.i;
    final kurs = s.rates[s.mataUang] ?? 1;
    final nilai = idr * kurs;
    switch (s.mataUang) {
      case 'USD':
        return '\$${nilai.toStringAsFixed(2)}';
      case 'EUR':
        return '€${nilai.toStringAsFixed(2)}';
      case 'JPY':
        return '¥${_grup(nilai.round(), ',')}';
      default:
        return rupiah(idr);
    }
  }

  static String jarak(double? km) =>
      km == null ? '' : '${km.toStringAsFixed(1).replaceAll('.', ',')} km';

  static String rating(double r) => r.toStringAsFixed(1).replaceAll('.', ',');

  static const _bulan = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  /// DateTime -> '2026-11-02' (format yang dipakai server dan layar lain).
  static String iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// '2026-11-02' -> '2 Nov 2026'
  static String tanggal(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day} ${_bulan[d.month - 1]} ${d.year}';
  }

  /// '2026-11-02 09:30:00' -> '2 Nov 2026, 09:30'
  static String tanggalJam(String iso) {
    final d = DateTime.tryParse(iso.replaceFirst(' ', 'T'));
    if (d == null) return iso;
    final j = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${_bulan[d.month - 1]} ${d.year}, $j:$m';
  }
}

/// Konversi jam dari WIB ke WITA, WIT, atau London (GMT/BST).
class TimeUtil {
  static const zonaPilihan = {
    'WIB': 'WIB',
    'WITA': 'WITA',
    'WIT': 'WIT',
    'LONDON': 'London',
  };

  /// Minggu terakhir pada bulan tertentu (pukul 00.00 UTC).
  static DateTime _mingguTerakhir(int tahun, int bulan) {
    final hariTerakhir = DateTime.utc(tahun, bulan + 1, 0);
    // weekday: Senin=1 ... Minggu=7, jadi (weekday % 7) = jumlah hari sejak Minggu.
    return DateTime.utc(
      tahun,
      bulan,
      hariTerakhir.day - (hariTerakhir.weekday % 7),
    );
  }

  /// London memakai BST (UTC+1) dari Minggu terakhir Maret sampai Minggu
  /// terakhir Oktober, masing-masing pukul 01.00 UTC. Di luar itu GMT (UTC+0).
  static bool isBst(DateTime utc) {
    final mulai = _mingguTerakhir(utc.year, 3).add(const Duration(hours: 1));
    final selesai = _mingguTerakhir(utc.year, 10).add(const Duration(hours: 1));
    return !utc.isBefore(mulai) && utc.isBefore(selesai);
  }

  static String _dua(int n) => n.toString().padLeft(2, '0');

  /// [tanggalIso] = '2026-11-02', [jamWib] = '15:30'. Hasil mis. '08:30 GMT'.
  /// Jika hari berubah, ditambah keterangan '(+1 hari)' atau '(-1 hari)'.
  static String konversi(String tanggalIso, String jamWib, String zona) {
    final t = DateTime.tryParse(tanggalIso);
    final p = jamWib.split(':');
    if (t == null || p.length < 2) return jamWib;

    // Jam jadwal adalah WIB (UTC+7): ubah dulu ke UTC.
    final utc = DateTime.utc(
      t.year,
      t.month,
      t.day,
      int.parse(p[0]),
      int.parse(p[1]),
    ).subtract(const Duration(hours: 7));

    int offset;
    String label;
    switch (zona) {
      case 'WITA':
        offset = 8;
        label = 'WITA';
        break;
      case 'WIT':
        offset = 9;
        label = 'WIT';
        break;
      case 'LONDON':
        offset = isBst(utc) ? 1 : 0;
        label = offset == 1 ? 'BST' : 'GMT';
        break;
      default:
        offset = 7;
        label = 'WIB';
    }

    final lokal = utc.add(Duration(hours: offset));
    final selisihHari = DateTime.utc(
      lokal.year,
      lokal.month,
      lokal.day,
    ).difference(DateTime.utc(t.year, t.month, t.day)).inDays;
    final ket = selisihHari > 0
        ? ' (+1 hari)'
        : (selisihHari < 0 ? ' (-1 hari)' : '');
    return '${_dua(lokal.hour)}:${_dua(lokal.minute)} $label$ket';
  }

  /// Rentang jam, mis. '08:30 - 10:00 GMT'.
  static String rentang(
    String tanggalIso,
    String mulai,
    String selesai,
    String zona,
  ) {
    final a = konversi(tanggalIso, mulai, zona);
    final b = konversi(tanggalIso, selesai, zona);
    final label = b.split(' ').length > 1
        ? b.substring(b.indexOf(' ') + 1)
        : '';
    return '${a.split(' ').first} - ${b.split(' ').first} $label'.trim();
  }
}
