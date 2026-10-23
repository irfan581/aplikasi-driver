import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/model/model_driver.dart';
import '../../../inti/tema/warna_app.dart';
import '../../../rute/nama_rute.dart';
import '../../provider/provider_auth.dart';
import '../../provider/provider_chat.dart';
import '../../provider/provider_riwayat.dart';
import '../../provider/provider_tugas.dart';
import '../../widget/umum/lembar_konfirmasi.dart';
import '../../widget/umum/kepala_warna.dart';

/// Data akun driver, ganti password, dan keluar.
///
/// Tombol keluar tinggal di sini, bukan di pojok beranda: di sana ia
/// bersebelahan dengan area yang sering disentuh saat menarik daftar tugas,
/// dan driver yang tidak sengaja menekannya harus mengetik kode serta
/// password lagi di tengah pekerjaan.
class LayarProfil extends StatefulWidget {
  const LayarProfil({super.key});

  @override
  State<LayarProfil> createState() => _LayarProfilState();
}

class _LayarProfilState extends State<LayarProfil> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Percobaan diam-diam di splash bisa saja gagal (sinyal sempat
      // hilang) — begitu driver benar-benar membuka tab ini, dicoba lagi
      // kalau memang belum berhasil. RefreshIndicator di bawah jadi jalan
      // keluar manual kalau ini pun gagal lagi.
      final auth = context.read<ProviderAuth>();
      if (auth.driver == null) auth.muatProfil();
    });
  }

  Future<void> _keluar(BuildContext context) async {
    final ya = await tanyaKonfirmasi(
      context,
      judul: 'Keluar dari aplikasi?',
      keterangan: 'Anda perlu memasukkan kode dan password lagi untuk masuk. '
          'Hubungi kantor kalau lupa passwordnya.',
      labelYa: 'Ya, Keluar',
      ikon: Icons.logout,
      merah: true,
    );

    if (!ya || !context.mounted) return;

    context.read<ProviderTugas>().bersihkan();
    context.read<ProviderRiwayat>().bersihkan();
    context.read<ProviderChat>().bersihkan();
    await context.read<ProviderAuth>().logout();

    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(NamaRute.login, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final driver = context.watch<ProviderAuth>().driver;

    return Scaffold(
      backgroundColor: WarnaApp.background,
      body: Stack(children: [
        RefreshIndicator(
          onRefresh: () => context.read<ProviderAuth>().muatProfil(),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              24,
              MediaQuery.of(context).padding.top + 32,
              24,
              32,
            ),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              _kepala(driver),
              const SizedBox(height: 28),
              if (driver == null) _memuat() else ..._data(driver),
              const SizedBox(height: 28),
              _tombolGantiPassword(),
              const SizedBox(height: 12),
              _tombolKeluar(),
            ],
          ),
        ),
        const TudungStatus(warna: WarnaApp.background)
      ]),
    );
  }

  // ── Kepala ────────────────────────────────────────────────────

  Widget _kepala(ModelDriver? driver) {
    final nama = driver?.namaDriver ?? 'Driver';

    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: WarnaApp.primary,
            borderRadius: BorderRadius.circular(26),
          ),
          alignment: Alignment.center,
          child: Text(
            _inisial(nama),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: WarnaApp.textWhite,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          nama,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: WarnaApp.textPrimary,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          driver?.kodeDriver == null
              ? 'Driver Tani Makmur'
              : 'Driver ${driver!.kodeDriver}',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: WarnaApp.textSecondary,
          ),
        ),
      ],
    );
  }

  /// Dua huruf dari kata pertama dan terakhir — "Slamet Riyadi" jadi "SR".
  /// Nama satu kata memakai dua huruf pertamanya supaya kotaknya tidak
  /// terlihat separuh kosong.
  String _inisial(String nama) {
    final kata = nama.trim().split(RegExp(r'\s+')).where((k) => k.isNotEmpty);

    if (kata.isEmpty) return 'TM';
    if (kata.length == 1) {
      final satu = kata.first;
      return (satu.length == 1 ? satu : satu.substring(0, 2)).toUpperCase();
    }

    return '${kata.first[0]}${kata.last[0]}'.toUpperCase();
  }

  // ── Data diri ─────────────────────────────────────────────────

  List<Widget> _data(ModelDriver driver) {
    final baris = <Widget>[
      _kartuInfo(Icons.call_outlined, 'Nomor HP', driver.noTelepon),
      _kartuInfo(Icons.badge_outlined, 'SIM', driver.jenisSim),
      _kartuInfo(Icons.home_outlined, 'Alamat', driver.alamat),
      // Ikon truk, bukan ikon orang seperti sebelumnya: barisnya bicara soal
      // kendaraan, dan ikon orang di sini membuatnya terbaca sebagai data diri.
      _kartuInfo(
        Icons.local_shipping_outlined,
        'Kendaraan',
        driver.kendaraan.isEmpty
            ? null
            : driver.kendaraan.map((k) => k.nomorPolisi).join(', '),
        kosong: 'Belum ada kendaraan tetap atas nama Anda',
      ),
    ];

    return [
      for (var i = 0; i < baris.length; i++) ...[
        if (i > 0) const SizedBox(height: 12),
        baris[i],
      ],
    ];
  }

  Widget _kartuInfo(
    IconData ikon,
    String label,
    String? nilai, {
    String kosong = 'Belum diisi',
  }) {
    final ada = nilai != null && nilai.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WarnaApp.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: WarnaApp.surfaceMuted),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: WarnaApp.secondary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(ikon, color: WarnaApp.primary, size: 21),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: WarnaApp.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  ada ? nilai : kosong,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: ada ? FontWeight.w700 : FontWeight.w500,
                    height: 1.35,
                    // Yang belum terisi ditulis lebih redup supaya tidak
                    // terbaca sebagai data sungguhan sekilas pandang.
                    color: ada ? WarnaApp.textPrimary : WarnaApp.textHint,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _memuat() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(child: CircularProgressIndicator()),
      );

  // ── Tombol ────────────────────────────────────────────────────

  Widget _tombolGantiPassword() {
    return OutlinedButton.icon(
      onPressed: () => Navigator.pushNamed(context, NamaRute.gantiPassword),
      icon: const Icon(Icons.lock_outline, size: 20),
      label: const Text('Ganti Password'),
      style: OutlinedButton.styleFrom(
        foregroundColor: WarnaApp.textPrimary,
        backgroundColor: WarnaApp.surface,
        minimumSize: const Size.fromHeight(56),
        side: const BorderSide(color: WarnaApp.surfaceMuted),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _tombolKeluar() {
    return OutlinedButton.icon(
      onPressed: () => _keluar(context),
      icon: const Icon(Icons.logout, size: 20),
      label: const Text('Keluar Akun'),
      style: OutlinedButton.styleFrom(
        foregroundColor: WarnaApp.error,
        backgroundColor: WarnaApp.errorBg,
        minimumSize: const Size.fromHeight(56),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    );
  }
}
