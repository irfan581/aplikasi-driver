import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/model/model_driver.dart';
import '../../data/repositori/repositori_auth.dart';
import '../../data/servis/servis_notifikasi.dart';
import '../../data/servis/servis_penyimpanan_aman.dart';

enum StatusSesi { memeriksa, masuk, perluGantiPassword, keluar }

class ProviderAuth extends ChangeNotifier {
  ProviderAuth([RepositoriAuth? repositori])
      : _repositori = repositori ?? RepositoriAuth();

  final RepositoriAuth _repositori;

  StatusSesi _status = StatusSesi.memeriksa;
  ModelDriver? _driver;
  String? _namaTersimpan;
  bool _sedangProses = false;
  String? _pesanError;

  StatusSesi get status => _status;
  ModelDriver? get driver => _driver;
  bool get sedangProses => _sedangProses;
  String? get pesanError => _pesanError;

  /// Nama untuk sapaan sebelum profil lengkap termuat dari server.
  String get namaSapaan => _driver?.namaSapaan ?? _namaTersimpan ?? 'Driver';

  /// Memeriksa sesi tanpa memanggil jaringan lebih dulu, supaya driver di
  /// daerah bersinyal buruk tidak terlempar ke layar login hanya karena
  /// permintaan profil gagal.
  Future<void> periksaSesi() async {
    final token = await ServisPenyimpananAman.ambilToken();

    if (token == null) {
      _ubahStatus(StatusSesi.keluar);
      return;
    }

    _namaTersimpan = await ServisPenyimpananAman.ambilNama();

    if (await ServisPenyimpananAman.harusGantiPassword()) {
      _ubahStatus(StatusSesi.perluGantiPassword);
    } else {
      _ubahStatus(StatusSesi.masuk);
    }

    // Sengaja TIDAK ditunggu. Status sesi sudah pasti begitu token terbaca,
    // jadi menahan pemanggil demi permintaan jaringan hanya membuat splash
    // menggantung selama driver berada di daerah bersinyal buruk — sampai
    // sepuluh detik penuh sebelum timeout, hanya untuk menyegarkan nama yang
    // sudah tersimpan.
    //
    // Kegagalannya tidak boleh mengeluarkan driver; token yang benar-benar
    // mati sudah ditangani interceptor 401.
    unawaited(muatProfil());

    // Diulang tiap aplikasi dibuka: token FCM bisa berganti.
    unawaited(ServisNotifikasi.daftarkanPerangkat());
  }

  /// Dipanggil lagi dari layar Profil kalau percobaan pertama di splash
  /// gagal (mis. sinyal sempat hilang) — tanpa ini, [_driver] tetap null
  /// selamanya dan layar Profil terjebak di "Memuat data akun..." sampai
  /// aplikasi ditutup-buka ulang, karena splash cuma mencoba sekali.
  Future<void> muatProfil() async {
    final hasil = await _repositori.profil();
    if (hasil.sukses && hasil.data != null) {
      _driver = hasil.data;
      notifyListeners();
    }
  }

  Future<bool> login(String kodeDriver, String password) async {
    _mulaiProses();

    final hasil = await _repositori.login(
      kodeDriver: kodeDriver,
      password: password,
    );

    _sedangProses = false;

    if (!hasil.sukses) {
      _pesanError = hasil.pesan;
      notifyListeners();
      return false;
    }

    _driver = hasil.data;
    _namaTersimpan = _driver?.namaDriver;
    _status = _driver?.harusGantiPassword == true
        ? StatusSesi.perluGantiPassword
        : StatusSesi.masuk;

    unawaited(ServisNotifikasi.daftarkanPerangkat());

    notifyListeners();
    return true;
  }

  Future<bool> gantiPassword(String passwordLama, String passwordBaru) async {
    _mulaiProses();

    final hasil = await _repositori.gantiPassword(
      passwordLama: passwordLama,
      passwordBaru: passwordBaru,
    );

    _sedangProses = false;

    if (!hasil.sukses) {
      _pesanError = hasil.pesan;
      notifyListeners();
      return false;
    }

    _ubahStatus(StatusSesi.masuk);
    return true;
  }

  Future<void> logout() async {
    await _repositori.logout();
    _driver = null;
    _ubahStatus(StatusSesi.keluar);
  }

  /// Dipanggil interceptor saat token ditolak server.
  void paksaKeluar() {
    _driver = null;
    _ubahStatus(StatusSesi.keluar);
  }

  void bersihkanError() {
    if (_pesanError == null) return;
    _pesanError = null;
    notifyListeners();
  }

  void _mulaiProses() {
    _sedangProses = true;
    _pesanError = null;
    notifyListeners();
  }

  void _ubahStatus(StatusSesi status) {
    _status = status;
    notifyListeners();
  }
}
