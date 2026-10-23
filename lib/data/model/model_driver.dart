class ModelKendaraan {
  const ModelKendaraan({
    required this.id,
    required this.nomorPolisi,
    this.jenis,
    this.kapasitasTon,
  });

  final int id;
  final String nomorPolisi;
  final String? jenis;
  final double? kapasitasTon;

  factory ModelKendaraan.fromJson(Map<String, dynamic> json) => ModelKendaraan(
        id: json['id'] as int,
        nomorPolisi: json['nomor_polisi']?.toString() ?? '-',
        jenis: json['jenis']?.toString(),
        kapasitasTon: (json['kapasitas_ton'] as num?)?.toDouble(),
      );
}

class ModelDriver {
  const ModelDriver({
    required this.id,
    required this.kodeDriver,
    required this.namaDriver,
    this.namaPanggilan,
    this.noTelepon,
    this.alamat,
    this.jenisSim,
    this.harusGantiPassword = false,
    this.nomorAdmin,
    this.kendaraan = const [],
  });

  final int id;
  final String kodeDriver;
  final String namaDriver;
  final String? namaPanggilan;
  final String? noTelepon;
  final String? alamat;
  final String? jenisSim;
  final bool harusGantiPassword;

  /// Nomor kantor yang bisa ditelepon driver saat ada tujuan bermasalah.
  /// Datang dari server, bukan dipaku di aplikasi, supaya bisa diganti tanpa
  /// membangun ulang APK. Kosong berarti tombol teleponnya disembunyikan.
  final String? nomorAdmin;

  /// [nomorAdmin] dalam bentuk yang diterima wa.me.
  ///
  /// Nomor disimpan dalam bentuk internasional (+62...) supaya bisa dipakai
  /// apa adanya oleh penelepon. wa.me hanya menerima angka, jadi tanda plus,
  /// spasi, dan tanda hubung dibuang. Nomor yang masih ditulis diawali 0 ikut
  /// diubah ke 62 — kalau tidak, WhatsApp membacanya sebagai nomor luar
  /// negeri dan gagal membuka percakapan.
  ///
  /// Null kalau kantor belum mengisi nomornya; pemanggil menyembunyikan
  /// tombolnya, bukan menampilkan tombol yang tidak berbuat apa-apa.
  String? get nomorAdminWa {
    final mentah = nomorAdmin;
    if (mentah == null || mentah.isEmpty) return null;

    var angka = mentah.replaceAll(RegExp(r'[^0-9]'), '');
    if (angka.isEmpty) return null;
    if (angka.startsWith('0')) angka = '62${angka.substring(1)}';

    return angka;
  }

  final List<ModelKendaraan> kendaraan;

  /// Nama panggilan lebih akrab dipakai di sapaan beranda.
  String get namaSapaan =>
      (namaPanggilan?.trim().isNotEmpty ?? false) ? namaPanggilan! : namaDriver;

  factory ModelDriver.fromJson(Map<String, dynamic> json) => ModelDriver(
        id: json['id'] as int,
        kodeDriver: json['kode_driver']?.toString() ?? '',
        namaDriver: json['nama_driver']?.toString() ?? '',
        namaPanggilan: json['nama_panggilan']?.toString(),
        noTelepon: json['no_telepon']?.toString(),
        alamat: json['alamat']?.toString(),
        jenisSim: json['jenis_sim']?.toString(),
        harusGantiPassword: json['harus_ganti_password'] == true,
        nomorAdmin: json['nomor_admin']?.toString(),
        kendaraan: (json['kendaraan'] as List?)
                ?.map((e) => ModelKendaraan.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}
