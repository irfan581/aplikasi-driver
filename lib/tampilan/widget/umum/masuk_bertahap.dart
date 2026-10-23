import 'package:flutter/material.dart';

import '../../../inti/gerak.dart';

/// Membuat isinya muncul sambil naik sedikit, dengan jeda yang bisa diatur.
///
/// Dipakai agar isi layar tidak menghantam mata sekaligus: kepala lebih dulu,
/// baru kartu yang harus ditindaklanjuti. Urutannya mengarahkan pandangan
/// driver ke tindakan berikutnya, bukan sekadar memperindah.
class MasukBertahap extends StatefulWidget {
  const MasukBertahap({
    super.key,
    required this.child,
    this.jeda = Duration.zero,
    this.geser = 16,
  });

  final Widget child;
  final Duration jeda;

  /// Jarak naik dalam piksel logis. Sengaja kecil — gerakan besar terasa
  /// lamban saat aplikasi dibuka puluhan kali sehari.
  final double geser;

  @override
  State<MasukBertahap> createState() => _MasukBertahapState();
}

class _MasukBertahapState extends State<MasukBertahap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _kendali = AnimationController(
    vsync: this,
    duration: Gerak.sedang,
  );

  late final Animation<double> _halus =
      CurvedAnimation(parent: _kendali, curve: Curves.easeOut);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (Gerak.dimatikan(context)) {
        _kendali.value = 1;
        return;
      }

      if (widget.jeda == Duration.zero) {
        _kendali.forward();
        return;
      }

      Future<void>.delayed(widget.jeda, () {
        if (mounted) _kendali.forward();
      });
    });
  }

  @override
  void dispose() {
    _kendali.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _halus,
      child: AnimatedBuilder(
        animation: _halus,
        builder: (context, anak) => Transform.translate(
          offset: Offset(0, widget.geser * (1 - _halus.value)),
          child: anak,
        ),
        child: widget.child,
      ),
    );
  }
}
