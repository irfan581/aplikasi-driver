import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'inti/globals.dart';
import 'inti/konstanta/konstanta_api.dart';
import 'inti/tema/tema_app.dart';
import 'data/servis/servis_antrian_foto.dart';
import 'data/repositori/repositori_chat.dart';
import 'data/servis/servis_api.dart';
import 'data/servis/servis_notifikasi.dart';
import 'rute/generator_rute.dart';
import 'rute/nama_rute.dart';
import 'tampilan/provider/provider_auth.dart';
import 'tampilan/provider/provider_chat.dart';
import 'tampilan/provider/provider_riwayat.dart';
import 'tampilan/provider/provider_tugas.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Build release memakai .env.production, debug memakai .env.development,
  // supaya alamat server tidak pernah salah ikut terbawa ke APK rilis.
  await dotenv.load(
    fileName: kReleaseMode ? '.env.production' : '.env.development',
  );

  await initializeDateFormatting('id_ID', null);

  await ServisNotifikasi.siapkan();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const AplikasiDriver());
}

class AplikasiDriver extends StatelessWidget {
  const AplikasiDriver({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProviderAuth()),
        ChangeNotifierProvider(create: (_) => ProviderTugas()),
        ChangeNotifierProvider(create: (_) => ProviderRiwayat()),
        ChangeNotifierProvider(create: (_) => ProviderChat(RepositoriChat())),
      ],
      child: const _AkarAplikasi(),
    );
  }
}

class _AkarAplikasi extends StatefulWidget {
  const _AkarAplikasi();

  @override
  State<_AkarAplikasi> createState() => _AkarAplikasiState();
}

class _AkarAplikasiState extends State<_AkarAplikasi>
    with WidgetsBindingObserver {
  StreamSubscription<ConnectivityResult>? _langgananSinyal;

  @override
  void initState() {
    super.initState();
    _pasangPenanganSesiBerakhir();
    _pasangPemicuAntrianFoto();
    _pasangPenanganNotifikasi();
  }

  void _pasangPenanganNotifikasi() {
    bool sedangMasuk(BuildContext konteks) =>
        konteks.read<ProviderAuth>().status == StatusSesi.masuk;

    ServisNotifikasi.saatMuatanBaru = () {
      final konteks = navigatorKey.currentContext;
      if (konteks == null || !sedangMasuk(konteks)) return;

      konteks.read<ProviderTugas>().muat();
    };

    ServisNotifikasi.saatBukaRit = (ritId) {
      final navigator = navigatorKey.currentState;
      if (navigator == null || !sedangMasuk(navigator.context)) return;

      navigator.pushNamed(NamaRute.detailTugas, arguments: ritId);
    };
  }

  /// Foto bukti yang tertahan di HP dicoba kirim ulang pada dua saat: begitu
  /// sinyal kembali, dan begitu aplikasi dibuka lagi. Driver sering menjepret
  /// di gudang tanpa sinyal lalu mengantongi HP-nya; tanpa dua pemicu ini foto
  /// baru berangkat kalau ia kebetulan membuka layar buktinya sekali lagi.
  void _pasangPemicuAntrianFoto() {
    WidgetsBinding.instance.addObserver(this);

    _langgananSinyal = Connectivity().onConnectivityChanged.listen((keadaan) {
      if (keadaan != ConnectivityResult.none) {
        unawaited(ServisAntrianFoto.kirimTertunda());
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState keadaan) {
    if (keadaan == AppLifecycleState.resumed) {
      unawaited(ServisAntrianFoto.kirimTertunda());
    }
  }

  @override
  void dispose() {
    _langgananSinyal?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Saat server menolak token, aplikasi harus benar-benar kembali ke awal:
  /// request yang masih berjalan dibatalkan, data tugas dibuang, lalu driver
  /// dilempar ke layar login.
  void _pasangPenanganSesiBerakhir() {
    ServisApi.onUnauthorized = () {
      final navigator = navigatorKey.currentState;
      if (navigator == null) return;

      final konteks = navigator.context;
      konteks.read<ProviderTugas>().bersihkan();
      // Riwayat ikut dibuang: tanpa ini, daftar rit driver sebelumnya masih
      // tersisa di layar saat driver lain masuk di HP yang sama.
      konteks.read<ProviderRiwayat>().bersihkan();
      // Ikut dibersihkan supaya percakapan sopir sebelumnya tidak tersisa
      // saat sopir lain masuk di HP yang sama.
      konteks.read<ProviderChat>().bersihkan();
      konteks.read<ProviderAuth>().paksaKeluar();

      ServisApi.batalkanSemuaRequest();

      // Percobaan berjadwal antrian foto dihentikan, tapi isinya sengaja tidak
      // dibuang: sesi bisa berakhir hanya karena token kedaluwarsa, dan foto
      // bukti yang belum terkirim tidak bisa dijepret ulang. Jadwalnya menyala
      // lagi sendiri lewat pemicu sinyal atau aplikasi kembali aktif.
      ServisAntrianFoto.hentikanJadwal();

      ServisNotifikasi.lupakanRitTertunda();

      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Sesi berakhir. Silakan masuk lagi.')),
      );

      navigator.pushNamedAndRemoveUntil(NamaRute.login, (_) => false);
    };
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: KonstantaApi.namaApp,
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: TemaApp.terang,
      locale: const Locale('id', 'ID'),
      initialRoute: NamaRute.splash,
      onGenerateRoute: GeneratorRute.buat,
      builder: (context, child) {
        // Ukuran teks dikunci: layar dipakai sambil bekerja, dan pengaturan
        // font raksasa di HP driver bisa merusak tata letak tombol aksi.
        return MediaQuery.withNoTextScaling(child: child ?? const SizedBox());
      },
    );
  }
}
