import 'package:flutter/material.dart';

/// Aturan gerak yang dipakai seluruh aplikasi.
///
/// Animasi di sini bertugas menjelaskan perubahan, bukan menghibur. Aplikasi
/// ini dibuka sambil tergesa di gudang, jadi durasinya sengaja pendek dan
/// tidak ada yang menunda pekerjaan driver.
class Gerak {
  Gerak._();

  /// Perubahan kecil di tempat: lencana status, titik langkah, warna.
  static const Duration cepat = Duration(milliseconds: 250);

  /// Perpindahan halaman dan isi yang masuk bertahap.
  static const Duration sedang = Duration(milliseconds: 320);

  /// Pembukaan splash: logo → nama aplikasi → indikator proses. Dibuat cukup
  /// lambat supaya ketiga tahapnya terbaca sebagai urutan, bukan satu ledakan
  /// elemen bersamaan.
  ///
  /// Harus selalu lebih pendek dari [lantaiSplash] — kalau tidak, navigasi
  /// bisa memotong animasinya saat pemeriksaan sesi selesai lebih cepat.
  static const Duration splash = Duration(milliseconds: 1600);

  /// Lama minimum splash tampil. Selisihnya dengan [splash] adalah waktu
  /// "diam" setelah semua elemen selesai masuk — tanpa jeda itu, layar
  /// langsung berpindah tepat saat animasi baru saja usai dan terasa
  /// terburu-buru.
  static const Duration lantaiSplash = Duration(milliseconds: 2400);

  /// Sapuan angka progres, cukup lambat untuk terlihat bergerak.
  static const Duration progres = Duration(milliseconds: 600);

  /// Sebagian driver menyalakan penghemat baterai yang mematikan animasi
  /// sistem. Pilihan itu harus dihormati: keadaan akhir ditampilkan langsung
  /// tanpa transisi.
  static bool dimatikan(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  /// Durasi yang sudah menghormati pengaturan di atas.
  static Duration durasi(BuildContext context, Duration normal) =>
      dimatikan(context) ? Duration.zero : normal;
}
