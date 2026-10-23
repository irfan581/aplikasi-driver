import 'package:flutter/material.dart';

import '../../../data/model/model_ringkasan.dart';
import '../../../inti/gerak.dart';
import '../../../inti/tema/warna_app.dart';

/// Rekap kerja driver 30 hari terakhir di beranda.
///
/// Beranda sebelumnya cuma menjawab "hari ini saya harus apa". Kartu ini
/// menjawab pertanyaan kedua yang sering ditanyakan driver ke kantor: sudah
/// berapa banyak yang saya antar bulan ini, dan ke daerah mana saja.
///
/// Aturan warna di kartu ini: oranye hanya untuk angka yang benar-benar ada
/// isinya. Angka nol dibiarkan abu — nol yang dicetak oranye besar terbaca
/// seperti peringatan, padahal artinya cuma "belum ada".
class KartuRingkasan extends StatelessWidget {
  const KartuRingkasan({super.key, required this.ringkasan});

  final ModelRingkasan ringkasan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WarnaApp.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: WarnaApp.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kepala(),
          if (ringkasan.kosong) ...[
            const SizedBox(height: 12),
            const Text(
              'Belum ada kiriman tercatat dalam 30 hari terakhir.',
              style: TextStyle(
                fontSize: 13,
                color: WarnaApp.textSecondary,
                height: 1.45,
              ),
            ),
          ] else ...[
            const SizedBox(height: 20),
            _angkaUtama(),
            if (ringkasan.tujuanBermasalah > 0) ...[
              const SizedBox(height: 16),
              _catatanMasalah(),
            ],
            const SizedBox(height: 20),
            _jenisMuatan(),
            if (ringkasan.wilayah.isNotEmpty) ...[
              const SizedBox(height: 20),
              _sebaranWilayah(context),
            ],
          ],
        ],
      ),
    );
  }

  Widget _kepala() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            '30 hari terakhir',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              color: WarnaApp.textPrimary,
            ),
          ),
        ),
        // Rit yang masih berjalan dibuat lencana, bukan teks lepas: ini satu-
        // satunya keadaan "sedang terjadi" di kartu yang isinya rekap masa
        // lalu, jadi pantas dibedakan bentuknya.
        if (ringkasan.ritBerjalan > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: WarnaApp.secondary,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${ringkasan.ritBerjalan} berjalan',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: WarnaApp.primary,
              ),
            ),
          ),
      ],
    );
  }

  // ── Tiga angka utama ──────────────────────────────────────────

  /// Tanpa garis pemisah vertikal. Tiga kolom yang jaraknya sudah lega tidak
  /// perlu garis untuk dipisahkan, dan garis pendek di antara angka justru
  /// menambah coretan tanpa menambah arti.
  Widget _angkaUtama() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _petakAngka('${ringkasan.ritSelesai}', 'Rit selesai',
            berisi: ringkasan.ritSelesai > 0),
        _petakAngka('${ringkasan.tujuanSelesai}', 'Toko dilayani',
            berisi: ringkasan.tujuanSelesai > 0),
        _petakAngka(_ton(ringkasan.muatanTon), 'Ton dibawa',
            berisi: ringkasan.muatanTon > 0),
      ],
    );
  }

  Widget _petakAngka(String nilai, String label, {required bool berisi}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // FittedBox: angka besar seperti "1.250" tetap muat di layar 320px
          // tanpa terpotong atau mendorong kolom sebelahnya.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              nilai,
              maxLines: 1,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
                height: 1.1,
                color: berisi ? WarnaApp.primary : WarnaApp.textHint,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              height: 1.3,
              color: WarnaApp.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _catatanMasalah() {
    final n = ringkasan.tujuanBermasalah;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: WarnaApp.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 17, color: WarnaApp.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$n toko dilaporkan bermasalah',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: WarnaApp.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Subsidi vs non-subsidi ────────────────────────────────────

  /// Dibuat pil yang merapat ke isinya dan dibungkus [Wrap], bukan dua kotak
  /// selebar setengah kartu. Dua kotak besar berisi satu angka membuat kartu
  /// terasa kosong di dalam, dan di layar sempit label panjangnya terpotong.
  Widget _jenisMuatan() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _JudulKecil('Jenis muatan'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _pil('Subsidi', ringkasan.subsidi, WarnaApp.primary),
            _pil('Non-subsidi', ringkasan.nonSubsidi, WarnaApp.textSecondary),
          ],
        ),
      ],
    );
  }

  Widget _pil(String label, int jumlah, Color warna) {
    // Jenis yang belum pernah dibawa tetap ditampilkan, tapi diredupkan.
    // Menyembunyikannya membuat driver mengira widgetnya rusak, bukan mengerti
    // bahwa memang belum ada rit jenis itu.
    final kosong = jumlah == 0;
    final w = kosong ? WarnaApp.textHint : warna;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: w.withValues(alpha: kosong ? 0.06 : 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$jumlah',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: w,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: kosong ? WarnaApp.textHint : WarnaApp.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Sebaran wilayah ───────────────────────────────────────────

  Widget _sebaranWilayah(BuildContext context) {
    // Dibatasi enam baris teratas. Driver yang menyinggahi belasan area tidak
    // akan membaca ekornya, dan daftar panjang mendorong daftar kiriman hari
    // ini — yang jauh lebih penting — turun jauh dari layar.
    final tampil = ringkasan.wilayah.take(6).toList();
    final sisa = ringkasan.wilayah.length - tampil.length;
    final puncak = ringkasan.wilayahTerbanyak;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _JudulKecil('Wilayah tujuan'),
        const SizedBox(height: 12),
        ...tampil.map((w) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _barisWilayah(context, w, puncak),
            )),
        if (sisa > 0)
          Text(
            '+ $sisa wilayah lain',
            style: const TextStyle(fontSize: 12, color: WarnaApp.textHint),
          ),
      ],
    );
  }

  Widget _barisWilayah(BuildContext context, WilayahRingkas w, int puncak) {
    final rasio = puncak == 0 ? 0.0 : w.jumlah / puncak;
    final takBerkode = w.kode == null;

    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(
            w.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: takBerkode ? FontWeight.w500 : FontWeight.w700,
              color: takBerkode ? WarnaApp.textHint : WarnaApp.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Stack(
              children: [
                // Bar tipis (5px), bukan batang tebal. Ini perbandingan antar
                // wilayah, bukan bilah progres — batang tebal penuh untuk
                // nilai 1 terbaca seperti "100% selesai".
                Container(height: 5, color: WarnaApp.surfaceMuted),
                AnimatedFractionallySizedBox(
                  duration: Gerak.durasi(context, Gerak.progres),
                  curve: Curves.easeOutCubic,
                  // Minimal 12% supaya wilayah bernilai kecil tetap terlihat
                  // punya batang, bukan garis kosong.
                  widthFactor: rasio.clamp(0.12, 1.0),
                  child: Container(
                    height: 5,
                    color: takBerkode
                        ? WarnaApp.border
                        : WarnaApp.primary.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 24,
          child: Text(
            '${w.jumlah}',
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: WarnaApp.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  String _ton(double nilai) => nilai == nilai.roundToDouble()
      ? nilai.toStringAsFixed(0)
      : nilai.toStringAsFixed(1).replaceAll('.', ',');
}

class _JudulKecil extends StatelessWidget {
  const _JudulKecil(this.teks);

  final String teks;

  @override
  Widget build(BuildContext context) {
    return Text(
      teks,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: WarnaApp.textSecondary,
      ),
    );
  }
}
