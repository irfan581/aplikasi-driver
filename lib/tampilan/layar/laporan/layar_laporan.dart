import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/model/model_foto_bongkar.dart';
import '../../../data/model/model_tugas.dart';
import '../../../inti/konstanta/konstanta_api.dart';
import '../../../inti/tema/warna_app.dart';
import '../../provider/provider_auth.dart';
import '../../provider/provider_foto_bongkar.dart';
import '../../provider/provider_tugas.dart';
import '../../widget/umum/kepala_warna.dart';
import '../../widget/umum/lembar_konfirmasi.dart';

/// Argumen rute layar laporan.
class ArgumenLaporan {
  const ArgumenLaporan({required this.ritId, required this.itemId});

  final int ritId;
  final int itemId;
}

/// Laporan satu tujuan: foto bukti, keterangan, lalu tutup tujuannya.
///
/// Satu layar untuk seluruh pekerjaan di satu toko. Driver tidak menggolongkan
/// jenis masalah lewat menu — ia cuma memilih pengirimannya lancar atau tidak.
/// Keputusan apa yang dilakukan dengan barang yang tidak turun selalu butuh
/// orang, jadi yang disediakan aplikasi adalah gagang telepon, bukan formulir.
class LayarLaporan extends StatelessWidget {
  const LayarLaporan({super.key, required this.argumen});

  final ArgumenLaporan argumen;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ProviderFotoBongkar(
        ritId: argumen.ritId,
        itemId: argumen.itemId,
      )..muat(),
      child: _IsiLaporan(ritId: argumen.ritId, itemId: argumen.itemId),
    );
  }
}

class _IsiLaporan extends StatefulWidget {
  const _IsiLaporan({required this.ritId, required this.itemId});

  final int ritId;
  final int itemId;

  @override
  State<_IsiLaporan> createState() => _IsiLaporanState();
}

class _IsiLaporanState extends State<_IsiLaporan> {
  final TextEditingController _keterangan = TextEditingController();

  bool _sedangKirim = false;

  /// Keterangan wajib diisi, dan driver sering buru-buru. Pilihan cepat ini
  /// membuat kewajiban itu bisa dipenuhi dengan satu ketukan alih-alih
  /// menghasilkan "ok" dan "aman" yang tidak berguna buat admin.
  static const List<String> _pilihanCepat = [
    'Barang diterima penuh',
    'Diterima sebagian',
    'Bongkar di gudang belakang',
    'Toko tutup',
    'Barang ditolak toko',
  ];

  @override
  void dispose() {
    _keterangan.dispose();
    super.dispose();
  }

  ModelTugas? get _rit => context.watch<ProviderTugas>().cariRit(widget.ritId);

  ModelTugasItem? get _item {
    final rit = _rit;
    if (rit == null) return null;

    for (final item in rit.items) {
      if (item.id == widget.itemId) return item;
    }
    return null;
  }

  void _pesan(String teks, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(teks),
        backgroundColor: error ? WarnaApp.error : WarnaApp.success,
      ));
  }

  // ── Foto ──────────────────────────────────────────────────────

  Future<void> _jepret() async {
    final pesan = await context.read<ProviderFotoBongkar>().jepret();
    if (!mounted || pesan == null) return;

    _pesan(pesan, error: true);
  }

  Future<void> _hapusTerkirim(ModelFotoBongkar foto) async {
    final setuju = await tanyaKonfirmasi(
      context,
      judul: 'Hapus foto ini?',
      keterangan: 'Foto dihapus dari server. Setelah laporan dikirim, foto '
          'tidak bisa dihapus lagi.',
      labelYa: 'Ya, Hapus',
      ikon: Icons.delete_outline,
      merah: true,
    );

    if (!setuju || !mounted) return;

    final pesan = await context.read<ProviderFotoBongkar>().hapus(foto.id);
    if (!mounted) return;

    _pesan(pesan ?? 'Foto dihapus', error: pesan != null);
  }

  Future<void> _buangTertunda(FotoTertunda foto) async {
    final setuju = await tanyaKonfirmasi(
      context,
      judul: 'Buang foto ini?',
      keterangan: 'Foto ini belum sampai ke server. Kalau dibuang, foto hilang '
          'dari HP dan harus dijepret ulang.',
      labelYa: 'Ya, Buang',
      ikon: Icons.delete_outline,
      merah: true,
    );

    if (!setuju || !mounted) return;

    await context.read<ProviderFotoBongkar>().buangTertunda(foto.clientUuid);
    if (!mounted) return;

    _pesan('Foto dibuang');
  }

  // ── Kirim laporan ─────────────────────────────────────────────

  /// Alasan kenapa laporan belum bisa dikirim, atau null kalau sudah siap.
  String? _penghalang(ProviderFotoBongkar foto) {
    if (!foto.siapDitutup) {
      return foto.tertunda.isEmpty
          ? 'Ambil dulu minimal satu foto bukti.'
          : 'Foto masih menunggu sinyal. Tunggu sampai terkirim, atau coba '
              'kirim ulang dari daftar foto di atas.';
    }

    if (_keterangan.text.trim().isEmpty) {
      return 'Keterangan wajib diisi.';
    }

    return null;
  }

  Future<void> _kirim(String status, ModelTugasItem item) async {
    final foto = context.read<ProviderFotoBongkar>();

    final penghalang = _penghalang(foto);
    if (penghalang != null) {
      _pesan(penghalang, error: true);
      return;
    }

    final bermasalah = status == 'Bermasalah';

    final setuju = await tanyaKonfirmasi(
      context,
      judul: bermasalah ? 'Laporkan masalah?' : 'Kirim laporan?',
      keterangan: bermasalah
          ? 'Tujuan ${item.lokasiPengiriman} ditandai bermasalah. Setelah ini '
              'hubungi kantor untuk memutuskan barangnya diapakan.'
          : 'Tujuan ${item.lokasiPengiriman} ditandai selesai. Foto dan '
              'keterangan menjadi bukti yang tidak bisa diubah lagi.',
      labelYa: bermasalah ? 'Ya, Ada Masalah' : 'Ya, Kirim Laporan',
      ikon: bermasalah ? Icons.error_outline : Icons.check_circle_outline,
      merah: bermasalah,
    );

    if (!setuju || !mounted) return;

    setState(() => _sedangKirim = true);

    final pengabar = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final error = await context.read<ProviderTugas>().kirimLaporan(
          ritId: widget.ritId,
          itemId: widget.itemId,
          status: status,
          catatan: _keterangan.text.trim(),
        );

    if (!mounted) return;

    setState(() => _sedangKirim = false);

    if (error != null) {
      _pesan(error, error: true);
      return;
    }

    // Tujuan yang bermasalah tidak ditinggalkan begitu saja: teleponnya
    // ditawarkan saat itu juga, selagi driver masih berdiri di depan toko dan
    // ingat detailnya.
    if (bermasalah) {
      await _tawarkanHubungiKantor(item);
      if (!mounted) return;
    }

    navigator.pop();

    pengabar
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(bermasalah
            ? '${item.lokasiPengiriman} ditandai bermasalah'
            : '${item.lokasiPengiriman} selesai'),
        backgroundColor: bermasalah ? WarnaApp.warning : WarnaApp.success,
      ));
  }

  /// Lembar yang muncul saat sopir menekan "Ada Masalah".
  ///
  /// Dua jalan keluar ditaruh berdampingan di satu layar, bukan disembunyikan
  /// di balik ketukan kedua, karena keduanya menjawab keadaan yang sama dan
  /// sopir tidak boleh menebak mana yang benar:
  ///
  /// * **Chat Kantor** selalu hidup. Ini yang dituju sopir yang baru sampai
  ///   dan menemukan tokonya tutup — ia perlu bertanya, bukan memutuskan.
  /// * **Tandai Bermasalah** menutup tujuan dan tidak bisa dibatalkan, jadi
  ///   tetap menuntut foto dan keterangan. Kalau syaratnya belum lengkap
  ///   tombolnya mati DAN alasannya tertulis, bukan sekadar kelabu tanpa
  ///   penjelasan.
  Future<void> _adaMasalah(ModelTugasItem item, ProviderFotoBongkar foto) async {
    final penghalang = _penghalang(foto);

    final pilihan = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: WarnaApp.warning.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline,
                    size: 27, color: WarnaApp.warning),
              ),
              const SizedBox(height: 14),
              Text(
                'Ada masalah di ${item.lokasiPengiriman}?',
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Hubungi kantor dulu. Kantor yang memutuskan barangnya dibawa '
                'pulang atau dialihkan.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: WarnaApp.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: () => Navigator.pop(ctx, 'chat'),
                icon: const Icon(Icons.chat_outlined, size: 20),
                label: const Text('Chat Kantor'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: penghalang != null
                    ? null
                    : () => Navigator.pop(ctx, 'tandai'),
                icon: const Icon(Icons.flag_outlined, size: 19),
                label: const Text('Tandai Tujuan Bermasalah'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: WarnaApp.warning,
                  side: const BorderSide(color: WarnaApp.warning),
                  minimumSize: const Size.fromHeight(46),
                ),
              ),
              if (penghalang != null) ...[
                const SizedBox(height: 8),
                Text(
                  penghalang,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: WarnaApp.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Tutup'),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || pilihan == null) return;

    if (pilihan == 'chat') {
      await _chatKantor(item);
      return;
    }

    await _kirim('Bermasalah', item);
  }

  /// Buka WhatsApp ke kantor tanpa mengubah status tujuan apa pun.
  ///
  /// Dipisah dari [_tawarkanHubungiKantor] yang hanya berjalan sesudah laporan
  /// bermasalah terkirim: yang ini tersedia kapan saja selagi sopir masih
  /// mengisi laporannya.
  Future<void> _chatKantor(ModelTugasItem item) async {
    final nomor = context.read<ProviderAuth>().driver?.nomorAdminWa;

    if (nomor == null) {
      _pesan(
        'Nomor kantor belum diatur. Hubungi kantor lewat telepon biasa, '
        'lalu minta admin mengisi nomornya.',
        error: true,
      );
      return;
    }

    await _bukaWhatsApp(nomor, item);
  }

  Future<void> _tawarkanHubungiKantor(ModelTugasItem item) async {
    final nomor = context.read<ProviderAuth>().driver?.nomorAdminWa;

    // Dulu diam saja saat nomornya belum diatur. Akibatnya tawaran menghubungi
    // kantor tidak pernah muncul dan tidak ada yang tahu kenapa — terlihat
    // seperti fiturnya tidak dibuat, padahal cuma nomornya yang kosong.
    // Sekarang sopir diberi tahu, supaya ia melapor ke kantor lewat jalan lain
    // dan admin tahu ada yang perlu diisi.
    if (nomor == null) {
      _pesan(
        'Nomor kantor belum diatur. Kabari kantor lewat telepon biasa, '
        'lalu minta admin mengisi nomornya.',
        error: true,
      );
      return;
    }

    final hubungi = await tanyaKonfirmasi(
      context,
      judul: 'Hubungi kantor sekarang?',
      keterangan: 'Kantor perlu tahu apa yang terjadi di '
          '${item.lokasiPengiriman} untuk memutuskan barangnya dibawa pulang '
          'atau dialihkan.',
      labelYa: 'Chat Kantor',
      ikon: Icons.chat_outlined,
    );

    if (!hubungi) return;

    await _bukaWhatsApp(nomor, item);
  }

  Future<void> _bukaWhatsApp(String nomor, ModelTugasItem item) async {
    // Diambil sebelum await: dipakai kalau WhatsApp gagal dibuka, dan context
    // tidak boleh disentuh lagi setelah jeda async.
    final nomorTampil =
        context.read<ProviderAuth>().driver?.nomorAdmin ?? nomor;

    // Pesannya diisikan lebih dulu supaya sopir yang sedang berdiri di depan
    // toko tidak perlu mengetik ulang kejadiannya, dan kantor langsung tahu
    // toko mana yang dimaksud tanpa bertanya balik.
    final catatan = _keterangan.text.trim();
    final nopol = _rit?.kendaraan?.nomorPolisi ?? '';
    final pesan = StringBuffer()
      ..writeln('Halo, ada kendala di ${item.lokasiPengiriman}.')
      ..writeln('Rit ${_rit?.nomorRit ?? 'tanpa nomor'}'
          '${nopol.isEmpty ? '' : ', kendaraan $nopol'}.');

    if (catatan.isNotEmpty) pesan.writeln('Keterangan: $catatan');

    final uri = Uri.parse(
      'https://wa.me/$nomor'
      '?text=${Uri.encodeComponent(pesan.toString().trim())}',
    );

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      // Yang ditampilkan bentuk aslinya (+62...), bukan yang sudah dipotong
      // untuk wa.me — nomor ini dibaca sopir untuk menyimpannya sendiri.
      _pesan('Tidak bisa membuka WhatsApp. Nomor kantor: $nomorTampil',
          error: true);
    }
  }

  // ── Tampilan ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final item = _rit == null ? null : _item;
    final foto = context.watch<ProviderFotoBongkar>();

    if (item == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(children: [
        RefreshIndicator(
          onRefresh: () async {
            final tugas = context.read<ProviderTugas>();
            final bukti = context.read<ProviderFotoBongkar>();

            await tugas.muatDetail(widget.ritId);
            await bukti.muat();
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _kepala(item, foto)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                sliver: SliverList.list(
                  children: item.tuntas
                      ? _isiTerkunci(item, foto)
                      : _isiPengisian(item, foto),
                ),
              ),
            ],
          ),
        ),
        const TudungStatus()
      ]),
      bottomNavigationBar: item.tuntas ? null : _bilahAksi(item, foto),
    );
  }

  Widget _kepala(ModelTugasItem item, ProviderFotoBongkar foto) {
    return KepalaWarna(
      adaTombolKembali: true,
      atasJudul: 'Tujuan ${item.urutan}',
      judul: item.lokasiPengiriman,
      isi: KotakKepala(
        child: Row(
          children: [
            Expanded(
              child: Text(
                item.tuntas
                    ? 'Sudah dilaporkan ${item.statusBongkar.toLowerCase()}'
                    : foto.tertunda.isEmpty
                        ? '${foto.jumlah} foto siap'
                        : '${foto.jumlah} foto, ${foto.tertunda.length} menunggu sinyal',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: WarnaApp.textPrimary,
                ),
              ),
            ),
            Icon(
              item.tuntas
                  ? Icons.lock_outline
                  : foto.siapDitutup
                      ? Icons.verified_outlined
                      : Icons.photo_camera_outlined,
              color: WarnaApp.primary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // ── Tujuan yang sudah dilaporkan ──────────────────────────────

  List<Widget> _isiTerkunci(ModelTugasItem item, ProviderFotoBongkar foto) {
    return [
      _catatan(
        item.bermasalah ? Icons.error_outline : Icons.check_circle_outline,
        item.bermasalah
            ? 'Tujuan ini dilaporkan bermasalah. Kalau kantor belum tahu, '
                'hubungi sekarang.'
            : 'Tujuan ini sudah selesai. Foto dan keterangannya terkunci '
                'sebagai bukti.',
        warna: item.bermasalah ? WarnaApp.warning : WarnaApp.success,
      ),
      if (item.catatanDriver != null && item.catatanDriver!.isNotEmpty) ...[
        const SizedBox(height: 16),
        _kartuSeksi(
          judul: 'Keterangan',
          isi: [
            Text(
              item.catatanDriver!,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ],
      if (item.bermasalah) ...[
        const SizedBox(height: 16),
        _tombolHubungiKantor(item),
      ],
      const SizedBox(height: 16),
      _kartuSeksi(
        judul: 'Foto bukti',
        isi: [
          if (foto.adaFoto)
            _petakFoto(foto, bolehHapus: false)
          else
            _catatan(Icons.image_not_supported_outlined,
                'Tidak ada foto tersimpan.'),
        ],
      ),
    ];
  }

  // ── Tujuan yang sedang dikerjakan ─────────────────────────────

  List<Widget> _isiPengisian(ModelTugasItem item, ProviderFotoBongkar foto) {
    return [
      _kartuSeksi(
        judul: 'Foto bukti',
        isi: [
          if (foto.pesanError != null) ...[
            _catatan(Icons.cloud_off_outlined, foto.pesanError!,
                warna: WarnaApp.warning),
            const SizedBox(height: 12),
          ],
          if (foto.adaFoto) ...[
            _petakFoto(foto, bolehHapus: true),
            const SizedBox(height: 12),
          ] else ...[
            _catatan(
              Icons.photo_camera_outlined,
              'Jepret surat jalan dan barang yang diturunkan. Minimal satu '
              'foto.',
            ),
            const SizedBox(height: 12),
          ],
          // Menyiapkan foto memakan waktu: kamera menutup, gambar dikompres,
          // koordinat dikunci, lalu unggahan berjalan. Tanpa penanda di
          // tombolnya, jeda itu terbaca sebagai aplikasi yang berhenti.
          OutlinedButton.icon(
            onPressed:
                foto.sedangSibuk || foto.penuh || _sedangKirim ? null : _jepret,
            icon: foto.sedangSibuk
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : const Icon(Icons.add_a_photo_outlined, size: 20),
            label: Text(foto.sedangSibuk
                ? 'Menyiapkan foto'
                : foto.penuh
                    ? 'Foto Sudah Penuh'
                    : 'Ambil Foto'),
            style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48)),
          ),
          if (foto.tertunda.isNotEmpty) ...[
            const SizedBox(height: 12),
            _catatan(
              Icons.schedule_outlined,
              '${foto.tertunda.length} foto tersimpan di HP dan akan terkirim '
              'sendiri saat sinyal kembali. Laporan baru bisa dikirim setelah '
              'ada foto yang sampai di server.',
              warna: WarnaApp.warning,
              aksi: TextButton(
                onPressed: foto.sedangSibuk
                    ? null
                    : () async {
                        final pesan = await context
                            .read<ProviderFotoBongkar>()
                            .kirimUlang();
                        if (!mounted) return;
                        _pesan(pesan ?? 'Semua foto sudah terkirim',
                            error: pesan != null);
                      },
                child: const Text('Coba Kirim Sekarang'),
              ),
            ),
          ],
        ],
      ),
      const SizedBox(height: 16),
      _kartuSeksi(
        judul: 'Keterangan',
        isi: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _pilihanCepat
                .map((teks) => ActionChip(
                      label: Text(teks),
                      onPressed: _sedangKirim
                          ? null
                          : () => setState(() => _keterangan.text = teks),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _keterangan,
            maxLength: 255,
            maxLines: 3,
            enabled: !_sedangKirim,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Tulis apa yang terjadi di toko ini',
            ),
          ),
        ],
      ),
    ];
  }

  /// Satu bagian layar sebagai kartu: judul di dalam, isi di bawahnya.
  ///
  /// Dipakai supaya "Foto bukti" dan "Keterangan" terbaca sebagai dua blok
  /// pekerjaan yang terpisah — sebelumnya keduanya mengalir sebagai satu
  /// daftar panjang, dan driver harus membaca judul kecil untuk tahu ia
  /// sedang berada di bagian mana.
  Widget _kartuSeksi({required String judul, required List<Widget> isi}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WarnaApp.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: WarnaApp.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _judul(judul),
          const SizedBox(height: 12),
          ...isi,
        ],
      ),
    );
  }

  // ── Bilah tombol ──────────────────────────────────────────────

  Widget _bilahAksi(ModelTugasItem item, ProviderFotoBongkar foto) {
    final terhalang = _penghalang(foto) != null;
    final mati = _sedangKirim || foto.sedangSibuk;

    return Container(
      decoration: const BoxDecoration(
        color: WarnaApp.surface,
        border: Border(top: BorderSide(color: WarnaApp.border)),
      ),
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton(
              onPressed:
                  mati || terhalang ? null : () => _kirim('Selesai', item),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              child: _sedangKirim
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Kirim Laporan'),
            ),
            const SizedBox(height: 10),
            // Satu tombol, bukan dua. "Ada Masalah" dan "Chat Admin"
            // berdampingan membuat sopir harus memilih dulu sebelum tahu
            // bedanya apa. Sekarang cukup satu ketukan saat ada yang tidak
            // beres, dan pilihannya dijelaskan di lembar berikutnya.
            //
            // Tidak ikut dimatikan oleh `terhalang`: justru saat foto atau
            // keterangan belum ada, menghubungi kantor yang paling dibutuhkan.
            OutlinedButton.icon(
              onPressed: _sedangKirim ? null : () => _adaMasalah(item, foto),
              icon: const Icon(Icons.error_outline, size: 19),
              label: const Text('Ada Masalah'),
              style: OutlinedButton.styleFrom(
                foregroundColor: WarnaApp.warning,
                side: const BorderSide(color: WarnaApp.warning),
                minimumSize: const Size.fromHeight(46),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tombolHubungiKantor(ModelTugasItem item) {
    final nomor = context.watch<ProviderAuth>().driver?.nomorAdminWa;

    // Bukan widget kosong: tujuan bermasalah selalu butuh orang, jadi kalau
    // gagangnya tidak bisa disediakan, alasannya harus terbaca.
    if (nomor == null) {
      return _catatan(
        Icons.phone_disabled_outlined,
        'Nomor kantor belum diatur, jadi tombol chat tidak bisa ditampilkan. '
        'Hubungi kantor lewat telepon biasa.',
        warna: WarnaApp.warning,
      );
    }

    return OutlinedButton.icon(
      onPressed: () => _bukaWhatsApp(nomor, item),
      icon: const Icon(Icons.chat_outlined, size: 19),
      label: const Text('Chat Kantor'),
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
    );
  }

  // ── Petak foto ────────────────────────────────────────────────

  Widget _petakFoto(ProviderFotoBongkar foto, {required bool bolehHapus}) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemCount: foto.jumlah,
      itemBuilder: (_, i) {
        // Yang belum terkirim ditaruh di belakang: urutannya mengikuti
        // perjalanan foto, dari yang sudah aman di server ke yang menunggu.
        if (i < foto.terkirim.length) {
          return _petakTerkirim(foto.terkirim[i], bolehHapus: bolehHapus);
        }
        return _petakTertunda(foto.tertunda[i - foto.terkirim.length]);
      },
    );
  }

  Widget _petakTerkirim(ModelFotoBongkar foto, {required bool bolehHapus}) {
    return _petak(
      gambar: CachedNetworkImage(
        // Petaknya sepertiga layar; yang dimuat cukup thumbnail 320px. Layar
        // penuh di bawah tetap mengambil berkas aslinya.
        imageUrl: KonstantaApi.urlBerkas(foto.urlPetak),
        fit: BoxFit.cover,
        placeholder: (_, __) => const ColoredBox(color: WarnaApp.surfaceMuted),
        errorWidget: (_, __, ___) => const ColoredBox(
          color: WarnaApp.surfaceMuted,
          child: Icon(Icons.broken_image_outlined, color: WarnaApp.textHint),
        ),
      ),
      // Foto yang berkasnya hilang di server tetap dihitung sebagai bukti oleh
      // aturan FOTO_WAJIB, jadi tanpa penanda ini driver mengirim laporan
      // dengan bukti kosong tanpa pernah tahu.
      penanda: foto.gagalProses
          ? const Icon(Icons.priority_high, size: 14, color: Colors.white)
          : null,
      warnaPenanda: WarnaApp.error,
      onTap: () => _lihat(
        gambar: CachedNetworkImage(
          imageUrl: KonstantaApi.urlBerkas(foto.fotoUrl),
          fit: BoxFit.contain,
        ),
        keterangan: foto.gagalProses
            ? 'Berkas foto ini tidak tersimpan utuh di server. Hapus lalu '
                'jepret ulang sebelum mengirim laporan.'
            : foto.alamat,
        onHapus: bolehHapus ? () => _hapusTerkirim(foto) : null,
      ),
    );
  }

  Widget _petakTertunda(FotoTertunda foto) {
    final berkas = File(foto.path);

    return _petak(
      gambar: berkas.existsSync()
          ? Image.file(berkas, fit: BoxFit.cover)
          : const ColoredBox(
              color: WarnaApp.surfaceMuted,
              child:
                  Icon(Icons.broken_image_outlined, color: WarnaApp.textHint),
            ),
      penanda: const Icon(Icons.schedule, size: 14, color: Colors.white),
      warnaPenanda: WarnaApp.warning,
      onTap: () => _lihat(
        gambar: berkas.existsSync()
            ? Image.file(berkas, fit: BoxFit.contain)
            : const SizedBox.shrink(),
        keterangan: foto.pesanGagal ?? 'Menunggu sinyal untuk dikirim',
        onHapus: () => _buangTertunda(foto),
      ),
    );
  }

  Widget _petak({
    required Widget gambar,
    required VoidCallback onTap,
    Widget? penanda,
    Color? warnaPenanda,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            gambar,
            if (penanda != null)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: warnaPenanda ?? WarnaApp.primary,
                    shape: BoxShape.circle,
                  ),
                  child: penanda,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _lihat({
    required Widget gambar,
    String? keterangan,
    VoidCallback? onHapus,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close, color: Colors.white),
                  tooltip: 'Tutup',
                ),
              ),
              Expanded(
                // Surat jalan sering perlu diperbesar untuk membaca nomor dan
                // tanda tangannya sebelum driver yakin fotonya terbaca.
                child: InteractiveViewer(maxScale: 4, child: gambar),
              ),
              if (keterangan != null && keterangan.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                  child: Text(
                    keterangan,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              if (onHapus != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      onHapus();
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Hapus Foto'),
                    style:
                        TextButton.styleFrom(foregroundColor: WarnaApp.error),
                  ),
                )
              else
                const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ── Potongan kecil ────────────────────────────────────────────

  /// Judul kartu bagian. Kalimat biasa 15sp, seragam dengan judul bagian di
  /// beranda — bukan huruf kapital 12sp berjarak lebar seperti sebelumnya.
  Widget _judul(String teks) => Text(
        teks,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: WarnaApp.textPrimary,
        ),
      );

  Widget _catatan(
    IconData ikon,
    String teks, {
    Color warna = WarnaApp.textSecondary,
    Widget? aksi,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: warna.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(ikon, size: 18, color: warna),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  teks,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: WarnaApp.textSecondary,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
          if (aksi != null)
            Align(alignment: Alignment.centerRight, child: aksi),
        ],
      ),
    );
  }
}
