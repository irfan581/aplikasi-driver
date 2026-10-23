import 'package:flutter/material.dart';

import '../../../data/model/model_tugas.dart';
import '../../../inti/tema/warna_app.dart';
import '../umum/lencana_status.dart';

/// Kartu ringkas untuk rit yang bukan sedang dikerjakan — antrean berikutnya
/// atau yang sudah tuntas. Sengaja dibuat lebih tenang daripada
/// [KartuRitAktif] supaya perhatian tidak terpecah dari rit yang sedang jalan.
class KartuRit extends StatelessWidget {
  const KartuRit({super.key, required this.rit, required this.onTap});

  final ModelTugas rit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final warnaStatus = WarnaApp.statusRit(rit.statusPerjalanan);
    final rampung = rit.selesai || rit.dibatalkan;

    return Material(
      color: WarnaApp.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: WarnaApp.border),
          ),
          child: Row(
            children: [
              // Pita warna status di tepi kiri: satu-satunya penanda yang masih
              // terbaca saat kartu hanya terlihat separuh sambil menggulir.
              Container(
                width: 5,
                height: 84,
                decoration: BoxDecoration(
                  color: warnaStatus,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(20),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Rit ${rit.nomorRit}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: rampung
                                  ? WarnaApp.textSecondary
                                  : WarnaApp.textPrimary,
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
                          LencanaStatus.rit(rit.statusPerjalanan),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.local_shipping_outlined,
                            size: 15,
                            color: WarnaApp.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${rit.kendaraan?.nomorPolisi ?? 'Kendaraan belum diisi'}'
                              ', ${_angka(rit.totalMuatanTon)} ton'
                              ', ${rit.jumlahTujuan} tujuan',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: WarnaApp.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(right: 10),
                child: Icon(
                  Icons.chevron_right,
                  color: WarnaApp.textHint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _angka(double nilai) => nilai == nilai.roundToDouble()
      ? nilai.toStringAsFixed(0)
      : nilai.toString();
}
