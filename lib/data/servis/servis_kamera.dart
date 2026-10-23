import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../inti/konstanta/konstanta_api.dart';

/// Hasil satu percobaan menjepret bukti bongkar.
///
/// Dibatalkan, izin ditolak, dan gagal teknis dibedakan karena tanggapannya di
/// layar berbeda: yang pertama diam saja, yang kedua menawarkan buka
/// pengaturan, yang ketiga menampilkan pesan kesalahan.
enum StatusJepret { berhasil, dibatalkan, izinDitolak, gagal }

class HasilJepret {
  const HasilJepret._(this.status, {this.berkas, this.pesan = ''});

  const HasilJepret.berhasil(File berkas)
      : this._(StatusJepret.berhasil, berkas: berkas);

  const HasilJepret.dibatalkan() : this._(StatusJepret.dibatalkan);

  const HasilJepret.izinDitolak(String pesan)
      : this._(StatusJepret.izinDitolak, pesan: pesan);

  const HasilJepret.gagal(String pesan)
      : this._(StatusJepret.gagal, pesan: pesan);

  final StatusJepret status;
  final File? berkas;
  final String pesan;

  bool get berhasilJepret => status == StatusJepret.berhasil;
}

/// Pengambilan dan penyiapan foto bukti bongkar.
///
/// Hanya kamera, tidak pernah galeri: bukti bongkar harus dijepret di lokasi,
/// dan galeri membuka jalan mengirim ulang foto lama dari tujuan lain.
class ServisKamera {
  ServisKamera._();

  static final ImagePicker _pemilih = ImagePicker();

  /// Nama folder tempat foto menunggu giliran unggah. Sengaja di direktori
  /// dokumen aplikasi, bukan cache: cache boleh dibersihkan Android kapan saja
  /// dan foto yang belum terkirim akan lenyap tanpa jejak.
  static const String _folder = 'bukti_bongkar';

  /// 1280px sisi terpanjang, kualitas 80 — sama dengan yang dipakai server
  /// lewat uploadBukti(). Angka yang sama di kedua sisi berarti server tidak
  /// perlu memperkecil lagi, sehingga tulisan di surat jalan tidak melewati
  /// dua kali kompresi dan tetap terbaca admin.
  static const int _lebarMaks = 1280;
  static const int _kualitas = 80;

  /// Catat lama satu tahap ke log, hanya saat DEBUG menyala.
  ///
  /// Keluhan "jepret foto lama" tidak bisa ditebak dari kode: tahapnya ada
  /// empat dan yang berat berbeda-beda antar HP. Angka per tahap membuatnya
  /// terbaca langsung di `flutter run` tanpa perlu memasang alat ukur lain.
  static Future<T> _ukurWaktu<T>(
      String tahap, Future<T> Function() aksi) async {
    if (!KonstantaApi.isDebug) return aksi();

    final mulai = DateTime.now();

    try {
      return await aksi();
    } finally {
      final lama = DateTime.now().difference(mulai).inMilliseconds;
      debugPrint('[Jepret] $tahap: $lama ms');
    }
  }

  /// Meminta izin kamera. Mengembalikan null bila diizinkan, atau pesan yang
  /// bisa langsung ditampilkan ke driver bila tidak.
  static Future<String?> _mintaIzin() async {
    final status = await Permission.camera.request();

    if (status.isGranted || status.isLimited) return null;

    if (status.isPermanentlyDenied) {
      return 'Izin kamera dimatikan permanen. Buka Pengaturan aplikasi untuk '
          'menyalakannya.';
    }

    return 'Foto bukti bongkar butuh izin kamera.';
  }

  /// Buka kamera, kompres sekali, simpan ke penyimpanan aplikasi.
  ///
  /// [namaBerkas] dipakai apa adanya sebagai nama file supaya foto di antrian
  /// bisa dicocokkan kembali dengan client_uuid-nya setelah aplikasi ditutup.
  static Future<HasilJepret> jepret({required String namaBerkas}) async {
    final tolakan = await _mintaIzin();
    if (tolakan != null) return HasilJepret.izinDitolak(tolakan);

    final XFile? asli;
    try {
      // Tanpa imageQuality. Begitu angka itu diisi, image_picker membongkar
      // seluruh gambar 12 MP jadi bitmap lalu menyandinya ulang di kualitas
      // 100 sebelum berkasnya diserahkan — beberapa detik menunggu, dan
      // hasilnya sering justru lebih besar daripada berkas asli kamera.
      // Padahal sesudah ini gambarnya toh dikompres sekali lagi. Yang dulu
      // dititipkan ke langkah itu cuma pelurusan arah gambar, dan pelurusan
      // itu sudah dikerjakan compressAndGetFile lewat autoCorrectionAngle
      // yang menyala secara bawaan.
      asli = await _ukurWaktu(
        'kamera',
        () => _pemilih.pickImage(
          source: ImageSource.camera,
          preferredCameraDevice: CameraDevice.rear,
        ),
      );
    } catch (e) {
      return HasilJepret.gagal('Kamera tidak bisa dibuka: $e');
    }

    if (asli == null) return const HasilJepret.dibatalkan();

    try {
      return HasilJepret.berhasil(
        await _ukurWaktu('siapkan', () => _kompres(asli!.path, namaBerkas)),
      );
    } catch (e) {
      return HasilJepret.gagal('Foto gagal disiapkan: $e');
    }
  }

  /// Sisipan nama untuk hasil kompresi yang belum menempati nama sungguhan.
  ///
  /// Ditaruh SEBELUM akhiran .jpg, bukan sesudahnya. flutter_image_compress
  /// menolak berkas tujuan yang namanya tidak berakhir .jpg atau .jpeg, jadi
  /// nama seperti `<uuid>.jpg.1` membuat seluruh penyiapan foto gagal dengan
  /// "CompressFormat.jpeg requires the target file name to end with .jpg".
  static const List<String> _sisipanSementara = ['.tmp1', '.tmp2'];

  /// Nama berkas untuk hasil kompresi yang belum menempati nama sungguhan.
  ///
  /// Dipisah jadi fungsi tersendiri supaya bisa diuji tanpa kamera maupun
  /// penyimpanan. Aturannya sepele, tapi melanggarnya mematikan seluruh
  /// penyiapan foto — dan itu baru ketahuan dari layar sopir di lapangan.
  @visibleForTesting
  static List<String> namaSementara(String folder, String namaBerkas) => [
        for (final sisipan in _sisipanSementara)
          '$folder/$namaBerkas$sisipan.jpg',
      ];

  static Future<File> _kompres(String pathAsli, String namaBerkas) async {
    final tujuan = await _siapkanFolder();
    final path = '${tujuan.path}/$namaBerkas.jpg';
    final sementara = namaSementara(tujuan.path, namaBerkas);

    // flutter_image_compress menskalakan gambar sampai KEDUA sisi memenuhi
    // minWidth/minHeight, bukan membatasi sisi terpanjang. Kalau dua-duanya
    // diisi _lebarMaks, sisi pendek jadi pas 1280px tapi sisi panjang malah
    // melebihi itu (potret 3024x4032 -> 1280x1706, bukan 1280 di sisi
    // terpanjang). Supaya sisi terpanjang yang dibatasi, sisi pendeknya
    // diberi batas minimal 1px agar tidak ikut menentukan skala.
    final ukuran =
        await _ukurWaktu('baca ukuran', () => _ukuranGambar(pathAsli));
    final potret = ukuran != null && ukuran.height >= ukuran.width;

    var hasil = await _ukurWaktu(
      'kompres',
      () => _kompresSekali(pathAsli, sementara[0], potret: potret),
    );

    // Arah gambar ditebak dari ukuran yang tersimpan di berkas, sedangkan
    // sebagian kamera menyimpan foto tegak di dalam bingkai mendatar dan
    // menitipkan putarannya di EXIF. Kalau tebakannya meleset, sisi terpanjang
    // hasilnya masih jauh di atas batas. Diperiksa lalu diulang sekali dengan
    // sisi dibalik. Pemeriksaannya cuma membaca kepala berkas, jadi murah, dan
    // kompresi kedua hanya terjadi kalau memang meleset. Hasil pertama baru
    // dibuang setelah yang kedua benar-benar jadi.
    if (hasil != null && _terlaluBesar(await _ukuranGambar(hasil.path))) {
      final ulang =
          await _kompresSekali(pathAsli, sementara[1], potret: !potret);

      if (ulang != null) {
        await ServisKamera.hapusBerkas(hasil.path);
        hasil = ulang;
      }
    }

    if (hasil == null) {
      // Kompresi gagal pada sebagian HP murah. Foto aslinya tetap lebih
      // berharga daripada tidak ada bukti sama sekali, jadi disalin apa
      // adanya — batas 8 MB di server masih memberi ruang.
      return File(pathAsli).copy(path);
    }

    // Baru sekarang menempati nama yang dicari antrian. Sebelum ini hasilnya
    // menumpang nama sementara, supaya nama sungguhan tidak pernah berisi
    // berkas setengah jadi kalau prosesnya putus di tengah.
    return File(hasil.path).rename(path);
  }

  static bool _terlaluBesar(ui.Size? ukuran) {
    if (ukuran == null) return false;

    final panjang = ukuran.width > ukuran.height ? ukuran.width : ukuran.height;

    return panjang > _lebarMaks * 1.05;
  }

  static Future<XFile?> _kompresSekali(
    String asal,
    String tujuan, {
    required bool potret,
  }) async {
    // Sisa berkas dari proses yang putus sebelumnya dibuang dulu: sebagian
    // pelantar menolak menimpa berkas yang sudah ada.
    await hapusBerkas(tujuan);

    return FlutterImageCompress.compressAndGetFile(
      asal,
      tujuan,
      quality: _kualitas,
      minWidth: potret ? 1 : _lebarMaks,
      minHeight: potret ? _lebarMaks : 1,
      format: CompressFormat.jpeg,
    );
  }

  /// Lebar dan tinggi berkas, atau null bila gagal dibaca — jatuhnya kembali
  /// ke perilaku lama (batas simetris di kedua sisi) daripada menggagalkan
  /// seluruh proses kompresi.
  ///
  /// Dibaca dari kepala berkas lewat [ui.ImageDescriptor], bukan dengan
  /// menyandi-balik gambarnya. Cara lama membaca seluruh JPEG ke memori lalu
  /// membongkarnya jadi bitmap utuh cuma untuk menanyakan dua angka: foto 12 MP
  /// berarti sekitar 48 MB piksel dan penantian yang terasa di HP kelas bawah,
  /// padahal ukurannya tertulis di beberapa bita pertama berkas.
  static Future<ui.Size?> _ukuranGambar(String path) async {
    ui.ImmutableBuffer? penyangga;
    ui.ImageDescriptor? keterangan;

    try {
      penyangga = await ui.ImmutableBuffer.fromFilePath(path);
      keterangan = await ui.ImageDescriptor.encoded(penyangga);

      return ui.Size(
        keterangan.width.toDouble(),
        keterangan.height.toDouble(),
      );
    } catch (_) {
      return null;
    } finally {
      keterangan?.dispose();
      penyangga?.dispose();
    }
  }

  /// Semua urusan berkas di sini memakai bentuk asinkron, bukan `...Sync`.
  ///
  /// Yang sinkron dijalankan tepat di isolate tampilan dan menahannya sampai
  /// cakram menjawab; sepuluh berkas yang disapu berarti sepuluh kali tampilan
  /// berhenti. Bentuk asinkron menyerahkannya ke kolam thread milik Dart, jadi
  /// gambar tetap bergerak selagi berkasnya diurus.
  static Future<Directory> _siapkanFolder() async {
    final akar = await getApplicationDocumentsDirectory();
    final folder = Directory('${akar.path}/$_folder');

    if (!await folder.exists()) {
      await folder.create(recursive: true);
      return folder;
    }

    // Sapu sisa berkas sementara dari proses yang putus di antara kompresi dan
    // penggantian nama. Namanya tidak akan pernah dicari lagi karena setiap
    // jepretan memakai uuid baru, jadi kalau tidak dibuang ia menumpuk diam-
    // diam di penyimpanan HP.
    await for (final isi in folder.list()) {
      final sisa = isi is File &&
          _sisipanSementara.any((sisipan) => isi.path.endsWith('$sisipan.jpg'));

      if (sisa) {
        try {
          await isi.delete();
        } catch (_) {
          // Gagal menyapu bukan alasan menggagalkan jepretan.
        }
      }
    }

    return folder;
  }

  /// Buang berkas yang sudah selesai diunggah atau dibatalkan driver.
  static Future<void> hapusBerkas(String path) async {
    final berkas = File(path);
    if (await berkas.exists()) await berkas.delete();
  }

  static Future<void> bukaPengaturan() => openAppSettings();
}
