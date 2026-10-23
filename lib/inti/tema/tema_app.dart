import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'warna_app.dart';

class TemaApp {
  TemaApp._();

  /// Radius kartu sesuai design system baru; dipakai juga di luar
  /// [cardTheme] oleh layar yang membangun kartunya sendiri lewat [Container].
  static const double radiusKartu = 20;

  /// Radius tombol dan kolom isian sesuai design system baru.
  static const double radiusTombol = 16;

  static ThemeData get terang {
    final teks = GoogleFonts.robotoTextTheme();

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: WarnaApp.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: WarnaApp.primary,
        primary: WarnaApp.primary,
        secondary: WarnaApp.secondary,
        surface: WarnaApp.surface,
        error: WarnaApp.error,
      ),
      textTheme: teks.apply(
        bodyColor: WarnaApp.textPrimary,
        displayColor: WarnaApp.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: WarnaApp.surface,
        foregroundColor: WarnaApp.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: GoogleFonts.roboto(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: WarnaApp.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: WarnaApp.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusKartu),
          side: const BorderSide(color: WarnaApp.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: WarnaApp.surface,
        // Tinggi kolom isian dikunci 56dp, sama dengan tinggi tombol utama —
        // tanpa ini tingginya ikut ukuran font dan bisa meleset beberapa
        // piksel dari tombol di bawahnya. Padding 16 mengikuti grid 8dp.
        constraints: const BoxConstraints(minHeight: 56),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: _garisInput(WarnaApp.border),
        enabledBorder: _garisInput(WarnaApp.border),
        focusedBorder: _garisInput(WarnaApp.primary, tebal: 1.6),
        errorBorder: _garisInput(WarnaApp.error),
        focusedErrorBorder: _garisInput(WarnaApp.error, tebal: 1.6),
        hintStyle: const TextStyle(color: WarnaApp.textHint),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: WarnaApp.primary,
          foregroundColor: WarnaApp.textWhite,
          // Tombol utama tinggi 56dp sesuai design system baru, dan dipakai
          // sopir sambil berdiri di gudang, sering dengan tangan kotor atau
          // bersarung.
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusTombol)),
          textStyle:
              GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: WarnaApp.textPrimary,
          minimumSize: const Size.fromHeight(56),
          side: const BorderSide(color: WarnaApp.border),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusTombol)),
          textStyle:
              GoogleFonts.roboto(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: WarnaApp.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: WarnaApp.primary.withValues(alpha: 0.16),
        elevation: 0,
        // Lebih tinggi dari bawaan dan label selalu tampil: sasaran sentuh
        // harus besar untuk tangan yang kotor atau bersarung, dan ikon saja
        // tidak cukup jelas bagi driver yang jarang memakai aplikasi.
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (keadaan) => GoogleFonts.roboto(
            fontSize: 12,
            fontWeight: keadaan.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: keadaan.contains(WidgetState.selected)
                ? WarnaApp.primaryDark
                : WarnaApp.textSecondary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (keadaan) => IconThemeData(
            size: 26,
            color: keadaan.contains(WidgetState.selected)
                ? WarnaApp.primaryDark
                : WarnaApp.textSecondary,
          ),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: WarnaApp.surface,
        // Tanpa ini Material 3 mewarnai permukaan dengan rona warna utama,
        // dan lembar konfirmasi tampil kekuningan alih-alih putih bersih.
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: WarnaApp.surface,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dividerTheme: const DividerThemeData(color: WarnaApp.divider, space: 1),
    );
  }

  static OutlineInputBorder _garisInput(Color warna, {double tebal = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusTombol),
      borderSide: BorderSide(color: warna, width: tebal),
    );
  }
}
