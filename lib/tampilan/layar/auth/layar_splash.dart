import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../inti/gerak.dart';
import '../../../inti/konstanta/konstanta_api.dart';
import '../../../inti/tema/warna_app.dart';
import '../../../rute/nama_rute.dart';
import '../../provider/provider_auth.dart';
import '../../widget/umum/logo_app.dart';

/// Splash: logo, nama aplikasi, dan penanda proses. Tidak lebih.
///
/// Layar ini tampil kurang dari dua detik dan tugasnya cuma satu — meyakinkan
/// driver bahwa aplikasi yang benar sedang dibuka sementara sesi diperiksa.
/// Karena itu isinya sengaja sedikit: logo sebagai fokus tunggal, teks
/// identitas di bawahnya, dan indikator proses yang tenang di kaki layar.
///
/// Komposisinya dipatok ke persentase tinggi layar, bukan sisa ruang dari
/// Spacer, supaya proporsinya sama di HP pendek maupun tinggi.
class LayarSplash extends StatefulWidget {
  const LayarSplash({super.key});

  @override
  State<LayarSplash> createState() => _LayarSplashState();
}

class _LayarSplashState extends State<LayarSplash>
    with TickerProviderStateMixin {
  /// Satu kendali untuk seluruh koreografi pembuka, bukan beberapa animasi
  /// terpisah: dengan satu sumber waktu, urutan dan jarak antar tahap
  /// terjamin sama di HP cepat maupun lambat.
  late final AnimationController _kendali = AnimationController(
    vsync: this,
    duration: Gerak.splash,
  );

  late final Animation<double> _logo = CurvedAnimation(
    parent: _kendali,
    curve: const Interval(0, 0.55, curve: Curves.easeOutCubic),
  );

  late final Animation<double> _nama = CurvedAnimation(
    parent: _kendali,
    curve: const Interval(0.35, 0.8, curve: Curves.easeOut),
  );

  late final Animation<double> _proses = CurvedAnimation(
    parent: _kendali,
    curve: const Interval(0.6, 1, curve: Curves.easeOut),
  );

  /// Denyut halus pada teks status — menandakan proses masih berjalan tanpa
  /// menambah elemen baru ke layar.
  late final AnimationController _denyut = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Gerak.dimatikan(context)) {
        _kendali.value = 1;
      } else {
        _kendali.forward();
      }
      _periksa();
    });
  }

  @override
  void dispose() {
    _kendali.dispose();
    _denyut.dispose();
    super.dispose();
  }

  Future<void> _periksa() async {
    final auth = context.read<ProviderAuth>();

    // Animasi berjalan bersamaan dengan pemeriksaan sesi, bukan sebelumnya.
    // Lantai waktu hanya menahan bila datanya memang datang lebih cepat, jadi
    // driver tidak pernah menunggu tambahan demi animasi.
    await Future.wait([
      auth.periksaSesi(),
      Future<void>.delayed(
        Gerak.dimatikan(context) ? Duration.zero : Gerak.lantaiSplash,
      ),
    ]);

    if (!mounted) return;

    final tujuan = switch (auth.status) {
      StatusSesi.masuk => NamaRute.beranda,
      StatusSesi.perluGantiPassword => NamaRute.gantiPasswordWajib,
      _ => NamaRute.login,
    };

    // pushReplacement, bukan pushNamedAndRemoveUntil: splash adalah rute
    // pertama sehingga hasil akhirnya sama (tumpukan cuma berisi tujuan),
    // tapi rute splash baru dilepas setelah transisi selesai — itu yang
    // membuat logo sempat terbang ke layar berikutnya lewat Hero.
    Navigator.of(context).pushReplacementNamed(tujuan);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: WarnaApp.surface,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, batas) {
              final tinggi = batas.maxHeight;

              return Stack(
                children: [
                  // Logo + nama duduk di 38% tinggi layar: mata membaca
                  // "tengah" sedikit lebih tinggi daripada tengah geometris,
                  // jadi komposisi terasa seimbang, bukan melorot.
                  Positioned(
                    top: tinggi * 0.32,
                    left: 24,
                    right: 24,
                    child: Column(
                      children: [
                        FadeTransition(
                          opacity: _logo,
                          child: ScaleTransition(
                            scale: Tween<double>(begin: 0.92, end: 1)
                                .animate(_logo),
                            // Ukuran ilustrasi, bukan ukuran logo mark:
                            // isinya adegan (truk, kurir, gedung) yang butuh
                            // ruang untuk terbaca. Proporsional ke lebar layar
                            // supaya tidak kepotong di HP kecil.
                            child: LogoApp(
                              ukuran: (batas.maxWidth * 0.58)
                                  .clamp(180.0, 240.0)
                                  .toDouble(),
                              tag: tagLogo,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        _naikSambilMuncul(
                          animasi: _nama,
                          child: const Column(
                            children: [
                              Text(
                                'Tani Makmur',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                  height: 1.1,
                                  color: WarnaApp.textPrimary,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Driver Partner App',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: WarnaApp.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Indikator proses di kaki layar, jauh dari logo — supaya
                  // tidak ikut berebut perhatian dengan identitas aplikasi.
                  Positioned(
                    top: tinggi * 0.82,
                    left: 24,
                    right: 24,
                    child: FadeTransition(
                      opacity: _proses,
                      child: Column(
                        children: [
                          const SizedBox(
                            width: 132,
                            child: ClipRRect(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(999)),
                              child: LinearProgressIndicator(
                                minHeight: 4,
                                backgroundColor: WarnaApp.border,
                                valueColor:
                                    AlwaysStoppedAnimation(WarnaApp.primary),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          AnimatedBuilder(
                            animation: _denyut,
                            builder: (_, anak) => Opacity(
                              opacity: 0.65 + 0.35 * _denyut.value,
                              child: anak,
                            ),
                            child: const Text(
                              'Menyiapkan rute pengiriman...',
                              style: TextStyle(
                                fontSize: 12,
                                color: WarnaApp.textHint,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Positioned(
                    bottom: 24,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Text(
                        'v${KonstantaApi.versiApp}',
                        style: TextStyle(
                          fontSize: 11,
                          color: WarnaApp.textHint,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _naikSambilMuncul({
    required Animation<double> animasi,
    required Widget child,
  }) {
    return FadeTransition(
      opacity: animasi,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.4),
          end: Offset.zero,
        ).animate(animasi),
        child: child,
      ),
    );
  }
}
