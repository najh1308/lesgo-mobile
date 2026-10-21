import 'package:flutter/material.dart';

/// Palet warna GeoLearn (mengikuti desain Figma "GeoLearn Mobile App").
class AppColors {
  // Warna utama
  static const indigo = Color(0xFF0F4C81);
  static const indigoDark = Color(0xFF0B3A63);
  static const teal = Color(0xFF00A896);
  static const tealDark = Color(0xFF0D7D76);
  static const coral = Color(0xFFF4A261);
  static const coralDark = Color(0xFFC56D2F);
  static const slate = Color(0xFF1D2A44);

  // Latar lembut
  static const softTeal = Color(0xFFE4F7F4);
  static const softBlue = Color(0xFFEAF2F8);
  static const softCoral = Color(0xFFFFF1E6);
  static const softGrey = Color(0xFFEEF1F4);

  // Nama lama tetap dipakai di seluruh layar
  static const primary = indigo;
  static const accent = coral;
  static const bg = Color(0xFFF8F9FA);
  static const ink = slate;
  static const muted = Color(0xFF6F7B8F);
  static const line = Color(0xFFE6EBF0);
  static const success = teal;
  static const danger = Color(0xFFE5484D);
  static const star = Color(0xFFD77A25);
}

/// Bayangan kartu standar.
const kShadow = [
  BoxShadow(color: Color(0x171D2A44), blurRadius: 26, offset: Offset(0, 8)),
];

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.indigo).copyWith(
    primary: AppColors.indigo,
    secondary: AppColors.teal,
    tertiary: AppColors.coral,
    surface: Colors.white,
    error: AppColors.danger,
  );
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: AppColors.line),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: AppColors.ink),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
      shape: Border(bottom: BorderSide(color: AppColors.line)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      hintStyle: const TextStyle(color: Color(0xFF8590A0), fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(borderSide: const BorderSide(color: AppColors.teal, width: 1.6)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.teal,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.line,
        elevation: 0,
        shadowColor: AppColors.teal.withAlpha(46),
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.indigo,
        backgroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.teal,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: AppColors.softTeal,
      side: const BorderSide(color: AppColors.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      labelStyle: const TextStyle(fontSize: 12.5, color: AppColors.ink),
      secondaryLabelStyle: const TextStyle(fontSize: 12.5, color: AppColors.teal, fontWeight: FontWeight.w700),
      checkmarkColor: AppColors.teal,
      showCheckmark: false,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.all(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.teal : AppColors.line),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.teal),
    dividerTheme: const DividerThemeData(color: AppColors.line, space: 1),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: AppColors.indigo,
      unselectedLabelColor: AppColors.muted,
      labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      unselectedLabelStyle: TextStyle(fontSize: 13),
      dividerColor: Colors.transparent,
      indicatorSize: TabBarIndicatorSize.tab,
      indicator: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(9)),
        boxShadow: [BoxShadow(color: Color(0xFFCCD4DB), blurRadius: 6, offset: Offset(0, 2))],
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
