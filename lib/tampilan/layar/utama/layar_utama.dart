import 'package:flutter/material.dart';

import '../../../data/servis/servis_notifikasi.dart';
import '../beranda/layar_beranda.dart';
import '../profil/layar_profil.dart';
import '../riwayat/layar_riwayat.dart';

/// Rangka utama aplikasi: tiga bagian yang selalu terjangkau ibu jari.
///
/// Driver memakai aplikasi ini sambil berdiri di gudang atau di bak truk,
/// sering dengan satu tangan dan tergesa. Perpindahan antar bagian tidak boleh
/// lewat menu yang harus dicari dulu.
///
/// Tab Grup sengaja dilepas, bukan dihapus. Kantor masih menimbang bentuk
/// akhirnya, jadi `LayarChat`, `ProviderChat`, dan repositorinya dibiarkan utuh
/// di tempatnya — mengembalikannya nanti cukup menambahkan satu tujuan navigasi
/// di sini. Selama tabnya tidak ada, layar chat tidak pernah dipasang, dan
/// karena layar itu yang membuka koneksi realtime, websocket-nya ikut diam
/// dengan sendirinya tanpa perlu dimatikan terpisah.
class LayarUtama extends StatefulWidget {
  const LayarUtama({super.key, this.tabAwal = 0});

  final int tabAwal;

  @override
  State<LayarUtama> createState() => _LayarUtamaState();
}

class _LayarUtamaState extends State<LayarUtama> {
  late int _terpilih = widget.tabAwal;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => ServisNotifikasi.bukaRitTertunda());
  }

  void _pindahTab(int i) => setState(() => _terpilih = i);

  /// IndexedStack, bukan membangun ulang halaman tiap pindah tab: daftar tugas
  /// yang sudah termuat harus bertahan, supaya driver di daerah bersinyal
  /// buruk tidak menunggu permintaan jaringan baru setiap kali menengok tab
  /// sebelah lalu kembali.
  static const _halaman = [
    LayarBeranda(),
    LayarRiwayat(),
    LayarProfil(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _terpilih, children: _halaman),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _terpilih,
        onDestinationSelected: _pindahTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Riwayat',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
