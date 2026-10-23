import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../data/servis/servis_penyimpanan_aman.dart';
import '../../../inti/konstanta/konstanta_api.dart';
import '../../../inti/tema/warna_app.dart';
import '../../../rute/nama_rute.dart';
import '../../provider/provider_auth.dart';
import '../../widget/umum/logo_app.dart';
import '../../widget/umum/masuk_bertahap.dart';

/// Layar masuk driver.
///
/// Satu kolom putih, padding 24dp, jarak antar elemen kelipatan 8dp. Logonya
/// widget yang sama dengan di Splash dan memakai tag Hero yang sama, jadi
/// perpindahannya terbaca sebagai kelanjutan — bukan dua layar terpisah.
class LayarLogin extends StatefulWidget {
  const LayarLogin({super.key});

  @override
  State<LayarLogin> createState() => _LayarLoginState();
}

class _LayarLoginState extends State<LayarLogin> {
  final _formKey = GlobalKey<FormState>();
  final _kodeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _passwordFocus = FocusNode();

  bool _sembunyikanPassword = true;

  @override
  void initState() {
    super.initState();
    _isiKodeTerakhir();
  }

  /// Driver memakai HP yang sama tiap hari, jadi kodenya tidak perlu diketik
  /// ulang setiap kali masuk.
  Future<void> _isiKodeTerakhir() async {
    final kode = await ServisPenyimpananAman.ambilKodeTerakhir();
    if (kode != null && mounted && _kodeCtrl.text.isEmpty) {
      _kodeCtrl.text = kode;
    }
  }

  @override
  void dispose() {
    _kodeCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _masuk() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<ProviderAuth>();
    final berhasil = await auth.login(_kodeCtrl.text, _passwordCtrl.text);

    if (!mounted) return;

    if (!berhasil) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.pesanError ?? 'Gagal masuk'),
          backgroundColor: WarnaApp.error,
        ),
      );
      return;
    }

    final tujuan = auth.status == StatusSesi.perluGantiPassword
        ? NamaRute.gantiPasswordWajib
        : NamaRute.beranda;

    Navigator.of(context).pushNamedAndRemoveUntil(tujuan, (_) => false);
  }

  /// Tidak ada alur atur-ulang password sendiri — kode dan password memang
  /// dikeluarkan admin kantor. Tautan ini menjelaskan itu di tempat, alih-alih
  /// membuka layar yang belum ada tujuannya.
  void _lupaPassword() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text(
          'Kode dan password diberikan admin kantor. Hubungi kantor bila lupa.',
        ),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final sedangProses = context.watch<ProviderAuth>().sedangProses;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: WarnaApp.surface,
        // resizeToAvoidBottomInset dibiarkan aktif dan seluruh isi digulirkan,
        // supaya kolom password tidak tertutup papan ketik di layar pendek.
        body: SafeArea(
          // minHeight setinggi viewport + mainAxisAlignment.center: selama
          // isinya masih muat, seluruh blok duduk di tengah layar sehingga
          // ruang kosong terbagi rata atas-bawah. Begitu papan ketik muncul
          // dan ruang menyempit, Column kembali setinggi isinya dan layar
          // bisa digulir seperti biasa.
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, batas) => SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: batas.maxHeight - 32),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Ilustrasi yang sama dengan Splash, lebih
                              // kecil — yang berpindah cuma ukuran & posisi.
                              const Center(
                                  child: LogoApp(ukuran: 150, tag: tagLogo)),
                              const SizedBox(height: 24),
                              MasukBertahap(
                                jeda: const Duration(milliseconds: 80),
                                child: _formulir(sedangProses),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Info sekunder duduk di dasar layar, di luar area yang
              // digulir — tombol "Masuk" sengaja tetap menempel pada form
              // di atasnya supaya terbaca sebagai tindakan akhir isian,
              // bukan tombol lepas yang kebetulan ada di bawah.
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Text(
                  'Tani Makmur Driver versi ${KonstantaApi.versiApp}',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: WarnaApp.textHint),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _formulir(bool sedangProses) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Selamat Datang',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: WarnaApp.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Masuk untuk mulai pengiriman hari ini',
            style: TextStyle(fontSize: 14, color: WarnaApp.textSecondary),
          ),
          const SizedBox(height: 32),
          const _LabelKolom('Kode Driver'),
          const SizedBox(height: 8),
          _kolomKode(sedangProses),
          const SizedBox(height: 16),
          const _LabelKolom('Password'),
          const SizedBox(height: 8),
          _kolomPassword(sedangProses),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: sedangProses ? null : _lupaPassword,
              child: const Text('Lupa Password?'),
            ),
          ),
          const SizedBox(height: 16),
          // Tombol menyusul setelah form: urutannya mengarahkan mata dari
          // judul → kolom isian → tindakan. Jaraknya sengaja lebih lega dari
          // jarak antar kolom, supaya tombol terbaca sebagai tindakan akhir,
          // bukan bagian dari daftar isian.
          MasukBertahap(
            jeda: const Duration(milliseconds: 220),
            geser: 8,
            child: FilledButton(
              onPressed: sedangProses ? null : _masuk,
              child: sedangProses
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Masuk'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kolomKode(bool sedangProses) {
    return TextFormField(
      controller: _kodeCtrl,
      enabled: !sedangProses,
      textCapitalization: TextCapitalization.characters,
      textInputAction: TextInputAction.next,
      // Kode selalu huruf besar; mengubahnya di sini menghindari salah ketik
      // yang tampak seperti kode salah.
      inputFormatters: [UpperCaseTextFormatter()],
      onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
      decoration: const InputDecoration(
        hintText: 'DRV-001',
        prefixIcon: Icon(Icons.badge_outlined),
      ),
      validator: (nilai) => (nilai == null || nilai.trim().isEmpty)
          ? 'Kode driver wajib diisi'
          : null,
    );
  }

  Widget _kolomPassword(bool sedangProses) {
    return TextFormField(
      controller: _passwordCtrl,
      focusNode: _passwordFocus,
      enabled: !sedangProses,
      obscureText: _sembunyikanPassword,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _masuk(),
      decoration: InputDecoration(
        hintText: 'Masukkan password',
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(
            _sembunyikanPassword ? Icons.visibility_off : Icons.visibility,
          ),
          tooltip: _sembunyikanPassword ? 'Lihat password' : 'Sembunyikan',
          onPressed: () =>
              setState(() => _sembunyikanPassword = !_sembunyikanPassword),
        ),
      ),
      validator: (nilai) =>
          (nilai == null || nilai.isEmpty) ? 'Password wajib diisi' : null,
    );
  }
}

class _LabelKolom extends StatelessWidget {
  const _LabelKolom(this.teks);

  final String teks;

  @override
  Widget build(BuildContext context) {
    return Text(
      teks,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: WarnaApp.textPrimary,
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue lama,
    TextEditingValue baru,
  ) {
    return TextEditingValue(
      text: baru.text.toUpperCase(),
      selection: baru.selection,
    );
  }
}
