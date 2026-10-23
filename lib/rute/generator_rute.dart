import 'package:flutter/material.dart';

import '../inti/gerak.dart';

import '../tampilan/layar/auth/layar_ganti_password.dart';
import '../tampilan/layar/auth/layar_login.dart';
import '../tampilan/layar/auth/layar_splash.dart';
import '../tampilan/layar/utama/layar_utama.dart';
import '../tampilan/layar/laporan/layar_laporan.dart';
import '../tampilan/layar/tugas/layar_detail_tugas.dart';
import 'nama_rute.dart';

class GeneratorRute {
  GeneratorRute._();

  static Route<dynamic> buat(RouteSettings settings) {
    switch (settings.name) {
      case NamaRute.splash:
        return _halaman(const LayarSplash(), settings);

      case NamaRute.login:
        return _lebur(const LayarLogin(), settings);

      case NamaRute.gantiPasswordWajib:
        return _lebur(const LayarGantiPassword(), settings);

      case NamaRute.gantiPassword:
        return _halaman(const LayarGantiPassword(wajib: false), settings);

      case NamaRute.beranda:
        return _lebur(const LayarUtama(), settings);

      case NamaRute.detailTugas:
        final ritId = settings.arguments as int;
        return _halaman(LayarDetailTugas(ritId: ritId), settings);

      case NamaRute.laporan:
        final argumen = settings.arguments as ArgumenLaporan;
        return _halaman(LayarLaporan(argumen: argumen), settings);

      default:
        return _halaman(
          Scaffold(
            appBar: AppBar(title: const Text('Halaman tidak ada')),
            body: Center(child: Text('Rute ${settings.name} tidak dikenal')),
          ),
          settings,
        );
    }
  }

  static MaterialPageRoute _halaman(Widget layar, RouteSettings settings) {
    return MaterialPageRoute(builder: (_) => layar, settings: settings);
  }

  /// Perpindahan yang mengganti seluruh konteks — masuk, keluar, selesai ganti
  /// password — memakai lebur-silang, bukan geser. Geser menyiratkan "maju
  /// satu halaman dan bisa kembali", padahal rute lama justru dibuang.
  static PageRouteBuilder _lebur(Widget layar, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      transitionDuration: Gerak.sedang,
      reverseTransitionDuration: Gerak.sedang,
      pageBuilder: (_, __, ___) => layar,
      transitionsBuilder: (context, animasi, _, anak) {
        if (Gerak.dimatikan(context)) return anak;

        final halus = CurvedAnimation(parent: animasi, curve: Curves.easeOut);

        return FadeTransition(
          opacity: halus,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(halus),
            child: anak,
          ),
        );
      },
    );
  }
}
