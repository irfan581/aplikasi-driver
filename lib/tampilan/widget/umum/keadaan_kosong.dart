import 'package:flutter/material.dart';

import '../../../inti/tema/warna_app.dart';

/// Keadaan "tidak ada isi" atau "gagal memuat", dibungkus kartu.
///
/// Sebagai teks telanjang di atas latar halaman, keadaan kosong tampak seperti
/// layar yang gagal dimuat; sebagai kartu — sama seperti kartu rit dan kartu
/// ringkasan di sekitarnya — ia terbaca sebagai satu blok informasi yang
/// memang disiapkan.
class KeadaanKosong extends StatelessWidget {
  const KeadaanKosong({
    super.key,
    required this.ikon,
    required this.judul,
    this.keterangan,
    this.aksi,
  });

  final IconData ikon;
  final String judul;
  final String? keterangan;
  final Widget? aksi;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: WarnaApp.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: WarnaApp.border),
      ),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ikon, size: 48, color: WarnaApp.textHint),
          const SizedBox(height: 16),
          Text(
            judul,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: WarnaApp.textPrimary,
            ),
          ),
          if (keterangan != null) ...[
            const SizedBox(height: 8),
            Text(
              keterangan!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: WarnaApp.textSecondary,
                height: 1.45,
              ),
            ),
          ],
          if (aksi != null) ...[
            const SizedBox(height: 20),
            aksi!,
          ],
        ],
      ),
    );
  }
}
