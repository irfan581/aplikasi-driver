import 'dart:convert';

/// Satu foto bukti bongkar yang sudah diterima server.
class ModelFotoBongkar {
  const ModelFotoBongkar({
    required this.id,
    required this.clientUuid,
    required this.jenis,
    required this.fotoUrl,
    required this.statusProses,
    this.thumbUrl,
    this.catatan,
    this.alamat,
    this.latitude,
    this.longitude,
    this.selisihWaktuDetik,
    this.diambilPada,
  });

  final int id;
  final String clientUuid;
  final String jenis;
  final String fotoUrl;

  /// Versi 320px dari [fotoUrl]. Kosong untuk foto lama yang belum pernah
  /// dilewati `bongkar:thumbnail` — [urlPetak] yang menanganinya.
  final String? thumbUrl;

  /// Yang dipakai petak kecil di daftar foto. Layar penuh tetap memakai
  /// [fotoUrl]: petaknya cuma sepertiga layar, tapi buktinya perlu dibaca.
  String get urlPetak =>
      (thumbUrl == null || thumbUrl!.isEmpty) ? fotoUrl : thumbUrl!;

  /// `temp` selama job belum memindahkan berkasnya, `siap` setelah pindah,
  /// `gagal` bila berkasnya hilang di server.
  final String statusProses;

  /// Server menerima barisnya tapi kehilangan berkasnya. Driver perlu tahu:
  /// foto ini tetap terhitung ada oleh aturan FOTO_WAJIB, padahal admin tidak
  /// akan menemukan gambar apa pun di baliknya.
  bool get gagalProses => statusProses == 'gagal';

  final String? catatan;
  final String? alamat;
  final double? latitude;
  final double? longitude;

  /// Selisih jam HP dengan jam server menurut server sendiri.
  final int? selisihWaktuDetik;

  final DateTime? diambilPada;

  bool get adaKoordinat => latitude != null && longitude != null;

  /// Ambang yang dianggap perlu ditegur. Di bawah ini selisihnya wajar untuk
  /// jeda unggah, di atasnya jam HP driver memang meleset dan bukti bongkarnya
  /// akan terlihat janggal di mata admin.
  bool get jamMeleset =>
      selisihWaktuDetik != null && selisihWaktuDetik!.abs() > 300;

  factory ModelFotoBongkar.fromJson(Map<String, dynamic> json) =>
      ModelFotoBongkar(
        id: json['id'] as int,
        clientUuid: json['client_uuid']?.toString() ?? '',
        jenis: json['jenis']?.toString() ?? 'bongkar',
        fotoUrl: json['foto_url']?.toString() ?? '',
        thumbUrl: json['thumb_url']?.toString(),
        statusProses: json['status_proses']?.toString() ?? 'siap',
        catatan: json['catatan']?.toString(),
        alamat: json['alamat']?.toString(),
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        selisihWaktuDetik: (json['selisih_waktu_detik'] as num?)?.toInt(),
        diambilPada: DateTime.tryParse(json['diambil_pada']?.toString() ?? ''),
      );
}

/// Foto yang sudah dijepret tapi belum sampai ke server.
///
/// Isinya dibuat bisa diubah jadi JSON karena antrian bertahan di
/// SharedPreferences: driver bisa menjepret di daerah tanpa sinyal, menutup
/// aplikasi, dan fotonya tetap terkirim setelah sinyal kembali.
class FotoTertunda {
  const FotoTertunda({
    required this.clientUuid,
    required this.ritId,
    required this.itemId,
    required this.path,
    required this.dibuatPada,
    this.jenis = 'bongkar',
    this.catatan,
    this.latitude,
    this.longitude,
    this.akurasi,
    this.palsu = false,
    this.percobaan = 0,
    this.pesanGagal,
  });

  final String clientUuid;
  final int ritId;
  final int itemId;

  /// Path berkas di penyimpanan aplikasi. Yang diantrikan path-nya, bukan isi
  /// fotonya, supaya proses yang dimatikan Android tidak membawa foto ikut
  /// hilang bersama memori.
  final String path;

  final DateTime dibuatPada;
  final String jenis;
  final String? catatan;
  final double? latitude;
  final double? longitude;
  final double? akurasi;
  final bool palsu;

  final int percobaan;

  /// Alasan kegagalan terakhir, ditampilkan agar driver tahu fotonya tertahan
  /// karena apa alih-alih hanya melihat penanda "menunggu" selamanya.
  final String? pesanGagal;

  FotoTertunda salin({int? percobaan, String? pesanGagal}) => FotoTertunda(
        clientUuid: clientUuid,
        ritId: ritId,
        itemId: itemId,
        path: path,
        dibuatPada: dibuatPada,
        jenis: jenis,
        catatan: catatan,
        latitude: latitude,
        longitude: longitude,
        akurasi: akurasi,
        palsu: palsu,
        percobaan: percobaan ?? this.percobaan,
        pesanGagal: pesanGagal,
      );

  /// Kolom yang ikut dikirim bersama berkas fotonya.
  Map<String, dynamic> toKolom() => {
        'client_uuid': clientUuid,
        'jenis': jenis,
        if (catatan != null && catatan!.isNotEmpty) 'catatan': catatan,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (akurasi != null) 'accuracy': akurasi,
        'is_mock': palsu ? 1 : 0,
        'diambil_pada': dibuatPada.toIso8601String(),
      };

  Map<String, dynamic> toJson() => {
        'client_uuid': clientUuid,
        'rit_id': ritId,
        'item_id': itemId,
        'path': path,
        'dibuat_pada': dibuatPada.toIso8601String(),
        'jenis': jenis,
        'catatan': catatan,
        'latitude': latitude,
        'longitude': longitude,
        'akurasi': akurasi,
        'palsu': palsu,
        'percobaan': percobaan,
        'pesan_gagal': pesanGagal,
      };

  factory FotoTertunda.fromJson(Map<String, dynamic> json) => FotoTertunda(
        clientUuid: json['client_uuid']?.toString() ?? '',
        ritId: (json['rit_id'] as num?)?.toInt() ?? 0,
        itemId: (json['item_id'] as num?)?.toInt() ?? 0,
        path: json['path']?.toString() ?? '',
        dibuatPada: DateTime.tryParse(json['dibuat_pada']?.toString() ?? '') ??
            DateTime.now(),
        jenis: json['jenis']?.toString() ?? 'bongkar',
        catatan: json['catatan']?.toString(),
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        akurasi: (json['akurasi'] as num?)?.toDouble(),
        palsu: json['palsu'] == true,
        percobaan: (json['percobaan'] as num?)?.toInt() ?? 0,
        pesanGagal: json['pesan_gagal']?.toString(),
      );

  static String encode(List<FotoTertunda> daftar) =>
      jsonEncode(daftar.map((e) => e.toJson()).toList());

  static List<FotoTertunda> decode(String mentah) {
    final isi = jsonDecode(mentah);
    if (isi is! List) return const [];

    return isi
        .whereType<Map<String, dynamic>>()
        .map(FotoTertunda.fromJson)
        .toList();
  }
}
