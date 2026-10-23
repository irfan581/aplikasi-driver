import 'package:flutter/foundation.dart';

import '../../data/model/model_tugas.dart';
import '../../data/repositori/repositori_tugas.dart';

/// Riwayat rit driver, dimuat per halaman.
///
/// Dipisah dari [ProviderTugas] karena keadaannya beda jenis: tugas hari ini
/// selalu satu daftar utuh yang ditarik ulang, sedangkan riwayat bertambah
/// sedikit demi sedikit sambil digulir dan harus mengingat sudah sampai
/// halaman berapa.
class ProviderRiwayat extends ChangeNotifier {
  ProviderRiwayat([RepositoriTugas? repositori])
      : _repositori = repositori ?? RepositoriTugas();

  final RepositoriTugas _repositori;

  final List<ModelTugas> _rit = [];
  bool _sedangMemuat = false;
  bool _sedangMemuatLagi = false;
  bool _adaLagi = true;
  int _halaman = 0;
  int _total = 0;
  String? _pesanError;

  List<ModelTugas> get rit => List.unmodifiable(_rit);

  /// Pemuatan halaman pertama — layar menampilkan pemuat penuh.
  bool get sedangMemuat => _sedangMemuat;

  /// Pemuatan halaman lanjutan — daftar tetap tampil, pemuat kecil di kaki.
  bool get sedangMemuatLagi => _sedangMemuatLagi;

  bool get adaLagi => _adaLagi;
  int get total => _total;
  String? get pesanError => _pesanError;

  bool get kosong => !_sedangMemuat && _rit.isEmpty && _pesanError == null;

  /// Muat dari awal. Dipakai saat layar dibuka dan saat ditarik untuk
  /// menyegarkan — keduanya harus membuang isi lama, bukan menumpuk.
  Future<void> muat() async {
    if (_sedangMemuat) return;

    _sedangMemuat = true;
    _pesanError = null;
    notifyListeners();

    final hasil = await _repositori.riwayat(halaman: 1);

    _sedangMemuat = false;

    if (!hasil.sukses || hasil.data == null) {
      _pesanError = hasil.pesan;
      notifyListeners();
      return;
    }

    _rit
      ..clear()
      ..addAll(hasil.data!.rit);
    _halaman = hasil.data!.halaman;
    _adaLagi = hasil.data!.adaLagi;
    _total = hasil.data!.total;
    notifyListeners();
  }

  /// Muat halaman berikutnya. Aman dipanggil berkali-kali saat menggulir:
  /// permintaan yang sedang berjalan atau halaman yang sudah habis diabaikan.
  Future<void> muatLagi() async {
    if (_sedangMemuat || _sedangMemuatLagi || !_adaLagi) return;

    _sedangMemuatLagi = true;
    notifyListeners();

    final hasil = await _repositori.riwayat(halaman: _halaman + 1);

    _sedangMemuatLagi = false;

    if (!hasil.sukses || hasil.data == null) {
      // Kegagalan halaman lanjutan tidak menghapus yang sudah tampil —
      // driver tetap bisa membaca riwayat yang sudah termuat.
      _pesanError = hasil.pesan;
      notifyListeners();
      return;
    }

    _rit.addAll(hasil.data!.rit);
    _halaman = hasil.data!.halaman;
    _adaLagi = hasil.data!.adaLagi;
    _total = hasil.data!.total;
    _pesanError = null;
    notifyListeners();
  }

  void bersihkan() {
    _rit.clear();
    _halaman = 0;
    _adaLagi = true;
    _total = 0;
    _pesanError = null;
    notifyListeners();
  }
}
