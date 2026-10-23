import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../data/model/model_tugas.dart';
import '../../../inti/tema/warna_app.dart';
import '../../../rute/nama_rute.dart';
import '../../provider/provider_riwayat.dart';
import '../../widget/pengiriman/kartu_rit.dart';
import '../../widget/umum/keadaan_kosong.dart';
import '../../widget/umum/kepala_warna.dart';

/// Riwayat kiriman driver, sejak rit pertama.
///
/// Daftarnya dimuat per halaman dan bertambah sambil digulir — driver lama
/// bisa punya ratusan rit, dan menariknya sekaligus membakar kuota di daerah
/// bersinyal buruk.
class LayarRiwayat extends StatefulWidget {
  const LayarRiwayat({super.key});

  @override
  State<LayarRiwayat> createState() => _LayarRiwayatState();
}

class _LayarRiwayatState extends State<LayarRiwayat> {
  final _gulir = ScrollController();

  @override
  void initState() {
    super.initState();
    _gulir.addListener(_saatMenggulir);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProviderRiwayat>().muat();
    });
  }

  @override
  void dispose() {
    _gulir.removeListener(_saatMenggulir);
    _gulir.dispose();
    super.dispose();
  }

  /// Halaman berikutnya diminta sebelum daftar benar-benar habis, supaya
  /// sambungannya tidak terasa tersendat saat digulir cepat.
  void _saatMenggulir() {
    if (!_gulir.hasClients) return;

    final sisa = _gulir.position.maxScrollExtent - _gulir.position.pixels;
    if (sisa < 600) context.read<ProviderRiwayat>().muatLagi();
  }

  @override
  Widget build(BuildContext context) {
    final riwayat = context.watch<ProviderRiwayat>();

    return Scaffold(
      body: Stack(children: [
        RefreshIndicator(
          onRefresh: () => context.read<ProviderRiwayat>().muat(),
          edgeOffset: MediaQuery.of(context).padding.top + 96,
          child: CustomScrollView(
            controller: _gulir,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: KepalaWarna(
                  atasJudul: 'Kiriman yang sudah lewat',
                  judul: 'Riwayat',
                  subjudul: riwayat.total > 0
                      ? '${riwayat.total} rit tersimpan'
                      : null,
                ),
              ),
              ..._isi(riwayat),
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],
          ),
        ),
        const TudungStatus()
      ]),
    );
  }

  List<Widget> _isi(ProviderRiwayat riwayat) {
    if (riwayat.sedangMemuat && riwayat.rit.isEmpty) {
      return [
        const SliverPadding(
          padding: EdgeInsets.only(top: 80),
          sliver: SliverToBoxAdapter(
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ];
    }

    if (riwayat.pesanError != null && riwayat.rit.isEmpty) {
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          sliver: SliverToBoxAdapter(
            child: KeadaanKosong(
              ikon: Icons.wifi_off_rounded,
              judul: 'Gagal memuat riwayat',
              keterangan: riwayat.pesanError,
              aksi: OutlinedButton.icon(
                onPressed: () => context.read<ProviderRiwayat>().muat(),
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
              ),
            ),
          ),
        ),
      ];
    }

    if (riwayat.kosong) {
      return [
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(24, 8, 24, 0),
          sliver: SliverToBoxAdapter(
            child: KeadaanKosong(
              ikon: Icons.receipt_long_outlined,
              judul: 'Belum ada riwayat',
              keterangan: 'Kiriman yang sudah selesai akan tercatat di sini.',
            ),
          ),
        ),
      ];
    }

    // Rit dikelompokkan per tanggal: driver mencari lewat "hari apa", bukan
    // lewat nomor rit, jadi tanggal jadi penanda utamanya.
    final kelompok = _kelompokkanPerTanggal(riwayat.rit);

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
        sliver: SliverList.builder(
          itemCount: kelompok.length,
          itemBuilder: (context, i) => _blokTanggal(kelompok[i]),
        ),
      ),
      if (riwayat.sedangMemuatLagi)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            ),
          ),
        ),
      // Kegagalan saat menambah halaman ditampilkan sebagai catatan kecil di
      // kaki daftar, bukan menggantikan isi yang sudah termuat.
      if (riwayat.pesanError != null && riwayat.rit.isNotEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    riwayat.pesanError!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: WarnaApp.textSecondary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => context.read<ProviderRiwayat>().muatLagi(),
                  child: const Text('Coba lagi'),
                ),
              ],
            ),
          ),
        ),
      if (!riwayat.adaLagi && riwayat.rit.isNotEmpty)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(top: 20),
            child: Center(
              child: Text(
                'Sudah sampai riwayat paling awal',
                style: TextStyle(fontSize: 12, color: WarnaApp.textHint),
              ),
            ),
          ),
        ),
    ];
  }

  Widget _blokTanggal(_KelompokTanggal kelompok) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 10),
          child: Text(
            kelompok.label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              color: WarnaApp.textPrimary,
            ),
          ),
        ),
        ...kelompok.rit.map((rit) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: KartuRit(
                rit: rit,
                onTap: () => Navigator.pushNamed(
                  context,
                  NamaRute.detailTugas,
                  arguments: rit.id,
                ),
              ),
            )),
      ],
    );
  }

  List<_KelompokTanggal> _kelompokkanPerTanggal(List<ModelTugas> rit) {
    final peta = <String, List<ModelTugas>>{};
    for (final r in rit) {
      peta.putIfAbsent(r.tanggalMuatan, () => []).add(r);
    }

    return peta.entries
        .map((e) => _KelompokTanggal(label: _labelTanggal(e.key), rit: e.value))
        .toList();
  }

  String _labelTanggal(String tanggal) {
    final waktu = DateTime.tryParse(tanggal);
    if (waktu == null) return tanggal;

    final hariIni = DateTime.now();
    final kemarin = hariIni.subtract(const Duration(days: 1));

    bool samaHari(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;

    if (samaHari(waktu, hariIni)) return 'Hari ini';
    if (samaHari(waktu, kemarin)) return 'Kemarin';

    return DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(waktu);
  }
}

class _KelompokTanggal {
  const _KelompokTanggal({required this.label, required this.rit});

  final String label;
  final List<ModelTugas> rit;
}
