import 'package:flutter/material.dart';

/// Warna mengikuti design system "Modern Logistics, Orange & White" —
/// satu warna aksen (oranye), bukan dua warna brand seperti sebelumnya.
/// [secondary] sekarang latar krem sangat terang untuk chip/aksen lembut;
/// badge atau ikon yang butuh warna solid dan terlihat pakai [primary].
class WarnaApp {
  WarnaApp._();

  static const Color primary = Color(0xFFF97316);
  static const Color primaryDark = Color(0xFFEA580C);

  static const Color secondary = Color(0xFFFFF7ED);

  static const Color background = Color(0xFFF8F9FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF0F1F4);

  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);
  static const Color textWhite = Color(0xFFFFFFFF);

  static const Color success = Color(0xFF22C55E);
  static const Color error = Color(0xFFEF4444);

  /// Latar lembut untuk aksi berbahaya — tombol Keluar memakainya supaya
  /// terbaca sebagai peringatan tanpa menjadi blok merah pekat yang menarik
  /// mata lebih dulu daripada isi layarnya.
  static const Color errorBg = Color(0xFFFEF2F2);
  static const Color warning = Color(0xFFF59E0B);

  /// Tidak ada di design system baru (cuma success/warning/danger); dipakai
  /// untuk status yang bukan salah satu dari ketiganya (mis. "Berangkat",
  /// "Tiba"), jadi tetap dipertahankan sebagai warna keempat yang netral.
  static const Color info = Color(0xFF3B82F6);

  static const Color border = Color(0xFFF0F1F4);
  static const Color divider = Color(0xFFF0F1F4);

  /// Warna per status perjalanan rit, dipakai di kartu dan lencana.
  static Color statusRit(String status) => switch (status) {
        'Dimuat' => warning,
        'Berangkat' => info,
        'Selesai' => success,
        'Batal' => error,
        _ => textSecondary,
      };

  /// Warna per status bongkar tiap tujuan.
  static Color statusBongkar(String status) => switch (status) {
        'Selesai' => success,
        // Bermasalah bukan kegagalan total — barangnya bisa saja turun
        // sebagian — jadi diberi warna peringatan, bukan merah.
        'Bermasalah' => warning,
        'Gagal' => error,
        'Tiba' => info,
        _ => textSecondary,
      };
}
