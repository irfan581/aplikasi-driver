import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Semua alamat endpoint dan pengaturan jaringan terkumpul di satu tempat,
/// supaya tidak ada string endpoint yang tercecer di dalam layar.
class KonstantaApi {
  KonstantaApi._();

  static String get baseUrl =>
      dotenv.env['BASE_URL'] ?? 'https://api.example.com/api';

  /// Asal server tanpa `/api`. Foto dibalas server sebagai path relatif
  /// (`/storage/...`) karena Storage::url() di Laravel tidak tahu alamat mana
  /// yang dipakai HP, jadi HP-lah yang melengkapinya.
  static String get asalServer {
    final url = baseUrl;
    return url.endsWith('/api') ? url.substring(0, url.length - 4) : url;
  }

  /// Alamat penuh sebuah berkas dari server, aman dipanggil untuk path yang
  /// sudah terlanjur absolut.
  static String urlBerkas(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return '$asalServer${path.startsWith('/') ? '' : '/'}$path';
  }

  static bool get isDebug => (dotenv.env['DEBUG'] ?? 'false') == 'true';

  static String get namaApp => dotenv.env['APP_NAME'] ?? 'Driver Tani Makmur';

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration timeout = Duration(seconds: 20);
  static const Duration sendTimeout = Duration(seconds: 60);

  /// Unggah foto diberi jatah waktu sendiri, jauh lebih longgar daripada
  /// permintaan biasa. Di gudang dengan sinyal satu bar, satu foto 1 MB bisa
  /// perlu lebih dari semenit hanya untuk selesai naik, dan sesudah itu server
  /// masih memindahkan berkasnya serta mencari alamat dari koordinat sebelum
  /// menjawab. Dengan jatah 60 detik seperti permintaan lain, unggahan yang
  /// sebenarnya berjalan lancar dipotong di tengah jalan.
  static const Duration unggahDasar = Duration(seconds: 60);

  /// Tambahan jatah per megabita berkas, supaya foto besar di sinyal lambat
  /// tidak dinilai dengan ukuran yang sama seperti foto kecil.
  static const Duration unggahPerMb = Duration(seconds: 90);

  /// Batas menunggu jawaban server setelah berkasnya selesai naik.
  static const Duration unggahTerima = Duration(seconds: 90);

  // ── Autentikasi ───────────────────────────────────────────────
  static const String login = '/driver/login';
  static const String logout = '/driver/logout';
  static const String profil = '/driver/profil';
  static const String gantiPassword = '/driver/profil/ganti-password';
  static const String fcmToken = '/driver/profil/fcm-token';

  // ── Tugas pengiriman ──────────────────────────────────────────
  static const String tugasHariIni = '/driver/tugas/hari-ini';

  /// Rekap kerja driver. Tanpa parameter berarti 30 hari terakhir.
  static const String ringkasan = '/driver/tugas/ringkasan';

  /// Riwayat rit, dipaginasi dan terbaru lebih dulu. Tanpa parameter berarti
  /// seluruh riwayat.
  static const String riwayat = '/driver/tugas/riwayat';

  static String tugasDetail(int id) => '/driver/tugas/$id';

  /// Tidak ada endpoint status rit. Status rit disimpulkan server dari
  /// laporan yang masuk, bukan ditekan driver.
  static String laporanTujuan(int ritId, int itemId) =>
      '/driver/tugas/$ritId/item/$itemId/laporan';

  // ── Foto bukti bongkar ────────────────────────────────────────
  static String fotoBongkar(int ritId, int itemId) =>
      '/driver/tugas/$ritId/item/$itemId/foto';

  static String hapusFotoBongkar(int ritId, int itemId, int fotoId) =>
      '/driver/tugas/$ritId/item/$itemId/foto/$fotoId';

  // ── Chat grup laporan ─────────────────────────────────────────
  static const String chatGrup = '/driver/chat/grup';
  static const String chatKirim = '/driver/chat/kirim';
  static const String chatUnread = '/driver/chat/unread';
  static const String chatFcmToken = '/driver/chat/fcm-token';

  static String chatPesan(int grupId) => '/driver/chat/grup/$grupId/pesan';

  /// Nama channel realtime grup, harus sama persis dengan yang disiarkan
  /// server di ChatMessageSent::broadcastOn().
  static String channelGrup(int grupId) => 'private-chat.group.$grupId';

  /// Batas foto per tujuan, disamakan dengan BATAS_PER_TUJUAN di server.
  /// Ditegakkan juga di sini supaya driver tidak menjepret lalu ditolak.
  static const int batasFotoPerTujuan = 10;

  /// Ditampilkan di footer Splash dan Login. Disamakan manual dengan
  /// `version` di pubspec.yaml — bukan dibaca lewat package_info_plus, supaya
  /// dua layar paling awal ini tidak menunggu pemanggilan platform channel
  /// yang async untuk sekadar menampilkan teks kecil.
  static const String versiApp = '1.0.11';
}
