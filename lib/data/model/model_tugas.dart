import 'model_driver.dart';

class ModelTugasItem {
  const ModelTugasItem({
    required this.id,
    required this.urutan,
    required this.lokasiPengiriman,
    required this.statusBongkar,
    this.kodeArea,
    this.jenisMuatan = 'non_subsidi',
    this.tibaAt,
    this.bongkarSelesaiAt,
    this.catatanAdmin,
    this.catatanDriver,
    this.jumlahFoto = 0,
    this.alamatOtomatis,
    this.alamatLat,
    this.alamatLng,
  });

  final int id;
  final int urutan;
  final String lokasiPengiriman;
  final String statusBongkar;
  final String? kodeArea;
  final String jenisMuatan;
  final DateTime? tibaAt;
  final DateTime? bongkarSelesaiAt;
  /// Pesan admin untuk sopir pada tujuan ini.
  final String? catatanAdmin;
  final String? catatanDriver;
  final int jumlahFoto;

  /// Hasil pencocokan otomatis ke kunjungan sales. Null berarti tokonya
  /// belum ketemu atau belum pernah dikunjungi — tombol Maps tetap jalan
  /// pakai [labelLokasi] sebagai query pencarian.
  final String? alamatOtomatis;
  final double? alamatLat;
  final double? alamatLng;

  /// Teks yang dikirim ke Maps: alamat asli kalau ada, kalau tidak pakai
  /// nama lokasi pengiriman apa adanya.
  String get queryMaps => alamatOtomatis ?? labelLokasi;

  /// "Gagal" masih mungkin muncul di data lama; aplikasi sekarang hanya
  /// menghasilkan "Bermasalah".
  bool get tuntas =>
      statusBongkar == 'Selesai' ||
      statusBongkar == 'Bermasalah' ||
      statusBongkar == 'Gagal';

  bool get selesai => statusBongkar == 'Selesai';

  bool get bermasalah =>
      statusBongkar == 'Bermasalah' || statusBongkar == 'Gagal';

  String get labelLokasi =>
      kodeArea == null ? lokasiPengiriman : '$lokasiPengiriman ($kodeArea)';

  factory ModelTugasItem.fromJson(Map<String, dynamic> json) => ModelTugasItem(
        id: json['id'] as int,
        urutan: (json['urutan'] as num?)?.toInt() ?? 1,
        lokasiPengiriman: json['lokasi_pengiriman']?.toString() ?? '-',
        statusBongkar: json['status_bongkar']?.toString() ?? 'Menunggu',
        kodeArea: json['kode_area']?.toString(),
        jenisMuatan: json['jenis_muatan']?.toString() ?? 'non_subsidi',
        tibaAt: DateTime.tryParse(json['tiba_at']?.toString() ?? ''),
        bongkarSelesaiAt:
            DateTime.tryParse(json['bongkar_selesai_at']?.toString() ?? ''),
        catatanAdmin: json['catatan_admin']?.toString(),
        catatanDriver: json['catatan_driver']?.toString(),
        jumlahFoto: (json['jumlah_foto'] as num?)?.toInt() ?? 0,
        alamatOtomatis: json['alamat_otomatis']?.toString(),
        alamatLat: (json['alamat_lat'] as num?)?.toDouble(),
        alamatLng: (json['alamat_lng'] as num?)?.toDouble(),
      );
}

class ModelTugas {
  const ModelTugas({
    required this.id,
    required this.tanggalMuatan,
    required this.nomorRit,
    required this.statusPerjalanan,
    this.jenisMuatan = 'non_subsidi',
    this.totalMuatanTon = 0,
    this.jumlahTujuan = 0,
    this.tujuanTuntas = 0,
    this.items = const [],
    this.kendaraan,
    this.checker,
    this.dimuatAt,
    this.berangkatAt,
    this.selesaiAt,
    this.logs = const [],
  });

  final int id;
  final String tanggalMuatan;
  final int nomorRit;

  /// Disimpulkan server dari laporan yang masuk, bukan ditekan driver.
  /// Ditampilkan sebagai keterangan, tidak lagi punya tombol.
  final String statusPerjalanan;

  final String jenisMuatan;
  final double totalMuatanTon;
  final int jumlahTujuan;
  final int tujuanTuntas;
  final List<ModelTugasItem> items;
  final ModelKendaraan? kendaraan;
  final String? checker;
  final DateTime? dimuatAt;
  final DateTime? berangkatAt;
  final DateTime? selesaiAt;
  final List<ModelLogTugas> logs;

  bool get selesai => statusPerjalanan == 'Selesai';

  bool get sedangJalan => statusPerjalanan == 'Berangkat';

  bool get dibatalkan => statusPerjalanan == 'Batal';

  bool get subsidi => jenisMuatan == 'subsidi';

  /// Tujuan yang masih menunggu laporan driver.
  int get tujuanTersisa => jumlahTujuan - tujuanTuntas;

  /// Ganti satu item tujuan dengan versi terbarunya, field rit lainnya
  /// dibiarkan apa adanya. Dipakai untuk menempelkan hasil laporan yang baru
  /// saja dikirim tanpa menunggu detail rit lengkap dimuat ulang dari server.
  ModelTugas gantiItem(ModelTugasItem item) => ModelTugas(
        id: id,
        tanggalMuatan: tanggalMuatan,
        nomorRit: nomorRit,
        statusPerjalanan: statusPerjalanan,
        jenisMuatan: jenisMuatan,
        totalMuatanTon: totalMuatanTon,
        jumlahTujuan: jumlahTujuan,
        tujuanTuntas: tujuanTuntas,
        items: [for (final i in items) i.id == item.id ? item : i],
        kendaraan: kendaraan,
        checker: checker,
        dimuatAt: dimuatAt,
        berangkatAt: berangkatAt,
        selesaiAt: selesaiAt,
        logs: logs,
      );

  factory ModelTugas.fromJson(Map<String, dynamic> json) => ModelTugas(
        id: json['id'] as int,
        tanggalMuatan: json['tanggal_muatan']?.toString() ?? '',
        nomorRit: (json['nomor_rit'] as num?)?.toInt() ?? 1,
        statusPerjalanan: json['status_perjalanan']?.toString() ?? 'Menunggu',
        jenisMuatan: json['jenis_muatan']?.toString() ?? 'non_subsidi',
        totalMuatanTon: (json['total_muatan_ton'] as num?)?.toDouble() ?? 0,
        jumlahTujuan: (json['jumlah_tujuan'] as num?)?.toInt() ?? 0,
        tujuanTuntas: (json['tujuan_tuntas'] as num?)?.toInt() ?? 0,
        items: (json['items'] as List?)
                ?.map((e) => ModelTugasItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        kendaraan: json['kendaraan'] == null
            ? null
            : ModelKendaraan.fromJson(
                json['kendaraan'] as Map<String, dynamic>),
        checker: json['checker']?.toString(),
        dimuatAt: DateTime.tryParse(json['dimuat_at']?.toString() ?? ''),
        berangkatAt: DateTime.tryParse(json['berangkat_at']?.toString() ?? ''),
        selesaiAt: DateTime.tryParse(json['selesai_at']?.toString() ?? ''),
        logs: (json['logs'] as List?)
                ?.map((e) => ModelLogTugas.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

class ModelLogTugas {
  const ModelLogTugas({
    required this.status,
    required this.pelaku,
    required this.waktu,
    this.keterangan,
  });

  final String status;
  final String pelaku;
  final String waktu;
  final String? keterangan;

  factory ModelLogTugas.fromJson(Map<String, dynamic> json) => ModelLogTugas(
        status: json['status']?.toString() ?? '',
        pelaku: json['pelaku']?.toString() ?? 'Sistem',
        waktu: json['waktu']?.toString() ?? '',
        keterangan: json['keterangan']?.toString(),
      );
}
