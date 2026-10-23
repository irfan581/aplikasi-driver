import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';

/// Penanda shared element logo: dipakai Splash dan Login supaya logonya
/// terbang antar layar, bukan hilang lalu muncul lagi.
const String tagLogo = 'logo-tani-makmur';

/// Logo/ilustrasi identitas Tani Makmur.
///
/// Keberadaan berkasnya diperiksa sekali di awal: kalau asetnya ada, itu yang
/// dipakai; kalau belum, tampil penampung sementara berinisial "TM" yang tetap
/// rapi, bukan layar galat.
///
/// Mengganti gambar = menimpa berkas di path [aset]. Tidak ada kode yang perlu
/// disentuh.
class LogoApp extends StatefulWidget {
  const LogoApp({super.key, required this.ukuran, this.tag});

  static const String aset = 'assets/logo/logistik.svg';

  final double ukuran;
  final Object? tag;

  @override
  State<LogoApp> createState() => _LogoAppState();
}

class _LogoAppState extends State<LogoApp> {
  bool? _adaAset;

  @override
  void initState() {
    super.initState();
    _periksaAset();
  }

  Future<void> _periksaAset() async {
    var ada = false;
    try {
      await rootBundle.load(LogoApp.aset);
      ada = true;
    } catch (_) {
      ada = false;
    }
    if (mounted) setState(() => _adaAset = ada);
  }

  @override
  Widget build(BuildContext context) {
    final isi = SizedBox(
      width: widget.ukuran,
      height: widget.ukuran,
      child: switch (_adaAset) {
        // Belum diperiksa: ruang kosong seukuran logo supaya tata letaknya
        // tidak melompat begitu hasil pemeriksaan datang.
        null => const SizedBox.shrink(),
        true => SvgPicture.asset(LogoApp.aset, fit: BoxFit.contain),
        false => const _PenampungLogo(),
      },
    );

    if (widget.tag == null) return isi;

    return Hero(
      tag: widget.tag!,
      flightShuttleBuilder: (_, __, ___, ____, _____) =>
          FittedBox(fit: BoxFit.contain, child: isi),
      child: isi,
    );
  }
}

/// Tampilan sementara selama `logo.svg` belum dimasukkan ke folder aset.
class _PenampungLogo extends StatelessWidget {
  const _PenampungLogo();

  @override
  Widget build(BuildContext context) {
    final warna = Theme.of(context).colorScheme.primary;

    return LayoutBuilder(
      builder: (context, batas) => Container(
        decoration: BoxDecoration(
          color: warna.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(batas.maxWidth * 0.28),
        ),
        alignment: Alignment.center,
        child: Text(
          'TM',
          style: TextStyle(
            fontSize: batas.maxWidth * 0.34,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
            color: warna,
          ),
        ),
      ),
    );
  }
}
