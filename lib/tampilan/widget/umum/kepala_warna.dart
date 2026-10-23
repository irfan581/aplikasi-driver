import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../inti/tema/warna_app.dart';

/// Kepala layar yang dipakai semua halaman utama.
///
/// Dulu berupa blok gradient oranye bersudut membulat. Sejak Splash dan Login
/// memakai latar putih bersih, blok berwarna itu jadi terasa dari aplikasi
/// yang berbeda — jadi sekarang kepalanya ikut putih, dan oranye disimpan
/// untuk hal yang benar-benar perlu ditonjolkan (tombol tindakan, status,
/// angka penting). Identitas warna tetap terasa justru karena dipakai hemat.
///
/// [isi] diletakkan di bawah judul untuk layar yang perlu membawa ringkasan,
/// misalnya jumlah foto di layar laporan atau progres tujuan di detail rit.
class KepalaWarna extends StatelessWidget {
  const KepalaWarna({
    super.key,
    required this.judul,
    this.subjudul,
    this.atasJudul,
    this.isi,
    this.aksi,
    this.adaTombolKembali = false,
  });

  final String judul;
  final String? subjudul;
  final String? atasJudul;
  final Widget? isi;
  final List<Widget>? aksi;
  final bool adaTombolKembali;

  @override
  Widget build(BuildContext context) {
    final atas = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Latar putih: jam dan indikator baterai harus gelap, kalau tidak
      // keduanya hilang di area status bar.
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Container(
        width: double.infinity,
        color: WarnaApp.surface,
        padding: EdgeInsets.fromLTRB(24, atas + 16, 24, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (adaTombolKembali)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    // Dibungkus jadi chip bundar tersendiri — bukan ikon
                    // telanjang yang nempel ke judul — supaya jelas ini area
                    // sentuh terpisah dan cukup besar untuk dipakai sambil
                    // berdiri di gudang.
                    child: Material(
                      color: WarnaApp.surfaceMuted,
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: () => Navigator.of(context).maybePop(),
                        customBorder: const CircleBorder(),
                        child: const SizedBox(
                          width: 42,
                          height: 42,
                          child: Icon(
                            Icons.arrow_back,
                            color: WarnaApp.textPrimary,
                            size: 21,
                          ),
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (atasJudul != null) ...[
                        Text(
                          atasJudul!,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: WarnaApp.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                      ],
                      Text(
                        judul,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          height: 1.15,
                          color: WarnaApp.textPrimary,
                        ),
                      ),
                      if (subjudul != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subjudul!,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: WarnaApp.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                ...?aksi,
              ],
            ),
            if (isi != null) ...[
              const SizedBox(height: 16),
              isi!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Penutup setinggi status bar, ditaruh di atas isi layar yang menggulung.
///
/// Kepala layar ikut tergulung bersama isinya. Tanpa penutup ini judul dan
/// kotak ringkasannya lewat persis di belakang jam, sinyal, dan indikator
/// baterai, dan keduanya saling tindih sampai tidak terbaca. Yang dipakai
/// penutup, bukan menggeser isi ke bawah SafeArea, supaya kepalanya tetap bisa
/// digulung habis dan tidak ada pita kosong permanen di pucuk layar.
///
/// [warna] disamakan dengan latar di belakang pucuk layar: putih untuk layar
/// berkepala [KepalaWarna], abu latar untuk layar yang isinya langsung
/// menempel ke latar halaman.
class TudungStatus extends StatelessWidget {
  const TudungStatus({super.key, this.warna = WarnaApp.surface});

  final Color warna;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      // Gaya ikon status bar ikut dititipkan di sini, bukan hanya di
      // [KepalaWarna]. Kepala bisa tergulung keluar layar, dan begitu ia
      // pergi gaya yang dititipkan padanya ikut hilang: jam dan baterai
      // kembali putih di atas latar terang, jadi tidak kelihatan sama sekali.
      // Tudung ini tidak pernah pergi, jadi gayanya bertahan.
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        child: Container(
          width: double.infinity,
          height: MediaQuery.of(context).padding.top,
          color: warna,
        ),
      ),
    );
  }
}

/// Kotak ringkasan di dalam [KepalaWarna].
///
/// Sebelumnya kotak tembus pandang di atas gradient oranye. Di kepala putih
/// itu tidak lagi terbaca, jadi sekarang memakai krem brand — cukup untuk
/// memisahkan diri dari latar tanpa menambah garis atau bayangan.
class KotakKepala extends StatelessWidget {
  const KotakKepala({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: WarnaApp.secondary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }
}
