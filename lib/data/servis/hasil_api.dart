/// Bentuk seragam hasil panggilan API.
///
/// [offline] membedakan "gagal karena jaringan" dari "server menolak". Bedanya
/// menentukan apakah sebuah aksi boleh diantrikan untuk dikirim ulang nanti
/// atau justru harus ditampilkan sebagai penolakan ke driver.
class HasilApi<T> {
  const HasilApi({
    required this.sukses,
    this.data,
    this.pesan = '',
    this.kode,
    this.offline = false,
  });

  final bool sukses;
  final T? data;
  final String pesan;

  /// Kode error dari backend, lihat [KodeError].
  final String? kode;

  final bool offline;

  factory HasilApi.sukses(T data, [String pesan = '']) =>
      HasilApi(sukses: true, data: data, pesan: pesan);

  factory HasilApi.gagal(String pesan, {String? kode, bool offline = false}) =>
      HasilApi(sukses: false, pesan: pesan, kode: kode, offline: offline);

  bool berkode(String kodeError) => kode == kodeError;
}
