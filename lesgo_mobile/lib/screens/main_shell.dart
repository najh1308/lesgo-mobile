import 'package:flutter/material.dart';

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
        bottomNavigationBar: NavigationBar(
          backgroundColor: Colors.white,
          selectedIndex: index,
          onDestinationSelected: (v) => ShellController.tab.value = v,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Beranda'),
            NavigationDestination(icon: Icon(Icons.search), label: 'Cari'),
            NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Belajar'),
            NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Aktivitas'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profil'),
          ],
        ),
      ),
    );
  }
}
