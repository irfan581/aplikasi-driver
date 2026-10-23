import '../../inti/konstanta/konstanta_api.dart';
import '../model/model_chat.dart';
import '../servis/hasil_api.dart';
import '../servis/servis_api.dart';

/// Akses grup chat laporan dari aplikasi sopir.
///
/// Hanya jalur grup: sopir tidak punya daftar kontak dan server menolak
/// percakapan pribadi dari token driver.
class RepositoriChat {
  Future<HasilApi<List<ModelGrupChat>>> grup() async {
    final hasil = await ServisApi.get(KonstantaApi.chatGrup);

    if (!hasil.sukses) {
      return HasilApi.gagal(hasil.pesan,
          kode: hasil.kode, offline: hasil.offline);
    }

    final daftar = (hasil.data as List? ?? [])
        .map((e) => ModelGrupChat.fromJson(e as Map<String, dynamic>))
        .toList();

    return HasilApi.sukses(daftar);
  }

  /// Halaman 1 berisi pesan terbaru. Halaman berikutnya menggali ke belakang,
  /// mengikuti cara server memaginasi (terbaru dulu, lalu dibalik).
  Future<HasilApi<List<ModelPesanChat>>> pesan(int grupId,
      {int halaman = 1}) async {
    final hasil =
        await ServisApi.get('${KonstantaApi.chatPesan(grupId)}?page=$halaman');

    if (!hasil.sukses) {
      return HasilApi.gagal(hasil.pesan,
          kode: hasil.kode, offline: hasil.offline);
    }

    final daftar = (hasil.data as List? ?? [])
        .map((e) => ModelPesanChat.fromJson(e as Map<String, dynamic>))
        .toList();

    return HasilApi.sukses(daftar);
  }

  Future<HasilApi<ModelPesanChat>> kirimTeks(int grupId, String teks) async {
    final hasil = await ServisApi.post(KonstantaApi.chatKirim, {
      'type': 'group',
      'contact_id': grupId,
      'message': teks,
      'message_type': 'text',
    });

    if (!hasil.sukses) {
      return HasilApi.gagal(hasil.pesan,
          kode: hasil.kode, offline: hasil.offline);
    }

    return HasilApi.sukses(_dariBalasanKirim(hasil.data, teks));
  }

  Future<HasilApi<ModelPesanChat>> kirimFoto(int grupId, String path,
      {String teks = ''}) async {
    final hasil = await ServisApi.unggah(
      KonstantaApi.chatKirim,
      namaField: 'file',
      path: path,
      kolom: {
        'type': 'group',
        'contact_id': grupId,
        'message': teks,
      },
    );

    if (!hasil.sukses) {
      return HasilApi.gagal(hasil.pesan,
          kode: hasil.kode, offline: hasil.offline);
    }

    return HasilApi.sukses(_dariBalasanKirim(hasil.data, teks));
  }

  /// Balasan kirim hanya membawa sebagian kolom — tanpa nama pengirim dan
  /// tanpa penanda "saya". Keduanya diisi di sini karena yang barusan
  /// mengirim sudah pasti sopir yang sedang login.
  ModelPesanChat _dariBalasanKirim(dynamic data, String teksAsli) {
    final json = (data as Map?)?.cast<String, dynamic>() ?? const {};

    return ModelPesanChat(
      id: (json['id'] as num?)?.toInt() ?? 0,
      namaPengirim: 'Saya',
      dariSaya: true,
      jenis: json['message_type']?.toString() ?? 'text',
      pesan: json['message']?.toString() ?? teksAsli,
      waktu: json['time']?.toString() ?? '',
      urlBerkas: json['file_url']?.toString(),
      urlThumb: json['thumb_url']?.toString(),
      dikirimSopir: true,
    );
  }
}
