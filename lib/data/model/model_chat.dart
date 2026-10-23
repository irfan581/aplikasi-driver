/// Pesan dan grup chat, versi yang dipakai aplikasi sopir.
///
/// Jauh lebih ringkas daripada model di aplikasi sales: reaksi emoji, polling,
/// pin, bintang, teruskan, dan mention sengaja tidak dibawa. Sopir memakai
/// grup ini untuk membaca laporan yang masuk dan menyahut seperlunya, bukan
/// untuk mengelola percakapan.
class ModelGrupChat {
  const ModelGrupChat({
    required this.id,
    required this.nama,
    required this.jumlahAnggota,
    required this.belumDibaca,
    this.pesanTerakhir,
    this.waktuTerakhir,
  });

  final int id;
  final String nama;
  final int jumlahAnggota;
  final int belumDibaca;
  final String? pesanTerakhir;
  final String? waktuTerakhir;

  factory ModelGrupChat.fromJson(Map<String, dynamic> json) => ModelGrupChat(
        id: (json['id'] as num).toInt(),
        nama: json['nama']?.toString() ?? 'Grup',
        jumlahAnggota: (json['member_count'] as num?)?.toInt() ?? 0,
        belumDibaca: (json['unread'] as num?)?.toInt() ?? 0,
        pesanTerakhir: json['last_message']?.toString(),
        waktuTerakhir: json['last_time']?.toString(),
      );
}

class ModelPesanChat {
  const ModelPesanChat({
    required this.id,
    required this.namaPengirim,
    required this.dariSaya,
    required this.jenis,
    required this.pesan,
    required this.waktu,
    this.urlBerkas,
    this.urlThumb,
    this.dikirimSopir = false,
  });

  final int id;
  final String namaPengirim;
  final bool dariSaya;

  /// 'text', 'image', atau 'file'. Jenis lain (mis. polling dari aplikasi
  /// sales) tetap ditampilkan sebagai teks apa adanya, bukan disembunyikan —
  /// sopir perlu tahu ada sesuatu di sana walau tidak bisa ikut menjawabnya.
  final String jenis;

  final String pesan;
  final String waktu;
  final String? urlBerkas;

  /// Versi kecil dari [urlBerkas]. Server mengirimkannya untuk foto laporan
  /// bongkar; gambar chat biasa tidak punya, dan pesan lama juga belum.
  final String? urlThumb;

  /// Yang dimuat gelembung chat. Lebarnya cuma 300px, jadi thumbnail sudah
  /// cukup — pratinjau layar penuh yang memakai [urlBerkas].
  String? get urlGelembung =>
      (urlThumb == null || urlThumb!.isEmpty) ? urlBerkas : urlThumb;

  /// Dipakai untuk membedakan tampilan laporan bongkar dari obrolan biasa.
  final bool dikirimSopir;

  bool get gambar => jenis == 'image' && (urlBerkas?.isNotEmpty ?? false);

  factory ModelPesanChat.fromJson(Map<String, dynamic> json) => ModelPesanChat(
        id: (json['id'] as num?)?.toInt() ?? 0,
        namaPengirim: json['sender_name']?.toString() ?? 'Tidak dikenal',
        dariSaya: json['is_me'] == true,
        jenis: json['message_type']?.toString() ?? 'text',
        pesan: json['message']?.toString() ?? '',
        waktu: json['time']?.toString() ?? '',
        urlBerkas: json['file_url']?.toString(),
        urlThumb: json['thumb_url']?.toString(),
        dikirimSopir: json['sender_role']?.toString() == 'sopir',
      );

  /// Siaran realtime selalu mengirim is_me = false — satu siaran dibaca
  /// banyak orang — jadi penandanya ditentukan ulang di aplikasi.
  ModelPesanChat salinDariSaya(bool nilai) => ModelPesanChat(
        id: id,
        namaPengirim: namaPengirim,
        dariSaya: nilai,
        jenis: jenis,
        pesan: pesan,
        waktu: waktu,
        urlBerkas: urlBerkas,
        urlThumb: urlThumb,
        dikirimSopir: dikirimSopir,
      );

  ModelPesanChat salin({int? id, String? waktu}) => ModelPesanChat(
        id: id ?? this.id,
        namaPengirim: namaPengirim,
        dariSaya: dariSaya,
        jenis: jenis,
        pesan: pesan,
        waktu: waktu ?? this.waktu,
        urlBerkas: urlBerkas,
        urlThumb: urlThumb,
        dikirimSopir: dikirimSopir,
      );
}
