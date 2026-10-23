import '../../inti/konstanta/konstanta_api.dart';
import '../model/model_foto_bongkar.dart';
import '../servis/hasil_api.dart';
import '../servis/servis_api.dart';

class RepositoriFotoBongkar {
  Future<HasilApi<List<ModelFotoBongkar>>> daftar({
    required int ritId,
    required int itemId,
  }) async {
    final hasil = await ServisApi.get(KonstantaApi.fotoBongkar(ritId, itemId));

    if (!hasil.sukses) {
      return HasilApi.gagal(hasil.pesan,
          kode: hasil.kode, offline: hasil.offline);
    }

    final foto = (hasil.data as List? ?? [])
        .map((e) => ModelFotoBongkar.fromJson(e as Map<String, dynamic>))
        .toList();

    return HasilApi.sukses(foto);
  }

  /// Mengirim satu foto dari antrian.
  ///
  /// Server menjawab foto yang sama bila `client_uuid`-nya sudah pernah masuk,
  /// jadi pengiriman ulang aman dan tidak perlu dijaga di sisi aplikasi.
  Future<HasilApi<ModelFotoBongkar>> unggah(FotoTertunda foto) async {
    final hasil = await ServisApi.unggah(
      KonstantaApi.fotoBongkar(foto.ritId, foto.itemId),
      namaField: 'foto',
      path: foto.path,
      kolom: foto.toKolom(),
    );

    if (!hasil.sukses) {
      return HasilApi.gagal(hasil.pesan,
          kode: hasil.kode, offline: hasil.offline);
    }

    return HasilApi.sukses(
      ModelFotoBongkar.fromJson(hasil.data as Map<String, dynamic>),
      hasil.pesan,
    );
  }

  Future<HasilApi<void>> hapus({
    required int ritId,
    required int itemId,
    required int fotoId,
  }) async {
    final hasil = await ServisApi.delete(
        KonstantaApi.hapusFotoBongkar(ritId, itemId, fotoId));

    if (!hasil.sukses) {
      return HasilApi.gagal(hasil.pesan,
          kode: hasil.kode, offline: hasil.offline);
    }

    return HasilApi.sukses(null, hasil.pesan);
  }
}
