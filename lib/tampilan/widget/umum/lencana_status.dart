import 'package:flutter/material.dart';

import '../../../inti/tema/warna_app.dart';

/// Lencana status yang dipakai untuk status rit maupun status bongkar tujuan.
class LencanaStatus extends StatelessWidget {
  const LencanaStatus({
    super.key,
    required this.teks,
    required this.warna,
    this.ikon,
  });

  /// Lencana untuk status perjalanan rit.
  factory LencanaStatus.rit(String status, {Key? key}) => LencanaStatus(
        key: key,
        teks: status,
        warna: WarnaApp.statusRit(status),
        ikon: switch (status) {
          'Dimuat' => Icons.inventory_2_outlined,
          'Berangkat' => Icons.local_shipping_outlined,
          'Selesai' => Icons.check_circle_outline,
          'Batal' => Icons.cancel_outlined,
          _ => Icons.schedule,
        },
      );

  /// Lencana untuk status bongkar satu tujuan.
  factory LencanaStatus.bongkar(String status, {Key? key}) => LencanaStatus(
        key: key,
        teks: status,
        warna: WarnaApp.statusBongkar(status),
        ikon: switch (status) {
          'Selesai' => Icons.check_circle_outline,
          'Bermasalah' => Icons.error_outline,
          'Gagal' => Icons.error_outline,
          'Tiba' => Icons.place_outlined,
          _ => Icons.schedule,
        },
      );

  final String teks;
  final Color warna;
  final IconData? ikon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (ikon != null) ...[
            Icon(ikon, size: 14, color: warna),
            const SizedBox(width: 5),
          ],
          Text(
            teks,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: warna,
            ),
          ),
        ],
      ),
    );
  }
}
