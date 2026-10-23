import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Penyimpanan kredensial driver. Token disimpan terenkripsi dan juga
/// di-cache di memori supaya tiap request tidak membaca storage.
class ServisPenyimpananAman {
  ServisPenyimpananAman._();

  // Sejak flutter_secure_storage v10, enkripsi Android sudah bawaan dan
  // opsi encryptedSharedPreferences ditinggalkan.
  static const _storage = FlutterSecureStorage();

  // Prefiks drv_ supaya tidak pernah bentrok dengan aplikasi lain di HP yang
  // sama, termasuk aplikasi presensi sales.
  static const _kToken = 'drv_auth_token';
  static const _kDriverId = 'drv_id';
  static const _kNama = 'drv_nama';
  static const _kKode = 'drv_kode';
  static const _kWaktuLogin = 'drv_waktu_login';
  static const _kHarusGantiPassword = 'drv_harus_ganti_password';
  static const _kKodeTerakhir = 'drv_kode_terakhir';

  static String? _cacheToken;
  static bool _sudahBaca = false;

  static Future<void> simpanSesi({
    required String token,
    required int driverId,
    required String nama,
    required String kodeDriver,
    required bool harusGantiPassword,
  }) async {
    _cacheToken = token;
    _sudahBaca = true;

    await Future.wait([
      _storage.write(key: _kToken, value: token),
      _storage.write(key: _kDriverId, value: driverId.toString()),
      _storage.write(key: _kNama, value: nama),
      _storage.write(key: _kKode, value: kodeDriver),
      _storage.write(key: _kKodeTerakhir, value: kodeDriver),
      _storage.write(
          key: _kWaktuLogin, value: DateTime.now().toIso8601String()),
      _storage.write(
        key: _kHarusGantiPassword,
        value: harusGantiPassword.toString(),
      ),
    ]);
  }

  // Tanpa batas jam: sesi hanya berakhir lewat logout atau 401 dari server.
  static Future<String?> ambilToken() async {
    if (_sudahBaca) return _cacheToken;

    _cacheToken = await _storage.read(key: _kToken);
    _sudahBaca = true;

    return _cacheToken;
  }

  static Future<int?> ambilDriverId() async =>
      int.tryParse(await _storage.read(key: _kDriverId) ?? '');

  static Future<String?> ambilNama() => _storage.read(key: _kNama);

  static Future<String?> ambilKode() => _storage.read(key: _kKode);

  /// Kode driver yang terakhir dipakai login, untuk mengisi otomatis kolom
  /// login. Sengaja tidak ikut terhapus saat logout.
  static Future<String?> ambilKodeTerakhir() =>
      _storage.read(key: _kKodeTerakhir);

  static Future<bool> harusGantiPassword() async =>
      (await _storage.read(key: _kHarusGantiPassword)) == 'true';

  static Future<void> tandaiPasswordSudahDiganti() =>
      _storage.write(key: _kHarusGantiPassword, value: 'false');

  static Future<void> hapusToken() async {
    _cacheToken = null;
    _sudahBaca = true;
    await _storage.delete(key: _kToken);
  }

  static Future<void> hapusSesi() async {
    _cacheToken = null;
    _sudahBaca = true;

    // Kode terakhir sengaja dipertahankan supaya driver tidak perlu
    // mengetiknya lagi setiap kali masuk.
    await Future.wait([
      _storage.delete(key: _kToken),
      _storage.delete(key: _kDriverId),
      _storage.delete(key: _kNama),
      _storage.delete(key: _kKode),
      _storage.delete(key: _kWaktuLogin),
      _storage.delete(key: _kHarusGantiPassword),
    ]);
  }
}
