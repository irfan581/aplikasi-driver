/// Kode error yang dikirim backend. Dipakai supaya aplikasi tidak perlu
/// mencocokkan teks pesan yang sewaktu-waktu bisa berubah.
class KodeError {
  KodeError._();

  // Autentikasi
  static const String kredensialSalah = 'KREDENSIAL_SALAH';
  static const String driverNonaktif = 'DRIVER_NONAKTIF';
  static const String akunBelumAktif = 'AKUN_BELUM_AKTIF';
  static const String akunDinonaktifkan = 'ACCOUNT_INACTIVE';
  static const String salahJenisAkun = 'WRONG_ACCOUNT_TYPE';
  static const String passwordLamaSalah = 'PASSWORD_LAMA_SALAH';

  // Laporan pengiriman
  static const String transisiTidakSah = 'TRANSISI_TIDAK_SAH';
  static const String ritDibatalkan = 'RIT_DIBATALKAN';
  static const String bukanTugasAnda = 'BUKAN_TUGAS_ANDA';
  static const String fotoWajib = 'FOTO_WAJIB';
  static const String catatanWajib = 'CATATAN_WAJIB';

  // Foto bukti bongkar
  static const String tujuanSudahTuntas = 'TUJUAN_SUDAH_TUNTAS';
  static const String batasFoto = 'BATAS_FOTO';
  static const String clientUuidBentrok = 'CLIENT_UUID_BENTROK';
  static const String bukanFotoAnda = 'BUKAN_FOTO_ANDA';
}
