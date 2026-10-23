import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/model/model_chat.dart';
import '../../../data/servis/servis_kamera.dart';
import '../../../inti/konstanta/konstanta_api.dart';
import '../../../inti/tema/warna_app.dart';
import '../../provider/provider_auth.dart';
import '../../provider/provider_chat.dart';
import '../../widget/umum/keadaan_kosong.dart';

/// Grup laporan kiriman, dibaca dari aplikasi sopir.
///
/// Sengaja tanpa reaksi emoji, polling, pin, bintang, teruskan, dan mention
/// yang ada di aplikasi sales: sopir memakai layar ini sambil berdiri di
/// depan toko, sering di HP murah dan sinyal seadanya. Yang tersisa hanya
/// yang dipakai — membaca, membalas, dan mengirim foto.
class LayarChat extends StatefulWidget {
  const LayarChat({super.key});

  @override
  State<LayarChat> createState() => _LayarChatState();
}

class _LayarChatState extends State<LayarChat> {
  final _teks = TextEditingController();
  final _gulir = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _mulai());
    _gulir.addListener(_saatDigulir);
  }

  @override
  void dispose() {
    _teks.dispose();
    _gulir.dispose();
    super.dispose();
  }

  Future<void> _mulai() async {
    if (!mounted) return;

    final chat = context.read<ProviderChat>();
    chat.setSopir(context.read<ProviderAuth>().driver?.id);

    // muatGrup() sekaligus menyambung siaran grupnya dan — hanya bila tab ini
    // memang sedang dilihat — mengambil percakapannya. Layar ini tidak
    // memanggil bukaGrup() sendiri: IndexedStack membangunnya sejak aplikasi
    // dibuka, jadi mengambil percakapan di sini akan menandai semuanya
    // terbaca padahal sopir belum melihat apa pun.
    await chat.muatGrup();

    if (!mounted) return;
    _keBawah();
  }

  /// Pesan lama digali saat gulir menyentuh ujung atas. Daftar dibalik
  /// (reverse), jadi ujung atas layar ada di posisi maksimum.
  void _saatDigulir() {
    if (!_gulir.hasClients) return;

    final chat = context.read<ProviderChat>();
    if (_gulir.position.pixels >= _gulir.position.maxScrollExtent - 240) {
      chat.muatLebihLama();
    }
  }

  void _keBawah() {
    if (!_gulir.hasClients) return;
    _gulir.jumpTo(0);
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

  Future<void> _kirim() async {
    final isi = _teks.text.trim();
    if (isi.isEmpty) return;

    _teks.clear();

    final galat = await context.read<ProviderChat>().kirimTeks(isi);

    if (galat != null) {
      // Teksnya dikembalikan supaya sopir tidak perlu mengetik ulang saat
      // sinyalnya putus di tengah jalan.
      _teks.text = isi;
      _pesan(galat, error: true);
      return;
    }

    _keBawah();
  }

  Future<void> _kirimFoto() async {
    final hasil = await ServisKamera.jepret(
      namaBerkas: 'chat-${DateTime.now().millisecondsSinceEpoch}',
    );

    if (!mounted) return;

    switch (hasil.status) {
      case StatusJepret.berhasil:
        break;
      case StatusJepret.dibatalkan:
        return;
      case StatusJepret.izinDitolak:
      case StatusJepret.gagal:
        _pesan(hasil.pesan, error: true);
        return;
    }

    final path = hasil.berkas!.path;

    final galat = await context
        .read<ProviderChat>()
        .kirimFoto(path, teks: _teks.text.trim());

    // Salinan di HP dibuang setelah dicoba kirim, berhasil maupun tidak.
    // Antrian foto bongkar sudah melakukan ini untuk buktinya; foto chat
    // tidak punya antrian, jadi kalau tidak dihapus di sini ia menetap
    // selamanya dan pelan-pelan memenuhi penyimpanan HP sopir. Gagal kirim
    // pun tidak memakai berkas ini lagi — sopir menjepret ulang.
    await ServisKamera.hapusBerkas(path);

    if (!mounted) return;

    if (galat != null) {
      _pesan(galat, error: true);
      return;
    }

    _teks.clear();
    _keBawah();
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ProviderChat>();
    final grup = chat.grupUtama;

    return Scaffold(
      backgroundColor: WarnaApp.background,
      appBar: AppBar(
        backgroundColor: WarnaApp.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              grup?.nama ?? 'Laporan Kiriman',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: WarnaApp.textPrimary,
              ),
            ),
            if (grup != null)
              Text(
                '${grup.jumlahAnggota} anggota',
                style: const TextStyle(
                  fontSize: 12,
                  color: WarnaApp.textSecondary,
                ),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _isi(chat)),
          _kotakKetik(chat),
        ],
      ),
    );
  }

  Widget _isi(ProviderChat chat) {
    if (chat.memuat && chat.pesan.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (chat.galat != null && chat.pesan.isEmpty) {
      return KeadaanKosong(
        ikon: Icons.wifi_off_rounded,
        judul: 'Grup gagal dimuat',
        keterangan: chat.galat!,
        aksi: FilledButton(
          onPressed: _mulai,
          child: const Text('Coba Lagi'),
        ),
      );
    }

    // Dibedakan dari grup kosong: sopir yang belum dimasukkan ke grup akan
    // mengira fiturnya rusak kalau dibilang "belum ada laporan", lalu balik
    // ke WhatsApp tanpa memberi tahu siapa pun.
    if (chat.grupUtama == null) {
      return const KeadaanKosong(
        ikon: Icons.group_off_outlined,
        judul: 'Belum masuk grup',
        keterangan: 'Minta kantor memasukkan Anda ke grup Laporan Kiriman.',
      );
    }

    if (chat.pesan.isEmpty) {
      return const KeadaanKosong(
        ikon: Icons.forum_outlined,
        judul: 'Belum ada laporan',
        keterangan:
            'Laporan bongkar yang dikirim akan otomatis muncul di sini.',
      );
    }

    // Dibalik supaya pesan terbaru berada di bawah tanpa perlu menghitung
    // tinggi daftar, dan posisi 0 selalu berarti "paling bawah".
    final urut = chat.pesan.reversed.toList();

    return ListView.builder(
      controller: _gulir,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: urut.length + (chat.memuatLagi ? 1 : 0),
      itemBuilder: (_, i) {
        if (i >= urut.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        return _gelembung(urut[i]);
      },
    );
  }

  /// Pratinjau layar penuh sebuah foto laporan.
  ///
  /// Gelembungnya memuat thumbnail, jadi tanpa ini bukti bongkar tidak pernah
  /// bisa dibaca sampai detailnya — padahal itu justru yang dicari saat sopir
  /// atau kantor membuka laporan: nomor surat jalan, label barang, keadaan
  /// muatan yang rusak.
  Future<void> _lihatFoto(ModelPesanChat p) {
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
                child: InteractiveViewer(
                  maxScale: 4,
                  // Yang dibuka di sini berkas penuh, bukan thumbnail-nya.
                  child: CachedNetworkImage(
                    imageUrl: KonstantaApi.urlBerkas(p.urlBerkas!),
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                    errorWidget: (_, __, ___) => const Center(
                      child: Text(
                        'Foto tidak bisa dimuat',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                  ),
                ),
              ),
              if (p.pesan.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                  child: Text(
                    p.pesan,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
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

  Widget _gelembung(ModelPesanChat p) {
    final saya = p.dariSaya;

    // Laporan bongkar dibedakan dari obrolan biasa supaya bukti tidak
    // tenggelam di antara percakapan — inilah yang dulu hilang di grup
    // WhatsApp.
    final laporan = p.dikirimSopir && p.gambar;

    final latar = saya
        ? WarnaApp.primary
        : laporan
            ? WarnaApp.secondary
            : WarnaApp.surface;

    final warnaTeks = saya ? WarnaApp.textWhite : WarnaApp.textPrimary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment:
            saya ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 300),
              decoration: BoxDecoration(
                color: latar,
                borderRadius: BorderRadius.circular(16),
                border: laporan && !saya
                    ? Border.all(
                        color: WarnaApp.primary.withValues(alpha: 0.35))
                    : Border.all(color: WarnaApp.surfaceMuted),
              ),
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!saya)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        p.namaPengirim,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: laporan
                              ? WarnaApp.primaryDark
                              : WarnaApp.textSecondary,
                        ),
                      ),
                    ),
                  if (p.gambar) ...[
                    // Gelembungnya cuma 300px, jadi yang dimuat versi kecil —
                    // dua puluh foto sekali gulir turun dari megabyte ke ratusan
                    // kilobyte. Yang di-cache juga: tanpa itu setiap gulir
                    // mengunduh ulang foto yang sama, dan kuota sopir yang habis.
                    GestureDetector(
                      onTap: () => _lihatFoto(p),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CachedNetworkImage(
                          imageUrl: KonstantaApi.urlBerkas(p.urlGelembung!),
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            height: 120,
                            color: WarnaApp.surfaceMuted,
                          ),
                          errorWidget: (_, __, ___) => Container(
                            height: 120,
                            alignment: Alignment.center,
                            color: WarnaApp.surfaceMuted,
                            child: const Text(
                              'Foto tidak bisa dimuat',
                              style: TextStyle(
                                fontSize: 12,
                                color: WarnaApp.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (p.pesan.isNotEmpty) const SizedBox(height: 8),
                  ],
                  if (p.pesan.isNotEmpty)
                    Text(
                      p.pesan,
                      style: TextStyle(
                          fontSize: 14, height: 1.4, color: warnaTeks),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    p.waktu,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: saya
                          ? WarnaApp.textWhite.withValues(alpha: 0.8)
                          : WarnaApp.textHint,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kotakKetik(ProviderChat chat) {
    return Container(
      color: WarnaApp.surface,
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        8 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            onPressed: chat.mengirim ? null : _kirimFoto,
            icon: const Icon(Icons.photo_camera_outlined),
            color: WarnaApp.textSecondary,
            tooltip: 'Kirim foto',
          ),
          Expanded(
            child: TextField(
              controller: _teks,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Tulis pesan…',
                filled: true,
                fillColor: WarnaApp.background,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 46,
            height: 46,
            child: chat.mengirim
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton.filled(
                    onPressed: _kirim,
                    icon: const Icon(Icons.send_rounded, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: WarnaApp.primary,
                      foregroundColor: WarnaApp.textWhite,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
