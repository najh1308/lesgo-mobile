import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/notifikasi_service.dart';
import 'aktivitas_screen.dart';
import 'belajar_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';

/// Penghubung antar tab: pindah tab, memicu muat ulang data, dan membawa kata kunci pencarian.
class ShellController {
  static final ValueNotifier<int> tab = ValueNotifier<int>(0);
  static final ValueNotifier<int> refresh = ValueNotifier<int>(0);
  static final ValueNotifier<String?> searchQuery = ValueNotifier<String?>(null);

  /// Jenjang yang dipilih dari Beranda (SD/SMP/SMA/UTBK) untuk langsung difilter di tab Cari.
  static final ValueNotifier<String?> searchJenjang = ValueNotifier<String?>(null);

  /// Panggil setelah data berubah (daftar, batal, favorit) agar tab lain memuat ulang.
  static void bump() => refresh.value++;
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  @override
  void initState() {
    super.initState();
    ShellController.tab.value = 0;
    NotifikasiService.mintaIzin(); // Android 13+: tampilkan dialog izin notifikasi
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: ShellController.tab,
      builder: (context, index, _) => Scaffold(
        body: IndexedStack(
          index: index,
          children: const [
            HomeScreen(),
            SearchScreen(),
            BelajarScreen(),
            AktivitasScreen(),
            ProfileScreen(),
          ],
        ),
        bottomNavigationBar: _BottomNav(
          index: index,
          onTap: (v) => ShellController.tab.value = v,
        ),
      ),
    );
  }
}

/// Navigasi bawah sesuai desain GeoLearn: ikon + label, tab aktif berwarna teal
/// dengan garis kecil di atasnya.
class _BottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.index, required this.onTap});

  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, 'Beranda'),
    (Icons.search_rounded, Icons.search_rounded, 'Cari'),
    (Icons.menu_book_outlined, Icons.menu_book_rounded, 'Belajar'),
    (Icons.calendar_month_outlined, Icons.calendar_month_rounded, 'Aktivitas'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: Row(children: [
            for (var i = 0; i < _items.length; i++)
              Expanded(
                child: InkWell(
                  onTap: () => onTap(i),
                  child: Stack(alignment: Alignment.center, children: [
                    if (i == index)
                      Positioned(
                        top: 0,
                        child: Container(
                          width: 24,
                          height: 3,
                          decoration: const BoxDecoration(
                            color: AppColors.teal,
                            borderRadius: BorderRadius.vertical(bottom: Radius.circular(4)),
                          ),
                        ),
                      ),
                    Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(i == index ? _items[i].$2 : _items[i].$1,
                          size: 23, color: i == index ? AppColors.teal : const Color(0xFF8C96A6)),
                      const SizedBox(height: 3),
                      Text(_items[i].$3,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: i == index ? FontWeight.w700 : FontWeight.w500,
                            color: i == index ? AppColors.teal : const Color(0xFF8C96A6),
                          )),
                    ]),
                  ]),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
