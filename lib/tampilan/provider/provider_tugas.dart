import 'package:flutter/foundation.dart';

import '../../data/model/model_ringkasan.dart';
import '../../data/model/model_tugas.dart';
import '../../data/repositori/repositori_tugas.dart';
import '../../data/servis/hasil_api.dart';
import '../../inti/konstanta/kode_error.dart';

class ProviderTugas extends ChangeNotifier {
  ProviderTugas([RepositoriTugas? repositori])
      : _repositori = repositori ?? RepositoriTugas();

  final RepositoriTugas _repositori;

  List<ModelTugas> _rit = [];
  bool _sedangMemuat = false;
  bool _sedangMengubah = false;
  String? _pesanError;
  DateTime? _terakhirDimuat;
  ModelRingkasan? _ringkasan;

  List<ModelTugas> get rit => List.unmodifiable(_rit);
  bool get sedangMemuat => _sedangMemuat;
  bool get sedangMengubah => _sedangMengubah;
  String? get pesanError => _pesanError;
  DateTime? get terakhirDimuat => _terakhirDimuat;

  /// Rekap 30 hari terakhir untuk beranda. Null selama belum termuat.
  ModelRingkasan? get ringkasan => _ringkasan;

  bool get kosong => !_sedangMemuat && _rit.isEmpty;

  int get ritBelumSelesai =>
      _rit.where((r) => !r.selesai && !r.dibatalkan).length;

  Future<void> muat({String? tanggal}) async {
    _sedangMemuat = true;
    _pesanError = null;
    notifyListeners();

    final hasil = await _repositori.hariIni(tanggal: tanggal);

    _sedangMemuat = false;

    if (hasil.sukses) {
      _rit = hasil.data ?? [];
      _terakhirDimuat = DateTime.now();
    } else {
      _pesanError = hasil.pesan;
    }

    notifyListeners();
  }

  /// Diambil terpisah dari daftar tugas, dan kegagalannya sengaja tidak
  /// mengisi [pesanError]: rekap cuma pelengkap, dan menutup seluruh beranda
  /// gara-gara rekapnya gagal membuat driver kehilangan daftar kiriman yang
  /// justru jadi alasan ia membuka aplikasi.
  Future<void> muatRingkasan() async {
    final hasil = await _repositori.ringkasan();

    if (hasil.sukses) {
      _ringkasan = hasil.data;
      notifyListeners();
    }
  }

  ModelTugas? cariRit(int id) {
    for (final r in _rit) {
      if (r.id == id) return r;
    }
    return null;
  }

  Future<ModelTugas?> muatDetail(int id) async {
    final hasil = await _repositori.detail(id);

    if (!hasil.sukses) {
      _pesanError = hasil.pesan;
      notifyListeners();
      return null;
    }

    _gantiRit(hasil.data!);
    return hasil.data;
  }

  /// Mengembalikan pesan error bila gagal, atau null bila berhasil. Pemanggil
  /// yang menampilkan pesannya, karena aturan penolakan dari server perlu
  /// dibaca driver apa adanya.
  Future<String?> kirimLaporan({
    required int ritId,
    required int itemId,
    required String status,
    required String catatan,
    double? latitude,
    double? longitude,
  }) async {
    _sedangMengubah = true;
    notifyListeners();

    final hasil = await _kirimLaporanUlet(
      ritId: ritId,
      itemId: itemId,
      status: status,
      catatan: catatan,
      latitude: latitude,
      longitude: longitude,
    );

    _sedangMengubah = false;

    if (!hasil.sukses) {
      notifyListeners();
      return hasil.pesan;
    }

    // Laporan sudah tersimpan di server pada titik ini. Item hasilnya
    // ditempel dulu ke rit lokal supaya `tuntas` langsung benar walau
    // permintaan detail rit di bawah gagal (mis. sinyal putus sesaat setelah
    // POST ini) — laporan yang sebenarnya sudah sukses tidak boleh membuat
    // layar terlihat seperti belum terkirim, karena server menolak laporan
    // kedua untuk tujuan yang sama.
    if (hasil.data != null) _tempelItem(ritId, hasil.data!);

    // Laporan satu tujuan ikut menggerakkan status ritnya — bisa jadi rit itu
    // baru saja menutup dirinya sendiri — jadi ritnya dicoba diambil ulang
    // utuh. Kegagalannya diabaikan begitu saja (bukan lewat muatDetail, yang
    // akan mengisi pesanError dan menampilkan galat padahal laporannya
    // sendiri berhasil): rit yang sedikit basi akan terkoreksi sendiri di
    // pemuatan berikutnya.
    final detail = await _repositori.detail(ritId);
    if (detail.sukses && detail.data != null) _gantiRit(detail.data!);

    return null;
  }

  /// Jeda antar percobaan pengiriman laporan.
  ///
  /// Wilayah bongkar sopir sering bersinyal buruk, dan satu kali gagal karena
  /// jaringan tersendat bukan alasan menyuruhnya menekan tombol lagi sambil
  /// berdiri di depan toko. Jedanya pendek karena ia sedang menunggu di layar,
  /// bukan berjalan di latar seperti antrian foto.
  static const List<Duration> _jedaLaporan = [
    Duration(seconds: 3),
    Duration(seconds: 6),
  ];

  /// Kirim laporan dengan beberapa kali percobaan bila jaringannya yang gagal.
  ///
  /// Hanya kegagalan jaringan yang diulang. Penolakan server (foto belum ada,
  /// keterangan kosong, rit dibatalkan) tidak akan berubah kalau diulang, jadi
  /// langsung diteruskan ke layar apa adanya.
  ///
  /// TUJUAN_SUDAH_TUNTAS pada percobaan kedua dan seterusnya dibaca sebagai
  /// berhasil, bukan gagal: artinya kiriman sebelumnya sebenarnya sudah sampai
  /// dan hanya jawabannya yang tidak kembali. Tanpa ini, laporan yang sudah
  /// tersimpan terlihat seperti gagal dan sopir mengulanginya terus.
  Future<HasilApi<ModelTugasItem>> _kirimLaporanUlet({
    required int ritId,
    required int itemId,
    required String status,
    required String catatan,
    double? latitude,
    double? longitude,
  }) async {
    for (var percobaan = 0;; percobaan++) {
      final hasil = await _repositori.kirimLaporan(
        ritId: ritId,
        itemId: itemId,
        status: status,
        catatan: catatan,
        latitude: latitude,
        longitude: longitude,
      );

      if (hasil.sukses) return hasil;

      if (percobaan > 0 && hasil.kode == KodeError.tujuanSudahTuntas) {
        // Tanpa data item: yang benar diambil dari pemuatan detail sesudah
        // ini, bukan dari jawaban penolakan.
        return const HasilApi(sukses: true);
      }

      if (!hasil.offline || percobaan >= _jedaLaporan.length) return hasil;

      await Future<void>.delayed(_jedaLaporan[percobaan]);
    }
  }

  void _tempelItem(int ritId, ModelTugasItem item) {
    final indeks = _rit.indexWhere((r) => r.id == ritId);
    if (indeks < 0) return;

    _rit[indeks] = _rit[indeks].gantiItem(item);
    notifyListeners();
  }

  void bersihkan() {
    _rit = [];
    _ringkasan = null;
    _pesanError = null;
    _terakhirDimuat = null;
    notifyListeners();
  }

  void _gantiRit(ModelTugas baru) {
    final indeks = _rit.indexWhere((r) => r.id == baru.id);
    if (indeks >= 0) {
      _rit[indeks] = baru;
    } else {
      _rit = [..._rit, baru];
    }
    notifyListeners();
  }
}
