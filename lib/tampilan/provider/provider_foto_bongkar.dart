import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../data/model/model_foto_bongkar.dart';
import '../../data/repositori/repositori_foto_bongkar.dart';
import '../../data/servis/servis_antrian_foto.dart';
import '../../data/servis/servis_kamera.dart';
import '../../data/servis/servis_lokasi.dart';
import '../../inti/konstanta/konstanta_api.dart';

/// Keadaan foto bukti untuk satu tujuan.
///
/// Dibuat per layar, bukan satu untuk seluruh aplikasi: yang ditampilkan
/// selalu milik satu tujuan yang sedang dibuka, dan menyimpannya global hanya
/// menambah urusan membersihkan sisa tujuan sebelumnya.
class ProviderFotoBongkar extends ChangeNotifier {
  ProviderFotoBongkar({
    required this.ritId,
    required this.itemId,
    RepositoriFotoBongkar? repositori,
  }) : _repositori = repositori ?? RepositoriFotoBongkar() {
    _langganan = ServisAntrianFoto.perubahan.listen((_) => _muatTertunda());
  }

  final int ritId;
  final int itemId;

  final RepositoriFotoBongkar _repositori;
  static const Uuid _uuid = Uuid();

  StreamSubscription<void>? _langganan;

  /// Unggahan bisa selesai setelah driver menutup layarnya. Tanpa penanda ini
  /// pemberitahuan menyusul mengenai provider yang sudah dibuang dan
  /// menjatuhkan aplikasi.
  bool _dibuang = false;

  List<ModelFotoBongkar> _terkirim = [];
  List<FotoTertunda> _tertunda = [];
  bool _sedangMemuat = false;
  bool _sedangSibuk = false;
  String? _pesanError;

  List<ModelFotoBongkar> get terkirim => List.unmodifiable(_terkirim);
  List<FotoTertunda> get tertunda => List.unmodifiable(_tertunda);
  bool get sedangMemuat => _sedangMemuat;

  /// Menjepret, mengunggah, dan menghapus memakai satu penanda sibuk karena
  /// ketiganya mengubah daftar yang sama; menjalankan dua sekaligus membuat
  /// hitungan foto sempat salah di layar.
  bool get sedangSibuk => _sedangSibuk;

  String? get pesanError => _pesanError;

  int get jumlah => _terkirim.length + _tertunda.length;

  bool get adaFoto => jumlah > 0;

  bool get penuh => jumlah >= KonstantaApi.batasFotoPerTujuan;

  /// Tujuan hanya bisa ditutup kalau fotonya sudah benar-benar di server;
  /// yang masih mengantre belum dihitung server saat memeriksa FOTO_WAJIB.
  bool get siapDitutup => _terkirim.isNotEmpty;

  Future<void> muat() async {
    _sedangMemuat = true;
    _pesanError = null;
    notifyListeners();

    await _muatTertunda(diam: true);

    final hasil = await _repositori.daftar(ritId: ritId, itemId: itemId);

    _sedangMemuat = false;

    if (hasil.sukses) {
      _terkirim = hasil.data ?? [];
    } else {
      // Daftar dari server gagal diambil bukan berarti tidak ada foto sama
      // sekali; yang di antrian tetap ditampilkan supaya driver tidak
      // menjepret ulang foto yang sebenarnya sudah tersimpan.
      _pesanError = hasil.pesan;
    }

    notifyListeners();
  }

  /// Jepret satu foto lalu langsung coba kirim.
  ///
  /// Mengembalikan pesan untuk ditampilkan, atau null bila mulus. Foto masuk
  /// antrian lebih dulu, jadi kalau pengirimannya gagal ia tetap ada.
  Future<String?> jepret({String? catatan, String jenis = 'bongkar'}) async {
    if (penuh) {
      return 'Foto untuk tujuan ini sudah '
          '${KonstantaApi.batasFotoPerTujuan}. Hapus dulu yang tidak terpakai.';
    }

    // Penanda dipasang sebelum kamera dibuka, bukan sesudah. Ketukan kedua
    // yang datang sebelum kamera sempat muncul akan membuka pemilih gambar
    // kedua, dan foto keduanya masuk antrian melewati batas per tujuan.
    if (_sedangSibuk) return null;

    _sedangSibuk = true;
    notifyListeners();

    try {
      final clientUuid = _uuid.v4();

      // GPS dinyalakan berbarengan dengan kamera, bukan sesudahnya. Mencari
      // sinyal bisa memakan delapan detik, dan kalau baru dimulai setelah
      // kamera ditutup, layar berhenti selama itu tanpa satu pun tanda —
      // driver mengira aplikasinya menggantung dan menekan tombolnya lagi.
      // Dijalankan lebih dulu, pencarian itu sudah selesai selagi ia membidik.
      //
      // Hanya kalau izinnya sudah ada: meminta izin lokasi saat kamera terbuka
      // memunculkan dialog di atas kamera yang tidak terbaca driver.
      final dini =
          await ServisLokasi.bisaTanpaDialog() ? ServisLokasi.ambil() : null;

      final hasil = await ServisKamera.jepret(namaBerkas: clientUuid);

      switch (hasil.status) {
        case StatusJepret.dibatalkan:
          return null;
        case StatusJepret.izinDitolak:
        case StatusJepret.gagal:
          return hasil.pesan;
        case StatusJepret.berhasil:
          break;
      }

      final titik = await (dini ?? ServisLokasi.ambil());

      final antre = FotoTertunda(
        clientUuid: clientUuid,
        ritId: ritId,
        itemId: itemId,
        path: hasil.berkas!.path,
        dibuatPada: DateTime.now(),
        jenis: jenis,
        catatan: catatan,
        latitude: titik?.latitude,
        longitude: titik?.longitude,
        akurasi: titik?.akurasi,
        palsu: titik?.palsu ?? false,
      );

      await ServisAntrianFoto.tambah(antre);
      await _muatTertunda(diam: true);
      notifyListeners();

      // Pengirimannya tidak ditunggu di sini. Di wilayah bersinyal buruk satu
      // foto bisa perlu beberapa menit termasuk percobaan ulangnya, dan
      // menahan tombol selama itu membuat sopir mengira aplikasinya mati.
      // Fotonya sudah aman di antrian dan sudah muncul di petak dengan penanda
      // jam; petak itu berubah jadi gambar sungguhan begitu unggahannya
      // sampai, dan antrian mencoba lagi sendiri kalau gagal.
      unawaited(_kirimAntrian());

      return null;
    } finally {
      _sedangSibuk = false;
      notifyListeners();
    }
  }

  /// Berapa lama layar mau menunggu pengiriman yang dimintanya sendiri.
  ///
  /// Unggahannya sendiri boleh berjalan jauh lebih lama dari ini; yang dibatasi
  /// cuma lamanya sopir dibuat menatap tombol yang berputar. Lewat batas ini
  /// layar melapor apa adanya, dan pengiriman diteruskan di latar.
  static const Duration _batasTunggu = Duration(seconds: 20);

  /// Coba kirim ulang isi antrian atas permintaan driver.
  Future<String?> kirimUlang() async {
    _sedangSibuk = true;
    notifyListeners();

    try {
      return await _kirimAntrian().timeout(
        _batasTunggu,
        onTimeout: () =>
            'Masih dikirim. Boleh ditinggal, foto lanjut naik sendiri.',
      );
    } finally {
      _sedangSibuk = false;
      notifyListeners();
    }
  }

  Future<String?> _kirimAntrian() async {
    final terkirimBaru = await ServisAntrianFoto.kirimTertunda();

    await _muatTertunda(diam: true);

    // Daftar server diambil ulang agar foto yang barusan masuk pindah dari
    // penanda "menunggu" ke gambar sungguhan, lengkap dengan alamat hasil
    // reverse-geocode yang hanya dimiliki server.
    final hasil = await _repositori.daftar(ritId: ritId, itemId: itemId);
    if (hasil.sukses) _terkirim = hasil.data ?? [];

    notifyListeners();

    if (_tertunda.isEmpty) return null;

    return terkirimBaru > 0
        ? '$terkirimBaru foto terkirim, ${_tertunda.length} masih menunggu sinyal.'
        : _tertunda.first.pesanGagal ??
            'Foto tersimpan di HP dan akan dikirim saat sinyal kembali.';
  }

  Future<String?> hapus(int fotoId) async {
    _sedangSibuk = true;
    notifyListeners();

    final hasil = await _repositori.hapus(
      ritId: ritId,
      itemId: itemId,
      fotoId: fotoId,
    );

    _sedangSibuk = false;

    if (!hasil.sukses) {
      notifyListeners();
      return hasil.pesan;
    }

    _terkirim = _terkirim.where((f) => f.id != fotoId).toList();
    notifyListeners();
    return null;
  }

  /// Buang foto yang belum sempat terkirim, berikut berkasnya di HP.
  Future<void> buangTertunda(String clientUuid) async {
    await ServisAntrianFoto.buang(clientUuid);
    await _muatTertunda();
  }

  Future<void> _muatTertunda({bool diam = false}) async {
    _tertunda = await ServisAntrianFoto.untukTujuan(ritId, itemId);
    if (!diam) notifyListeners();
  }

  @override
  void notifyListeners() {
    if (_dibuang) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _dibuang = true;
    _langganan?.cancel();
    super.dispose();
  }
}
