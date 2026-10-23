import 'package:flutter/material.dart';

import '../../../inti/tema/warna_app.dart';

/// Konfirmasi sebelum tindakan yang tidak bisa dibatalkan driver sendiri.
///
/// Server hanya mengizinkan status maju, tidak mundur. Satu tap yang tidak
/// disengaja berarti driver harus menelepon kantor, jadi setiap tindakan yang
/// mengubah status selalu lewat lembar ini — dan lembarnya menjelaskan
/// akibatnya, bukan sekadar bertanya "yakin?".
///
/// Dipakai lembar bawah, bukan dialog tengah, karena tombolnya jatuh dekat
/// ibu jari dan bisa ditutup dengan menyeret ke bawah.
Future<bool> tanyaKonfirmasi(
  BuildContext context, {
  required String judul,
  required String keterangan,
  required String labelYa,
  IconData? ikon,
  bool merah = false,
}) async {
  final warna = merah ? WarnaApp.error : WarnaApp.primary;

  final jawaban = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (ikon != null) ...[
              Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: warna.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(ikon, size: 27, color: warna),
              ),
              const SizedBox(height: 14),
            ],
            Text(
              judul,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              keterangan,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: WarnaApp.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: warna),
              child: Text(labelYa),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
          ],
        ),
      ),
    ),
  );

  return jawaban == true;
}

/// Menanyakan alasan yang wajib diisi, dipakai saat tujuan gagal dibongkar.
/// Mengembalikan null bila dibatalkan.
Future<String?> tanyaAlasan(
  BuildContext context, {
  required String judul,
  required String namaTujuan,
  required String contoh,
}) async {
  final ctrl = TextEditingController();

  final hasil = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      // Lembar terangkat mengikuti papan ketik supaya kolom isian tidak
      // tertutup saat driver mengetik.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(ctx).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                judul,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                namaTujuan,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: WarnaApp.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: ctrl,
                autofocus: true,
                maxLength: 255,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(hintText: contoh),
              ),
              const SizedBox(height: 6),
              FilledButton(
                onPressed: () {
                  final teks = ctrl.text.trim();
                  // Server juga menolak catatan kosong; dicegah di sini supaya
                  // driver tidak menunggu perjalanan bolak-balik jaringan
                  // hanya untuk diberi tahu isiannya kurang.
                  if (teks.isEmpty) return;
                  Navigator.pop(ctx, teks);
                },
                child: const Text('Simpan Alasan'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  ctrl.dispose();
  return hasil;
}
