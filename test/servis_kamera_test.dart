import 'package:flutter_test/flutter_test.dart';

import 'package:driver_tmk/data/servis/servis_kamera.dart';

void main() {
  group('nama berkas sementara', () {
    // flutter_image_compress menolak berkas tujuan yang namanya tidak berakhir
    // .jpg atau .jpeg. Sebelum uji ini ada, nama sementaranya `<uuid>.jpg.1`
    // dan seluruh penyiapan foto gagal di HP sopir dengan pesan
    // "CompressFormat.jpeg requires the target file name to end with .jpg" —
    // build lolos, analyzer bersih, dan tidak ada yang tahu sampai ada yang
    // mencoba menjepret.
    test('selalu berakhir .jpg', () {
      final nama = ServisKamera.namaSementara('/data/bukti', 'a9564a08-f71f');

      expect(nama, isNotEmpty);
      for (final n in nama) {
        expect(
          n.endsWith('.jpg'),
          isTrue,
          reason: '$n ditolak flutter_image_compress karena bukan .jpg',
        );
      }
    });

    test('berbeda satu sama lain dan dari nama sungguhannya', () {
      final nama = ServisKamera.namaSementara('/data/bukti', 'abc');

      expect(nama.toSet().length, nama.length,
          reason: 'dua percobaan kompresi akan saling menimpa');
      expect(nama, isNot(contains('/data/bukti/abc.jpg')),
          reason: 'nama sungguhan tidak boleh terisi berkas setengah jadi');
    });
  });
}
