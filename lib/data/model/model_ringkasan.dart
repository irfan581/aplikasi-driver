/// Sebaran tujuan pada satu kode area.
class WilayahRingkas {
  const WilayahRingkas({required this.kode, required this.jumlah});

  /// Kosong untuk tujuan yang memang tidak punya kode area di data admin.
  final String? kode;

  final int jumlah;

  String get label => kode ?? 'Tanpa kode';

  factory WilayahRingkas.fromJson(Map<String, dynamic> json) => WilayahRingkas(
        kode: json['kode']?.toString(),
        jumlah: (json['jumlah'] as num?)?.toInt() ?? 0,
      );
}

/// Rekap kerja driver sepanjang satu rentang tanggal.
///
/// Dihitung server, bukan dijumlah di HP: driver bisa punya ratusan rit dalam
/// sebulan, dan menarik semuanya cuma untuk menampilkan beberapa angka
/// membakar kuota di daerah bersinyal buruk.
class ModelRingkasan {
  const ModelRingkasan({
    required this.dari,
    required this.sampai,
    this.ritTotal = 0,
    this.ritSelesai = 0,
    this.ritBerjalan = 0,
    this.ritBatal = 0,
    this.tujuanTotal = 0,
    this.tujuanSelesai = 0,
    this.tujuanBermasalah = 0,
    this.muatanTon = 0,
    this.subsidi = 0,
    this.nonSubsidi = 0,
    this.wilayah = const [],
  });

  final String dari;
  final String sampai;

  final int ritTotal;
  final int ritSelesai;
  final int ritBerjalan;
  final int ritBatal;

  final int tujuanTotal;
  final int tujuanSelesai;
  final int tujuanBermasalah;

  /// Muatan yang benar-benar dibawa; rit yang dibatalkan tidak ikut.
  final double muatanTon;

  final int subsidi;
  final int nonSubsidi;

  final List<WilayahRingkas> wilayah;

  bool get kosong => ritTotal == 0;

  /// Dipakai untuk memanjangkan batang wilayah secara proporsional.
  int get wilayahTerbanyak => wilayah.isEmpty
      ? 0
      : wilayah.map((w) => w.jumlah).reduce((a, b) => a > b ? a : b);

  factory ModelRingkasan.fromJson(Map<String, dynamic> json) {
    final periode = json['periode'] as Map<String, dynamic>? ?? const {};
    final rit = json['rit'] as Map<String, dynamic>? ?? const {};
    final tujuan = json['tujuan'] as Map<String, dynamic>? ?? const {};
    final jenis = json['jenis'] as Map<String, dynamic>? ?? const {};

    int angka(Map<String, dynamic> sumber, String kunci) =>
        (sumber[kunci] as num?)?.toInt() ?? 0;

    return ModelRingkasan(
      dari: periode['dari']?.toString() ?? '',
      sampai: periode['sampai']?.toString() ?? '',
      ritTotal: angka(rit, 'total'),
      ritSelesai: angka(rit, 'selesai'),
      ritBerjalan: angka(rit, 'berjalan'),
      ritBatal: angka(rit, 'batal'),
      tujuanTotal: angka(tujuan, 'total'),
      tujuanSelesai: angka(tujuan, 'selesai'),
      tujuanBermasalah: angka(tujuan, 'bermasalah'),
      muatanTon: (json['muatan_ton'] as num?)?.toDouble() ?? 0,
      subsidi: angka(jenis, 'subsidi'),
      nonSubsidi: angka(jenis, 'non_subsidi'),
      wilayah: (json['wilayah'] as List?)
              ?.map((e) => WilayahRingkas.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}
