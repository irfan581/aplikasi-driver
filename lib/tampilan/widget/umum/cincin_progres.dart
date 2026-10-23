import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../inti/gerak.dart';

/// Cincin progres dengan angka besar di tengahnya.
///
/// Dipilih daripada batang progres untuk ringkasan harian: driver melirik
/// layar sambil berjalan, dan bentuk lingkaran yang terisi lebih cepat
/// terbaca daripada batang tipis. Angka tetap ditulis, karena bentuk saja
/// tidak memberi tahu "berapa lagi yang harus dikerjakan".
class CincinProgres extends StatelessWidget {
  const CincinProgres({
    super.key,
    required this.nilai,
    required this.total,
    required this.warna,
    required this.warnaLatar,
    this.ukuran = 64,
    this.tebal = 7,
  });

  final int nilai;
  final int total;
  final Color warna;
  final Color warnaLatar;
  final double ukuran;
  final double tebal;

  @override
  Widget build(BuildContext context) {
    final rasio = total == 0 ? 0.0 : (nilai / total).clamp(0.0, 1.0);

    return SizedBox(
      width: ukuran,
      height: ukuran,
      // Busurnya menyapu ke nilai baru, tidak meloncat. Driver jadi melihat
      // kemajuannya bertambah setelah menyelesaikan satu rit, bukan menemukan
      // angka yang tahu-tahu sudah berbeda.
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: rasio),
        duration: Gerak.durasi(context, Gerak.progres),
        curve: Curves.easeOutCubic,
        builder: (context, nilaiSapuan, anak) => CustomPaint(
          painter: _PelukisCincin(
            rasio: nilaiSapuan,
            warna: warna,
            warnaLatar: warnaLatar,
            tebal: tebal,
          ),
          child: anak,
        ),
        child: Center(
          child: FittedBox(
            child: Padding(
              padding: EdgeInsets.all(tebal + 4),
              child: Text(
                '$nilai/$total',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: warna,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PelukisCincin extends CustomPainter {
  _PelukisCincin({
    required this.rasio,
    required this.warna,
    required this.warnaLatar,
    required this.tebal,
  });

  final double rasio;
  final Color warna;
  final Color warnaLatar;
  final double tebal;

  @override
  void paint(Canvas canvas, Size size) {
    final pusat = Offset(size.width / 2, size.height / 2);
    final jari = (math.min(size.width, size.height) - tebal) / 2;

    final kuas = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = tebal
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(pusat, jari, kuas..color = warnaLatar);

    if (rasio <= 0) return;

    canvas.drawArc(
      Rect.fromCircle(center: pusat, radius: jari),
      -math.pi / 2,
      2 * math.pi * rasio,
      false,
      kuas..color = warna,
    );
  }

  @override
  bool shouldRepaint(_PelukisCincin lama) =>
      lama.rasio != rasio || lama.warna != warna;
}
