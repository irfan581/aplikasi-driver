import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

import '../../inti/konstanta/konstanta_api.dart';
import '../model/model_driver.dart';
import '../servis/hasil_api.dart';
import '../servis/servis_api.dart';
import '../servis/servis_penyimpanan_aman.dart';

class RepositoriAuth {
  Future<HasilApi<ModelDriver>> login({
    required String kodeDriver,
    required String password,
  }) async {
    final hasil = await ServisApi.post(KonstantaApi.login, {
      'kode_driver': kodeDriver.trim().toUpperCase(),
      'password': password,
      'device_id': await _deviceId(),
    });

    if (!hasil.sukses) {
      return HasilApi.gagal(hasil.pesan,
          kode: hasil.kode, offline: hasil.offline);
    }

    final data = hasil.data as Map<String, dynamic>;
    final driver = ModelDriver.fromJson(data['driver'] as Map<String, dynamic>);

    await ServisPenyimpananAman.simpanSesi(
      token: data['token'].toString(),
      driverId: driver.id,
      nama: driver.namaDriver,
      kodeDriver: driver.kodeDriver,
      harusGantiPassword: data['harus_ganti_password'] == true,
    );

    return HasilApi.sukses(driver, hasil.pesan);
  }

  Future<HasilApi<ModelDriver>> profil() async {
    final hasil = await ServisApi.get(KonstantaApi.profil);

    if (!hasil.sukses) {
      return HasilApi.gagal(hasil.pesan,
          kode: hasil.kode, offline: hasil.offline);
    }

    return HasilApi.sukses(
      ModelDriver.fromJson(hasil.data as Map<String, dynamic>),
    );
  }

  Future<HasilApi<void>> gantiPassword({
    required String passwordLama,
    required String passwordBaru,
  }) async {
    final hasil = await ServisApi.post(KonstantaApi.gantiPassword, {
      'password_lama': passwordLama,
      'password_baru': passwordBaru,
      'password_baru_confirmation': passwordBaru,
    });

    if (hasil.sukses) {
      await ServisPenyimpananAman.tandaiPasswordSudahDiganti();
      return HasilApi.sukses(null, hasil.pesan);
    }

    return HasilApi.gagal(hasil.pesan,
        kode: hasil.kode, offline: hasil.offline);
  }

  /// Logout tetap membersihkan sesi lokal walau panggilan ke server gagal —
  /// driver yang menekan keluar harus benar-benar keluar dari HP-nya.
  Future<void> logout() async {
    try {
      await ServisApi.post(KonstantaApi.logout);
    } finally {
      ServisApi.batalkanSemuaRequest();
      await ServisPenyimpananAman.hapusSesi();
    }
  }

  /// Dipakai server untuk mengikat satu akun ke satu HP.
  Future<String?> _deviceId() async {
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) return (await info.androidInfo).id;
      if (Platform.isIOS) return (await info.iosInfo).identifierForVendor;
    } catch (_) {
      // Gagal membaca identitas perangkat tidak boleh menggagalkan login.
    }
    return null;
  }
}
