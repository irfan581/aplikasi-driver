import 'package:flutter/material.dart';

import '../../../data/model/model_tugas.dart';
import '../../../inti/gerak.dart';
import '../../../inti/tema/warna_app.dart';
import '../umum/lencana_status.dart';

/// Kartu rit yang sedang dikerjakan, ditaruh paling atas dan dibuat menonjol.
///
/// Pertanyaan driver saat membuka aplikasi selalu sama: "sekarang saya harus
/// apa". Kartu ini menjawabnya tanpa perlu membuka halaman detail: tujuan
/// berikutnya disebut namanya, dan tombolnya langsung membuka layar laporan
/// tujuan itu.
class KartuRitAktif extends StatelessWidget {
  const KartuRitAktif({
    super.key,
    required this.rit,
    required this.onTap,
    required this.onAksi,
    this.sedangProses = false,
  });

  final ModelTugas rit;
  final VoidCallback onTap;
  final VoidCallback onAksi;
  final bool sedangProses;

  @override
  Widget build(BuildContext context) {
    final warnaStatus = WarnaApp.statusRit(rit.statusPerjalanan);

    return AnimatedContainer(
      duration: Gerak.durasi(context, Gerak.cepat),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: WarnaApp.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: warnaStatus.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: warnaStatus.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Rit ${rit.nomorRit}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (rit.subsidi)
                        const LencanaStatus(
                          teks: 'Subsidi',
                          warna: WarnaApp.primary,
                          ikon: Icons.verified_outlined,
                        ),
                      const Spacer(),
                      // Lencana berganti dengan lebur agar perubahan status
                      // terlihat terjadi, bukan tahu-tahu sudah berbeda.
                      AnimatedSwitcher(
                        duration: Gerak.durasi(context, Gerak.cepat),
                        child: LencanaStatus.rit(
                          rit.statusPerjalanan,
                          key: ValueKey(rit.statusPerjalanan),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _cip(
                        Icons.local_shipping_outlined,
                        rit.kendaraan?.nomorPolisi ?? 'Kendaraan belum diisi',
                      ),
                      const SizedBox(width: 8),
                      _cip(Icons.scale_outlined,
                          '${_angka(rit.totalMuatanTon)} ton'),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _tujuan(),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),
          if (_tujuanBerikutnya() != null) _tombolAksi(),
        ],
      ),
    );
  }

  Widget _tujuan() {
    if (rit.jumlahTujuan == 0) {
      return const Text(
        'Rit ini belum punya tujuan. Hubungi kantor.',
        style: TextStyle(fontSize: 13, color: WarnaApp.textSecondary),
      );
    }

    final berikutnya = _tujuanBerikutnya();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: WarnaApp.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            berikutnya == null ? Icons.done_all : Icons.place_outlined,
            size: 20,
            color: WarnaApp.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  berikutnya == null
                      ? 'Semua tujuan tuntas'
                      : 'Tujuan berikutnya',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: WarnaApp.textSecondary,
                    letterSpacing: 0.3,
                  ),
                ),
                if (berikutnya != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    berikutnya.labelLokasi,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            '${rit.tujuanTuntas}/${rit.jumlahTujuan}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: WarnaApp.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  ModelTugasItem? _tujuanBerikutnya() {
    for (final item in rit.items) {
      if (!item.tuntas) return item;
    }
    return null;
  }

  Widget _tombolAksi() {
    final berikutnya = _tujuanBerikutnya()!;

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: sedangProses ? null : onAksi,
        icon: sedangProses
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.photo_camera_outlined),
        // Nama tokonya ikut di tombol supaya driver tahu tombol ini membuka
        // tujuan yang mana sebelum menekannya.
        label: Text(
          'Lapor ${berikutnya.lokasiPengiriman}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          shape: const RoundedRectangleBorder(),
        ),
      ),
    );
  }

  Widget _cip(IconData ikon, String teks) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: WarnaApp.surfaceMuted,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ikon, size: 15, color: WarnaApp.textSecondary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                teks,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: WarnaApp.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _angka(double nilai) => nilai == nilai.roundToDouble()
      ? nilai.toStringAsFixed(0)
      : nilai.toString();
}
