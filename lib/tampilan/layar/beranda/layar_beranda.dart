import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../data/model/model_tugas.dart';
import '../../../inti/tema/warna_app.dart';
import '../../../rute/nama_rute.dart';
import '../../provider/provider_auth.dart';
import '../../provider/provider_tugas.dart';
import '../../widget/beranda/kartu_ringkasan.dart';
import '../../widget/beranda/kepala_beranda.dart';
import '../../widget/pengiriman/kartu_rit.dart';
import '../../widget/pengiriman/kartu_rit_aktif.dart';
import '../../widget/umum/keadaan_kosong.dart';
import '../../widget/umum/masuk_bertahap.dart';
import '../laporan/layar_laporan.dart';
import '../../widget/umum/kepala_warna.dart';

class LayarBeranda extends StatefulWidget {
  const LayarBeranda({super.key});

  @override
  State<LayarBeranda> createState() => _LayarBerandaState();
}

class _LayarBerandaState extends State<LayarBeranda>
    with WidgetsBindingObserver {
  Timer? _pemantauBerkala;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tugas = context.read<ProviderTugas>();
      tugas.muat();
      // Dilepas tanpa ditunggu: rekap 30 hari cuma pelengkap, dan menahan
      // beranda sampai hitungannya sampai membuat daftar kiriman hari ini —
      // alasan sebenarnya driver membuka aplikasi — telat muncul.
      tugas.muatRingkasan();
    });

    // Tanpa notifikasi push, driver harus tahu ada kiriman baru dari sisi
    // aplikasi sendiri: dicek ulang tiap ia kembali membuka aplikasi (lihat
    // didChangeAppLifecycleState) dan secara berkala selama beranda terbuka
    // di depan — supaya rencana yang baru dibuat admin tidak menunggu driver
    // sadar untuk menarik layar.
    _pemantauBerkala = Timer.periodic(
      const Duration(minutes: 2),
      (_) => context.read<ProviderTugas>().muat(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<ProviderTugas>().muat();
    }
  }

  @override
  void dispose() {
    _pemantauBerkala?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Rit yang sedang dikerjakan: yang pertama belum tuntas menurut urutan rit.
  /// Driver mengerjakan rit satu per satu, jadi hanya ada satu yang layak
  /// diangkat ke atas.
  ModelTugas? _ritAktif(List<ModelTugas> semua) {
    for (final r in semua) {
      if (!r.selesai && !r.dibatalkan) return r;
    }
    return null;
  }

  /// Membuka layar laporan untuk tujuan berikutnya yang belum dilaporkan.
  ///
  /// Dulu tombol ini menaikkan status rit. Sejak tahapan rit dicabut, yang
  /// paling berguna di beranda adalah lompatan langsung ke pekerjaan yang
  /// memang sedang menunggu — driver tidak perlu masuk detail rit dulu.
  Future<void> _bukaTujuanBerikutnya(ModelTugas rit) async {
    ModelTugasItem? berikutnya;
    for (final item in rit.items) {
      if (!item.tuntas) {
        berikutnya = item;
        break;
      }
    }

    if (berikutnya == null) return;

    await Navigator.of(context).pushNamed(
      NamaRute.laporan,
      arguments: ArgumenLaporan(ritId: rit.id, itemId: berikutnya.id),
    );

    if (!mounted) return;
    await context.read<ProviderTugas>().muat();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<ProviderAuth>();
    final tugas = context.watch<ProviderTugas>();

    return Scaffold(
      body: Stack(children: [
        RefreshIndicator(
          onRefresh: () async {
            final tugas = context.read<ProviderTugas>();
            await tugas.muat();
            await tugas.muatRingkasan();
          },
          // Tanpa ini, lingkaran refresh muncul di dekat pucuk layar dan
          // menutupi sapaan di kepala — bawaan RefreshIndicator tidak tahu
          // kepala kustom di bawahnya setinggi apa.
          edgeOffset: MediaQuery.of(context).padding.top + 96,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: MasukBertahap(
                  child: KepalaBeranda(nama: auth.namaSapaan),
                ),
              ),
              ..._isi(tugas),
              if (tugas.ringkasan != null)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  sliver: SliverToBoxAdapter(
                    child: MasukBertahap(
                      jeda: const Duration(milliseconds: 220),
                      child: KartuRingkasan(ringkasan: tugas.ringkasan!),
                    ),
                  ),
                ),
              // Pemberitahuan "belum ada kiriman" ditaruh SETELAH rekap 30 hari,
              // bukan sebelumnya. Saat hari ini kosong, yang berguna dilihat
              // driver justru rekap kerjanya — kabar kosong cukup jadi catatan
              // penutup, bukan hal pertama yang memenuhi layar.
              if (_kosongHariIni(tugas)) ..._kartuKosong(),
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],
          ),
        ),
        const TudungStatus()
      ]),
    );
  }

  /// Kunci tanggal hari ini, bentuknya sama dengan `tanggal_muatan` dari
  /// server ('yyyy-MM-dd') sehingga bisa dibandingkan sebagai teks biasa.
  String get _kunciHariIni => DateFormat('yyyy-MM-dd').format(DateTime.now());

  /// Rit yang memang untuk dikerjakan sekarang: hari ini, ditambah rit
  /// kemarin yang lupa ditutup dan masih dibawa server.
  List<ModelTugas> _ritSekarang(List<ModelTugas> semua) => semua
      .where((r) => r.tanggalMuatan.compareTo(_kunciHariIni) <= 0)
      .toList();

  /// Rit yang sudah ditugaskan tapi tanggalnya belum tiba.
  ///
  /// Server sekarang mengirimkannya begitu admin mengisi nama sopir — kantor
  /// menginput sore untuk besok, jadi sopir bisa bersiap sejak malam. Dipisah
  /// dari yang di atas supaya tidak ada yang keliru dikerjakan hari ini.
  List<ModelTugas> _ritNanti(List<ModelTugas> semua) =>
      semua.where((r) => r.tanggalMuatan.compareTo(_kunciHariIni) > 0).toList();

  /// Benar-benar tidak ada kiriman untuk dikerjakan sekarang — bukan sedang
  /// memuat, dan bukan gagal memuat (keduanya punya tampilannya sendiri di
  /// [_isi]). Rit besok tidak menghitung: hari ini tetap kosong.
  bool _kosongHariIni(ProviderTugas tugas) =>
      tugas.pesanError == null &&
      !tugas.sedangMemuat &&
      _ritSekarang(tugas.rit).isEmpty;

  List<Widget> _kartuKosong() => [
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(24, 16, 24, 0),
          sliver: SliverToBoxAdapter(
            child: KeadaanKosong(
              ikon: Icons.event_available_outlined,
              judul: 'Belum ada kiriman hari ini',
              keterangan: 'Kalau seharusnya ada, tarik layar ke bawah untuk '
                  'memuat ulang atau hubungi kantor.',
            ),
          ),
        ),
      ];

  List<Widget> _isi(ProviderTugas tugas) {
    if (tugas.sedangMemuat && tugas.rit.isEmpty) {
      return [
        const SliverPadding(
          padding: EdgeInsets.only(top: 80),
          sliver: SliverToBoxAdapter(
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ];
    }

    if (tugas.pesanError != null && tugas.rit.isEmpty) {
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          sliver: SliverToBoxAdapter(
            child: KeadaanKosong(
              ikon: Icons.wifi_off_rounded,
              judul: 'Gagal memuat tugas',
              keterangan: tugas.pesanError,
              aksi: OutlinedButton.icon(
                onPressed: () => context.read<ProviderTugas>().muat(),
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
              ),
            ),
          ),
        ),
      ];
    }

    // Keadaan kosong tidak dikembalikan di sini — lihat [_kartuKosong], yang
    // dipasang setelah kartu rekap 30 hari di build().
    if (tugas.kosong) return const [];

    final sekarang = _ritSekarang(tugas.rit);
    final nanti = _ritNanti(tugas.rit);

    // Rit yang tanggalnya belum tiba tidak boleh diangkat jadi "sedang
    // dikerjakan" — tombolnya membuka layar laporan, dan sopir bisa terlanjur
    // menutup tujuan yang seharusnya dikerjakan besok.
    final aktif = _ritAktif(sekarang);
    final lain = sekarang.where((r) => r.id != aktif?.id).toList();

    return [
      if (aktif != null)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _JudulBagian('Sedang dikerjakan'),
                const SizedBox(height: 10),
                MasukBertahap(
                  jeda: const Duration(milliseconds: 120),
                  child: KartuRitAktif(
                    rit: aktif,
                    sedangProses: tugas.sedangMengubah,
                    onTap: () => Navigator.pushNamed(
                      context,
                      NamaRute.detailTugas,
                      arguments: aktif.id,
                    ),
                    onAksi: () => _bukaTujuanBerikutnya(aktif),
                  ),
                ),
              ],
            ),
          ),
        ),
      if (lain.isNotEmpty) ...[
        SliverPadding(
          padding: EdgeInsets.fromLTRB(24, aktif == null ? 8 : 24, 24, 12),
          sliver: SliverToBoxAdapter(
            child: _JudulBagian(aktif == null ? 'Rit hari ini' : 'Rit lainnya'),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverList.separated(
            itemCount: lain.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => KartuRit(
              rit: lain[i],
              onTap: () => Navigator.pushNamed(
                context,
                NamaRute.detailTugas,
                arguments: lain[i].id,
              ),
            ),
          ),
        ),
      ],
      ..._bagianNanti(nanti, adaDiAtas: aktif != null || lain.isNotEmpty),
    ];
  }

  /// Rit yang tanggalnya belum tiba, dikelompokkan per tanggal.
  ///
  /// Tanggalnya ditulis di setiap kelompok karena kartu rit tidak
  /// menampilkannya — tanpa itu, rit besok tidak bisa dibedakan dari rit hari
  /// ini selain dari posisinya di layar, dan itu terlalu tipis untuk sesuatu
  /// yang bisa membuat sopir berangkat sehari lebih awal.
  List<Widget> _bagianNanti(List<ModelTugas> nanti, {required bool adaDiAtas}) {
    if (nanti.isEmpty) return const [];

    // Dikelompokkan sekali di sini, bukan disaring ulang di dalam itemBuilder —
    // itemBuilder dipanggil tiap kartu digambar dan tiap kali digulir.
    final perTanggal = <String, List<ModelTugas>>{};
    for (final r in nanti) {
      perTanggal.putIfAbsent(r.tanggalMuatan, () => []).add(r);
    }
    final tanggal = perTanggal.keys.toList()..sort();

    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(24, adaDiAtas ? 24 : 8, 24, 12),
        sliver: const SliverToBoxAdapter(child: _JudulBagian('Berikutnya')),
      ),
      for (final t in tanggal) ...[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          sliver: SliverToBoxAdapter(child: _LabelTanggal(t)),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 6),
          sliver: SliverList.separated(
            itemCount: perTanggal[t]!.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final rit = perTanggal[t]![i];
              return KartuRit(
                rit: rit,
                onTap: () => Navigator.pushNamed(
                  context,
                  NamaRute.detailTugas,
                  arguments: rit.id,
                ),
              );
            },
          ),
        ),
      ],
    ];
  }
}

/// Penanda tanggal di atas kelompok rit yang belum tiba harinya.
class _LabelTanggal extends StatelessWidget {
  const _LabelTanggal(this.tanggal);

  final String tanggal;

  @override
  Widget build(BuildContext context) {
    final waktu = DateTime.tryParse(tanggal);
    final besok = DateTime.now().add(const Duration(days: 1));

    // "Besok" lebih cepat ditangkap daripada tanggalnya, dan itu yang paling
    // sering muncul: kantor menginput sore untuk hari berikutnya.
    final teks = waktu == null
        ? tanggal
        : (waktu.year == besok.year &&
                waktu.month == besok.month &&
                waktu.day == besok.day)
            ? 'Besok, ${DateFormat('d MMMM', 'id_ID').format(waktu)}'
            : DateFormat('EEEE, d MMMM', 'id_ID').format(waktu);

    return Row(
      children: [
        const Icon(Icons.schedule, size: 14, color: WarnaApp.textHint),
        const SizedBox(width: 6),
        Text(
          teks,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: WarnaApp.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _JudulBagian extends StatelessWidget {
  const _JudulBagian(this.teks);

  final String teks;

  @override
  Widget build(BuildContext context) {
    // Kalimat biasa berukuran 15sp, bukan huruf kapital 12sp berjarak lebar.
    // Judul bagian perlu terbaca sekilas sambil menggulir dengan satu tangan;
    // huruf kapital kecil justru memaksa mata membaca huruf per huruf.
    return Text(
      teks,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: WarnaApp.textPrimary,
      ),
    );
  }
}
