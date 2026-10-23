import '../../inti/konstanta/konstanta_api.dart';
import '../model/model_ringkasan.dart';
import '../model/model_tugas.dart';
import '../servis/hasil_api.dart';
import '../servis/servis_api.dart';

/// Satu halaman riwayat rit beserta penanda apakah masih ada lanjutannya.
class HalamanRiwayat {
  const HalamanRiwayat({
    required this.rit,
    required this.halaman,
    required this.adaLagi,
    required this.total,
  });

  final List<ModelTugas> rit;
  final int halaman;
  final bool adaLagi;
  final int total;
}

class RepositoriTugas {
  Future<HasilApi<List<ModelTugas>>> hariIni({String? tanggal}) async {
    final endpoint = tanggal == null
        ? KonstantaApi.tugasHariIni
        : '${KonstantaApi.tugasHariIni}?tanggal=$tanggal';

    final hasil = await ServisApi.get(endpoint);

    if (!hasil.sukses) {
      return HasilApi.gagal(hasil.pesan,
          kode: hasil.kode, offline: hasil.offline);
    }

    final data = hasil.data as Map<String, dynamic>;
    final rit = (data['rit'] as List? ?? [])
        .map((e) => ModelTugas.fromJson(e as Map<String, dynamic>))
        .toList();

    return HasilApi.sukses(rit);
  }

  Future<HasilApi<ModelRingkasan>> ringkasan(
      {String? dari, String? sampai}) async {
    final param = <String>[
      if (dari != null) 'dari=$dari',
      if (sampai != null) 'sampai=$sampai',
    ];

    final endpoint = param.isEmpty
        ? KonstantaApi.ringkasan
        : '${KonstantaApi.ringkasan}?${param.join('&')}';

    final hasil = await ServisApi.get(endpoint);

    if (!hasil.sukses) {
      return HasilApi.gagal(hasil.pesan,
          kode: hasil.kode, offline: hasil.offline);
    }

    return HasilApi.sukses(
        ModelRingkasan.fromJson(hasil.data as Map<String, dynamic>));
  }

  /// Satu halaman riwayat rit. [halaman] dimulai dari 1.
  ///
  /// Mengembalikan daftar rit beserta penanda apakah masih ada halaman
  /// berikutnya — pemanggil tidak perlu tahu bentuk objek paginasi server.
  Future<HasilApi<HalamanRiwayat>> riwayat({int halaman = 1}) async {
    final hasil = await ServisApi.get(
      '${KonstantaApi.riwayat}?page=$halaman',
    );

    if (!hasil.sukses) {
      return HasilApi.gagal(hasil.pesan,
          kode: hasil.kode, offline: hasil.offline);
    }

    final data = hasil.data as Map<String, dynamic>;
    final rit = (data['rit'] as List? ?? [])
        .map((e) => ModelTugas.fromJson(e as Map<String, dynamic>))
        .toList();

    final paginasi = data['pagination'] as Map<String, dynamic>? ?? const {};
    final halamanIni = (paginasi['current_page'] as num?)?.toInt() ?? halaman;
    final halamanAkhir = (paginasi['last_page'] as num?)?.toInt() ?? halamanIni;

    return HasilApi.sukses(HalamanRiwayat(
      rit: rit,
      halaman: halamanIni,
      adaLagi: halamanIni < halamanAkhir,
      total: (paginasi['total'] as num?)?.toInt() ?? rit.length,
    ));
  }

  Future<HasilApi<ModelTugas>> detail(int id) async {
    final hasil = await ServisApi.get(KonstantaApi.tugasDetail(id));

    if (!hasil.sukses) {
      return HasilApi.gagal(hasil.pesan,
          kode: hasil.kode, offline: hasil.offline);
    }

    return HasilApi.sukses(
        ModelTugas.fromJson(hasil.data as Map<String, dynamic>));
  }

  /// Menutup satu tujuan dengan laporan driver.
  ///
  /// Fotonya sudah lebih dulu diunggah lewat antrian; yang dikirim di sini
  /// tinggal keputusan dan keterangannya. Tidak diulang otomatis kalau gagal —
  /// server menolak laporan kedua untuk tujuan yang sama, dan mengulangnya
  /// diam-diam cuma membuat driver melihat kegagalan atas sesuatu yang
  /// sebenarnya sudah tersimpan.
  Future<HasilApi<ModelTugasItem>> kirimLaporan({
    required int ritId,
    required int itemId,
    required String status,
    required String catatan,
    double? latitude,
    double? longitude,
  }) async {
    final hasil = await ServisApi.post(
      KonstantaApi.laporanTujuan(ritId, itemId),
      {
        'status': status,
        'catatan': catatan,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      },
    );

    if (!hasil.sukses) {
      return HasilApi.gagal(hasil.pesan,
          kode: hasil.kode, offline: hasil.offline);
    }

    return HasilApi.sukses(
      ModelTugasItem.fromJson(hasil.data as Map<String, dynamic>),
      hasil.pesan,
    );
  }
}
