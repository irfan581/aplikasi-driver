import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/model/model_tugas.dart';
import '../../../inti/tema/warna_app.dart';
import '../../../rute/nama_rute.dart';
import '../../provider/provider_auth.dart';
import '../../provider/provider_tugas.dart';
import '../../widget/umum/kepala_warna.dart';
import '../../widget/umum/lencana_status.dart';
import '../laporan/layar_laporan.dart';

/// Isi satu rit: keterangan kendaraan, lalu daftar tujuan yang harus dilaporkan.
///
/// Layar ini tidak lagi punya tombol tahapan rit. Dulu driver harus menekan
/// "mulai muat", "berangkat", dan "selesaikan rit" — tiga tap yang tidak
/// mengubah apa pun di dunia nyata, gampang terlupa saat buru-buru, dan
/// membuat rit tampak menggantung padahal barangnya sudah turun semua.
/// Sekarang statusnya disimpulkan server dari laporan yang masuk, jadi yang
/// tersisa di sini murni pekerjaan: satu tombol per tujuan.
class LayarDetailTugas extends StatefulWidget {
  const LayarDetailTugas({super.key, required this.ritId});

  final int ritId;

  @override
  State<LayarDetailTugas> createState() => _LayarDetailTugasState();
}

class _LayarDetailTugasState extends State<LayarDetailTugas> {
  // Satu tempat untuk jarak yang dipakai berulang, supaya seluruh halaman
  // konsisten dan gampang disetel ulang sekaligus alih-alih angka lepas
  // bertebaran di tiap widget.
  static const double _padH = 18; // padding horizontal seluruh halaman
  static const double _gapSeksi = 16; // jarak antar section besar
  static const double _gapKecil = 12; // jarak dalam satu section

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProviderTugas>().muatDetail(widget.ritId);
    });
  }

  ModelTugas? get _rit => context.watch<ProviderTugas>().cariRit(widget.ritId);

  Future<void> _bukaLaporan(ModelTugasItem item) async {
    await Navigator.of(context).pushNamed(
      NamaRute.laporan,
      arguments: ArgumenLaporan(ritId: widget.ritId, itemId: item.id),
    );

    if (!mounted) return;

    // Status tujuan dan jumlah fotonya bisa berubah di layar laporan,
    // termasuk lewat antrian foto yang baru terkirim di sana.
    context.read<ProviderTugas>().muatDetail(widget.ritId);
  }

  @override
  Widget build(BuildContext context) {
    final rit = _rit;

    if (rit == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: WarnaApp.background,
      body: Stack(children: [
        RefreshIndicator(
          onRefresh: () async {
            await context.read<ProviderTugas>().muatDetail(widget.ritId);
          },
          // Tanpa ini, lingkaran refresh muncul di dekat pucuk layar dan
          // menutupi judul di kepala berwarna — bawaan RefreshIndicator tidak
          // tahu kepala kustom di bawahnya setinggi apa.
          edgeOffset: MediaQuery.of(context).padding.top + 175,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _kepala(rit)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(_padH, _gapSeksi, _padH, 28),
                sliver: SliverList.list(
                  children: [
                    if (rit.dibatalkan) ...[
                      _catatanKecil(
                        Icons.block,
                        'Rit ini dibatalkan admin. Hubungi kantor.',
                        warna: WarnaApp.error,
                      ),
                      const SizedBox(height: _gapSeksi),
                    ],
                    _konteksRit(rit),
                    _judul('Tujuan (${rit.jumlahTujuan})'),
                    const SizedBox(height: _gapKecil),
                    ...List.generate(rit.items.length, (i) {
                      return _kartuTujuan(
                        rit,
                        rit.items[i],
                        terakhir: i == rit.items.length - 1,
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
        const TudungStatus()
      ]),
    );
  }

  // ── Kepala ────────────────────────────────────────────────────

  Widget _kepala(ModelTugas rit) {
    return KepalaWarna(
      adaTombolKembali: true,
      // Nomor polisi ikut di sini, bukan berdiri sendiri di bawah kepala —
      // ia bagian dari identitas ritnya ("rit 1 pakai truk yang mana"),
      // bukan keterangan lepas yang menggantung tanpa label.
      atasJudul: [
        rit.subsidi ? 'Muatan subsidi' : 'Muatan non-subsidi',
        if (rit.kendaraan?.nomorPolisi != null) rit.kendaraan!.nomorPolisi,
      ].join(', '),
      judul: 'Rit ${rit.nomorRit}',
      // Dua kolom: sisa tujuan di kiri, total muatan di kanan, dipisah garis
      // tipis. Dulu ada baris kedua "0 dari 1 tujuan" di bawah kalimat sisa
      // tujuan — dua kalimat untuk satu fakta yang sama, dan jumlah totalnya
      // toh sudah tertulis di judul daftar tujuan tepat di bawahnya.
      isi: KotakKepala(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    // Kalimat, bukan nama status. "Berangkat" tidak berarti apa
                    // pun buat driver yang memang sedang di jalan; yang ia
                    // butuhkan adalah tinggal berapa toko lagi.
                    _ringkasan(rit),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: WarnaApp.textPrimary,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 1,
              height: 32,
              margin: const EdgeInsets.symmetric(horizontal: 14),
              color: WarnaApp.primary.withValues(alpha: 0.2),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _angka(rit.totalMuatanTon),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    // Satu-satunya angka oranye di kepala: total muatan
                    // adalah hal pertama yang dicari driver di layar ini.
                    color: WarnaApp.primary,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'ton muatan',
                  style: TextStyle(
                    fontSize: 11,
                    color: WarnaApp.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _ringkasan(ModelTugas rit) {
    if (rit.dibatalkan) return 'Rit dibatalkan';
    if (rit.selesai) return 'Semua tujuan selesai';
    if (rit.tujuanTersisa == 1) return 'Tinggal 1 tujuan';
    return 'Tinggal ${rit.tujuanTersisa} tujuan';
  }

  // ── Konteks rit ──────────────────────────────────────────────

  /// Satu baris keterangan rit, menggantikan kartu empat baris.
  ///
  /// Kartu lamanya berisi Kendaraan, Total muatan, Jenis muatan, dan Ceker —
  /// tiga dari empat baris itu mengulang apa yang sudah tertulis di kepala
  /// layar, dan yang keempat menampilkan "-" saat ceker belum ditunjuk.
  /// Setiap baris juga diberi ikon yang tidak membantu membaca apa pun.
  ///
  /// Yang tersisa di sini cuma yang benar-benar baru: nomor polisi, dan nama
  /// ceker kalau memang ada. Sisanya sudah di kepala.
  Widget _konteksRit(ModelTugas rit) {
    // Nomor polisi sudah ikut di kepala; yang tersisa cuma ceker, dan itu
    // pun sering belum ditunjuk — kalau kosong barisnya hilang sama sekali,
    // bukan menampilkan "-" seperti kartu lama.
    if (rit.checker == null || rit.checker!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: _gapSeksi),
      child: Text(
        'Ceker gudang: ${rit.checker}',
        style: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: WarnaApp.textSecondary,
        ),
      ),
    );
  }

  Widget _kartuTujuan(
    ModelTugas rit,
    ModelTugasItem item, {
    required bool terakhir,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: terakhir ? 0 : _gapKecil + 2),
      child: _kartu(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Nomor urutan cukup jadi label kecil di dalam kartu —
                      // statusnya sendiri sudah cukup terwakili oleh lencana
                      // di kanan, jadi tidak perlu lagi lingkaran bertimeline
                      // terpisah di luar kartu.
                      Text(
                        'Tujuan ${item.urutan}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: WarnaApp.textHint,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Nama toko dibuat paling menonjol di kartu —
                      // itulah yang pertama dicari driver saat
                      // membandingkan daftar tujuan dengan yang ada
                      // di depan matanya.
                      Text(
                        item.lokasiPengiriman,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: WarnaApp.textPrimary,
                          height: 1.2,
                        ),
                      ),
                      if (item.kodeArea != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          item.kodeArea!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: WarnaApp.textSecondary,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Tujuan yang belum dikerjakan tidak diberi lencana sama
                // sekali. Dulu tertulis "Menunggu", dan itu terbaca seolah
                // sopir sedang menunggu sesuatu dari kantor — padahal justru
                // dia yang belum mengerjakannya, dan tombol Buat Laporan di
                // bawah sudah mengatakan itu. Lencana baru muncul setelah ada
                // hasilnya: Selesai atau Bermasalah.
                if (item.tuntas) ...[
                  const SizedBox(width: 10),
                  LencanaStatus.bongkar(item.statusBongkar),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.place_outlined,
                  size: 16,
                  color: item.alamatOtomatis != null
                      ? WarnaApp.textSecondary
                      : WarnaApp.textSecondary.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item.alamatOtomatis ??
                        'Alamat belum tersedia dari kunjungan sales',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: item.alamatOtomatis != null
                          ? WarnaApp.textSecondary
                          : WarnaApp.textSecondary.withValues(alpha: 0.6),
                      fontStyle: item.alamatOtomatis != null
                          ? FontStyle.normal
                          : FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
            if (item.catatanAdmin != null &&
                item.catatanAdmin!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: WarnaApp.secondary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.campaign_outlined,
                      size: 18,
                      color: WarnaApp.primaryDark,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Keterangan dari admin',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: WarnaApp.primaryDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.catatanAdmin!.trim(),
                            style: const TextStyle(
                              fontSize: 13,
                              color: WarnaApp.textPrimary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (item.catatanDriver != null &&
                item.catatanDriver!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: WarnaApp.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  item.catatanDriver!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: WarnaApp.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
            const SizedBox(height: _gapKecil),
            const Divider(height: 1, color: WarnaApp.divider),
            const SizedBox(height: _gapKecil),
            _aksiTujuan(rit, item),
          ],
        ),
      ),
    );
  }

  /// Kalau koordinat toko sudah ada (dari kunjungan sales), buka rute
  /// navigasi langsung ke titik itu — bukan sekadar pencarian nama, yang
  /// bisa nyasar ke toko lain dengan nama mirip di kota berbeda. Baru kalau
  /// koordinatnya belum ada (toko belum pernah dikunjungi sales), Maps
  /// dibuka pakai nama lokasi pengiriman sebagai kata kunci pencarian.
  Future<void> _bukaMaps(ModelTugasItem item) async {
    final adaKoordinat = item.alamatLat != null && item.alamatLng != null;

    final uri = adaKoordinat
        ? Uri.https('www.google.com', '/maps/dir/', {
            'api': '1',
            'destination': '${item.alamatLat},${item.alamatLng}',
          })
        : Uri.https('www.google.com', '/maps/search/', {
            'api': '1',
            'query': item.queryMaps,
          });

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Tidak bisa membuka aplikasi Maps.'),
          backgroundColor: WarnaApp.error,
        ));
    }
  }

  /// Menanyakan patokan alamat ke kantor lewat WhatsApp.
  ///
  /// Hanya ditawarkan untuk tujuan yang belum punya koordinat. Pencarian nama
  /// di Maps tetap jadi tombol utama karena yang diketik admin memang nama
  /// toko sungguhan dan biasanya ketemu — kalau setiap tujuan tanpa koordinat
  /// langsung mengirim pesan, kantor menerima puluhan pertanyaan alamat tiap
  /// hari untuk hal yang sebagian besar bisa ditemukan sendiri.
  /// Baris pengenal rit untuk pesan WhatsApp. Nomor polisi bisa kosong kalau
  /// kendaraannya belum ditentukan, jadi pemisahnya ikut hilang alih-alih
  /// meninggalkan tanda hubung yang menggantung tanpa apa-apa di belakangnya.
  String _barisRit(ModelTugas rit) {
    final nopol = rit.kendaraan?.nomorPolisi ?? '';
    return nopol.isEmpty
        ? 'Rit ${rit.nomorRit}.'
        : 'Rit ${rit.nomorRit}, kendaraan $nopol.';
  }

  Future<void> _tanyaAlamatKeKantor(ModelTugas rit, ModelTugasItem item) async {
    final nomor = context.read<ProviderAuth>().driver?.nomorAdminWa;
    if (nomor == null) return;

    // Diisikan lebih dulu supaya kantor langsung tahu toko mana yang dimaksud
    // tanpa bertanya balik, dan sopir tidak perlu mengetik sambil menyetir.
    final pesan = StringBuffer()
      ..writeln(
          'Halo, minta alamat atau patokan untuk ${item.lokasiPengiriman}.')
      ..writeln(_barisRit(rit));

    final uri = Uri.parse(
      'https://wa.me/$nomor?text=${Uri.encodeComponent(pesan.toString().trim())}',
    );

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Tidak bisa membuka WhatsApp.'),
          backgroundColor: WarnaApp.error,
        ));
    }
  }

  /// Navigasi selalu tersedia — bahkan rit yang dibatalkan tetap boleh
  /// dilihat rutenya kalau driver penasaran. Di bawahnya, satu tombol aksi
  /// utama yang bentuknya berubah sesuai keadaan tujuan: buat laporan,
  /// lihat laporan yang sudah terkunci, atau tidak ada sama sekali kalau
  /// rit dibatalkan. Keduanya dibuat selebar kartu dan setinggi 50dp —
  /// nyaman disentuh satu tangan sambil berdiri di pinggir truk, dan
  /// labelnya tidak pernah terpotong jadi dua baris di layar sempit.
  static const double _tinggiTombol = 50;

  Widget _aksiTujuan(ModelTugas rit, ModelTugasItem item) {
    final tombolNavigasi = SizedBox(
      height: _tinggiTombol,
      child: OutlinedButton.icon(
        onPressed: () => _bukaMaps(item),
        icon: const Icon(Icons.navigation_outlined, size: 20),
        label: const Text('Navigasi'),
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );

    // Tujuan tanpa koordinat cuma bisa dicari Maps lewat namanya, dan itu
    // tidak selalu ketemu — toko kecil di desa sering tidak terdaftar. Untuk
    // yang seperti itu, jalan keduanya ditaruh di sebelahnya: tanya kantor.
    // Yang sudah punya koordinat tidak perlu, rutenya sudah pasti.
    final adaKoordinat = item.alamatLat != null && item.alamatLng != null;
    final adaNomorKantor =
        context.watch<ProviderAuth>().driver?.nomorAdminWa != null;

    final navigasi = !adaKoordinat && adaNomorKantor
        ? Row(
            children: [
              Expanded(child: tombolNavigasi),
              const SizedBox(width: _gapKecil),
              // WAJIB Expanded, bukan SizedBox berlebar bebas: tema aplikasi
              // memberi setiap OutlinedButton minimumSize Size.fromHeight(56),
              // dan lebar Size.fromHeight adalah double.infinity. Di dalam Row,
              // anak yang bukan Expanded menerima lebar tak terbatas, jadi
              // tombolnya menuntut lebar tak hingga dan SELURUH layar gagal
              // dilayout — bukan cuma tombolnya yang salah, layarnya kosong.
              Expanded(
                child: SizedBox(
                  height: _tinggiTombol,
                  child: OutlinedButton.icon(
                    onPressed: () => _tanyaAlamatKeKantor(rit, item),
                    icon: const Icon(Icons.chat_outlined, size: 18),
                    label: const Text(
                      'Tanya kantor',
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          )
        : SizedBox(width: double.infinity, child: tombolNavigasi);

    Widget susun(Widget aksiUtama) => Column(
          children: [
            navigasi,
            const SizedBox(height: _gapKecil),
            aksiUtama,
          ],
        );

    if (item.tuntas) {
      // Laporan terkunci setelah terkirim, tapi driver masih perlu bisa
      // membukanya saat kantor menelepon menanyakan bukti tujuan tertentu.
      return susun(
        SizedBox(
          width: double.infinity,
          height: _tinggiTombol,
          child: OutlinedButton.icon(
            onPressed: () => _bukaLaporan(item),
            icon: const Icon(Icons.image_outlined, size: 20),
            label: Text(
              item.jumlahFoto > 0
                  ? 'Lihat Laporan (${item.jumlahFoto} foto)'
                  : 'Lihat Laporan',
            ),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      );
    }

    if (rit.dibatalkan) {
      return susun(
        _catatanKecil(
          Icons.lock_outline,
          'Rit dibatalkan, tujuan ini tidak perlu dikerjakan.',
        ),
      );
    }

    return susun(
      SizedBox(
        width: double.infinity,
        height: _tinggiTombol,
        child: FilledButton.icon(
          onPressed: () => _bukaLaporan(item),
          icon: const Icon(Icons.photo_camera_outlined, size: 20),
          label: const Text('Buat Laporan'),
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }

  Widget _catatanKecil(IconData ikon, String teks, {Color? warna}) {
    final w = warna ?? WarnaApp.textSecondary;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: w.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ikon, size: 18, color: w),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              teks,
              style: TextStyle(fontSize: 12, color: w, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kartu({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WarnaApp.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: WarnaApp.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  /// Judul bagian: kalimat biasa 15sp, seragam dengan beranda.
  ///
  /// Gaya 12sp ALL-CAPS berjarak lebar sudah dibuang dari design system —
  /// judul perlu terbaca sekilas sambil menggulir dengan satu tangan, dan
  /// huruf kapital kecil justru memaksa mata membaca huruf per huruf.
  Widget _judul(String teks) => Text(
        teks,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: WarnaApp.textPrimary,
        ),
      );

  String _angka(double nilai) => nilai == nilai.roundToDouble()
      ? nilai.toStringAsFixed(0)
      : nilai.toString();
}
