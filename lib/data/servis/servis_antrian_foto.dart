import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../../inti/konstanta/kode_error.dart';
import '../model/model_foto_bongkar.dart';
import '../repositori/repositori_foto_bongkar.dart';
import 'servis_kamera.dart';

/// Antrian foto bukti bongkar yang belum sampai ke server.
///
/// Driver menjepret di halaman toko, sering di balik tembok gudang atau di
/// jalan tanpa sinyal. Kalau unggahan dibuat sebagai janji sekali jalan, foto
/// yang gagal terkirim hilang bersama layarnya dan driver baru sadar setelah
/// server menolak menutup tujuannya. Karena itu setiap foto dicatat dulu ke
/// penyimpanan, baru dicoba dikirim.
///
/// Yang tidak diantrikan adalah perubahan status tujuan: server menolak
/// transisi yang diulang, jadi menandai "selesai" tetap butuh sinyal saat itu
/// juga. Antrian ini hanya menjaga fotonya tidak hilang sementara menunggu.
///
/// Antrian sengaja tidak dikosongkan saat driver keluar. Sesi bisa berakhir
/// hanya karena token kedaluwarsa, dan membuang foto yang belum terkirim di
/// saat itu berarti menghapus bukti bongkar yang tidak bisa diulang. Foto yang
/// benar-benar bukan milik driver yang sedang masuk akan ditolak server
/// dengan BUKAN_TUGAS_ANDA dan gugur dengan sendirinya.
class ServisAntrianFoto {
  ServisAntrianFoto._();

  static const String _kunci = 'antrian_foto_bongkar';

  static final RepositoriFotoBongkar _repositori = RepositoriFotoBongkar();

  /// Kode penolakan yang tidak akan pernah berubah kalau dicoba lagi. Foto
  /// dengan salah satu kode ini dibuang dari antrian, karena mengulangnya
  /// hanya membakar kuota driver tanpa pernah berhasil.
  static const Set<String> _penolakanPermanen = {
    KodeError.tujuanSudahTuntas,
    KodeError.clientUuidBentrok,
    KodeError.bukanTugasAnda,
    KodeError.ritDibatalkan,
    KodeError.batasFoto,
  };

  /// Pengiriman yang sedang berlangsung, supaya dua pemicu yang datang
  /// bersamaan (aplikasi kembali aktif dan sinyal pulih) tidak mengunggah
  /// berkas yang sama dua kali.
  static Future<int>? _berjalan;

  /// Satu putaran susulan yang sudah dipesan. Foto yang baru masuk antrian
  /// belum tentu terbawa putaran yang sedang berjalan, karena isi antrian
  /// dibaca sekali di awal putaran.
  static Future<int>? _susulan;

  /// Jeda antar percobaan otomatis, naik bertingkat.
  ///
  /// Wilayah bongkar sopir sering bersinyal satu bar atau hilang sama sekali,
  /// dan di sana `onConnectivityChanged` tidak berbunyi: HP tetap merasa
  /// tersambung, cuma datanya tidak jalan. Tanpa percobaan berjadwal sendiri,
  /// foto menganggur sampai sopir kebetulan membuka layar buktinya lagi atau
  /// menekan tombol coba kirim. Jedanya dinaikkan supaya baterai dan kuota
  /// tidak habis mengetuk jaringan yang memang sedang mati.
  static const List<Duration> _jedaCoba = [
    Duration(seconds: 15),
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 3),
    Duration(minutes: 5),
  ];

  static Timer? _pewaktu;
  static int _percobaanBeruntun = 0;

  /// Mengantre operasi baca-ubah-tulis pada penyimpanan supaya `tambah()`
  /// yang dipanggil saat `kirimTertunda()` masih membaca/menulis tidak
  /// bentrok dan membuat salah satu perubahan tertimpa.
  static Future<void> _gembok = Future.value();

  static Future<T> _terkunci<T>(Future<T> Function() aksi) {
    final selesai = Completer<void>();
    final tunggu = _gembok;
    _gembok = selesai.future;
    return tunggu.then((_) async {
      try {
        return await aksi();
      } finally {
        selesai.complete();
      }
    });
  }

  /// Diberi tahu setiap kali isi antrian berubah, supaya layar yang sedang
  /// terbuka ikut memperbarui penandanya tanpa harus menarik ulang.
  static final StreamController<void> _perubahan =
      StreamController<void>.broadcast();

  static Stream<void> get perubahan => _perubahan.stream;

  // ── Penyimpanan ───────────────────────────────────────────────

  static Future<List<FotoTertunda>> semua() async {
    final prefs = await SharedPreferences.getInstance();
    final mentah = prefs.getString(_kunci);

    if (mentah == null || mentah.isEmpty) return const [];

    try {
      return FotoTertunda.decode(mentah);
    } catch (_) {
      // Isi yang rusak lebih baik dibuang daripada membuat antrian macet
      // selamanya di setiap pemanggilan.
      await prefs.remove(_kunci);
      return const [];
    }
  }

  static Future<List<FotoTertunda>> untukTujuan(int ritId, int itemId) async {
    final daftar = await semua();
    return daftar.where((f) => f.ritId == ritId && f.itemId == itemId).toList();
  }

  static Future<void> tambah(FotoTertunda foto) {
    return _terkunci(() async {
      final daftar = await semua();

      await _simpan([
        ...daftar.where((f) => f.clientUuid != foto.clientUuid),
        foto,
      ]);
    });
  }

  /// Buang satu foto dari antrian sekaligus berkasnya di HP.
  static Future<void> buang(String clientUuid) {
    return _terkunci(() async {
      final daftar = await semua();
      final sisa = <FotoTertunda>[];

      for (final foto in daftar) {
        if (foto.clientUuid == clientUuid) {
          await ServisKamera.hapusBerkas(foto.path);
        } else {
          sisa.add(foto);
        }
      }

      await _simpan(sisa);
    });
  }

  static Future<void> _simpan(List<FotoTertunda> daftar) async {
    final prefs = await SharedPreferences.getInstance();

    if (daftar.isEmpty) {
      await prefs.remove(_kunci);
    } else {
      await prefs.setString(_kunci, FotoTertunda.encode(daftar));
    }

    if (!_perubahan.isClosed) _perubahan.add(null);
  }

  // ── Pengiriman ────────────────────────────────────────────────

  /// Coba kirim seluruh isi antrian sekali jalan.
  ///
  /// Mengembalikan jumlah foto yang berhasil masuk server pada percobaan ini.
  ///
  /// Kalau satu putaran sedang berjalan, pemanggilan ini tidak dibuang begitu
  /// saja melainkan menunggu putaran itu selesai lalu menjalankan satu putaran
  /// lagi. Tanpa itu, foto yang baru dijepret bisa tertinggal di antrian tanpa
  /// pernah dicoba: menutup kamera membangunkan aplikasi, dan pemicu "aplikasi
  /// kembali aktif" sudah lebih dulu membaca antrian tanpa foto tersebut.
  /// Cukup satu putaran susulan untuk semua pemanggil yang menunggu, karena
  /// putaran itu membaca isi antrian yang terbaru.
  static Future<int> kirimTertunda() {
    final berjalan = _berjalan;
    if (berjalan == null) return _jalankan();

    return _susulan ??= () async {
      // Kegagalan putaran sebelumnya tidak boleh menggagalkan susulannya:
      // justru saat itulah antrian paling perlu dicoba lagi.
      try {
        await berjalan;
      } catch (_) {}

      _susulan = null;
      return _jalankan();
    }();
  }

  static Future<int> _jalankan() {
    final putaran = _kirimSemua();
    _berjalan = putaran;

    // Kegagalan putaran ditangani pemanggilnya; di sini hanya penandanya
    // yang dilepas, dan errornya diredam agar tidak jatuh sebagai kesalahan
    // tanpa penanganan.
    unawaited(putaran.whenComplete(() {
      if (identical(_berjalan, putaran)) _berjalan = null;
    }).catchError((_) => 0));

    return putaran;
  }

  static Future<int> _kirimSemua() async {
    final daftar = await semua();
    if (daftar.isEmpty) return 0;

    var berhasil = 0;
    // Hasil dicatat per clientUuid, bukan langsung ditimpakan ke
    // penyimpanan — upload di bawah ini bisa makan waktu detik-menit, dan
    // selama itu tambah()/buang() lain bisa saja mengubah antrian. Yang
    // disimpan di akhir adalah gabungan dari hasil ini dengan state
    // penyimpanan yang paling baru, bukan snapshot `daftar` di atas.
    final selesai = <String>{};
    final diperbarui = <String, FotoTertunda>{};

    for (var i = 0; i < daftar.length; i++) {
      final foto = daftar[i];
      final hasil = await _repositori.unggah(foto);

      if (hasil.sukses) {
        await ServisKamera.hapusBerkas(foto.path);
        berhasil++;
        selesai.add(foto.clientUuid);
        continue;
      }

      if (hasil.offline) {
        // Sinyal mati atau tersendat. Sisanya pasti bernasib sama, jadi
        // antrian disudahi di sini alih-alih menabrak timeout satu per satu.
        // Pesannya ditulis ulang di sini: foto memang punya antrian, jadi
        // janji "dicoba lagi sendiri" untuk foto benar adanya.
        diperbarui[foto.clientUuid] = foto.salin(
          percobaan: foto.percobaan + 1,
          pesanGagal: 'Sinyal lemah. Foto aman di HP dan dicoba lagi sendiri.',
        );
        break;
      }

      if (hasil.kode != null && _penolakanPermanen.contains(hasil.kode)) {
        await ServisKamera.hapusBerkas(foto.path);
        selesai.add(foto.clientUuid);
        continue;
      }

      // Penolakan yang belum tentu tetap — sesi kedaluwarsa, rit belum
      // ditandai berangkat, gangguan server — tetap disimpan untuk dicoba
      // lagi, dengan alasannya supaya driver tidak menebak-nebak.
      diperbarui[foto.clientUuid] = foto.salin(
        percobaan: foto.percobaan + 1,
        pesanGagal: hasil.pesan,
      );
    }

    await _terkunci(() async {
      final terkini = await semua();
      final gabungan = terkini
          .where((f) => !selesai.contains(f.clientUuid))
          .map((f) => diperbarui[f.clientUuid] ?? f)
          .toList();
      await _simpan(gabungan);
    });

    await _jadwalkanUlang(adaKemajuan: berhasil > 0);

    return berhasil;
  }

  /// Pasang percobaan berikutnya bila masih ada yang tertinggal, atau matikan
  /// jadwalnya bila antrian sudah bersih.
  ///
  /// [adaKemajuan] mengembalikan jeda ke tingkat terpendek: satu foto yang
  /// berhasil naik berarti jaringannya mulai jalan, jadi sisanya pantas
  /// dicoba segera alih-alih menunggu jeda panjang yang terlanjur terkumpul.
  static Future<void> _jadwalkanUlang({required bool adaKemajuan}) async {
    _pewaktu?.cancel();
    _pewaktu = null;

    final sisa = await semua();

    if (sisa.isEmpty) {
      _percobaanBeruntun = 0;
      return;
    }

    if (adaKemajuan) _percobaanBeruntun = 0;

    final jeda = _jedaCoba[_percobaanBeruntun.clamp(0, _jedaCoba.length - 1)];
    _percobaanBeruntun++;

    _pewaktu = Timer(jeda, () {
      _pewaktu = null;
      unawaited(kirimTertunda());
    });
  }

  /// Hentikan percobaan berjadwal. Dipakai saat sesi berakhir supaya antrian
  /// tidak terus mengetuk server memakai token yang sudah dicabut.
  static void hentikanJadwal() {
    _pewaktu?.cancel();
    _pewaktu = null;
    _percobaanBeruntun = 0;
  }
}
