class NamaRute {
  NamaRute._();

  static const String splash = '/';
  static const String login = '/login';
  static const String gantiPasswordWajib = '/ganti-password-wajib';

  /// Rangka bertab. Namanya tetap `beranda` supaya alur yang sudah ada
  /// (splash, login, ganti password wajib) tidak perlu ikut berubah.
  static const String beranda = '/beranda';

  static const String gantiPassword = '/profil/ganti-password';
  static const String detailTugas = '/tugas/detail';
  static const String laporan = '/tugas/laporan';
}
