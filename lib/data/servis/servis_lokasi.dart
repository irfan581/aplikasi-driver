import 'package:geolocator/geolocator.dart';

/// Koordinat yang menyertai satu foto bukti bongkar.
class TitikLokasi {
  const TitikLokasi({
    required this.latitude,
    required this.longitude,
    required this.akurasi,
    required this.palsu,
  });

  final double latitude;
  final double longitude;
  final double akurasi;

  /// Android menandai posisi yang berasal dari aplikasi pemalsu lokasi.
  /// Dikirim apa adanya ke server, biar admin yang menilai.
  final bool palsu;

  Map<String, dynamic> toKolom() => {
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': akurasi,
        'is_mock': palsu,
      };
}

/// Lokasi bersifat pelengkap bukti, bukan syarat.
///
/// Gudang berdinding seng dan gang toko yang sempit sering membuat GPS lama
/// terkunci. Karena itu setiap pengambilan dibatasi waktu dan kegagalannya
/// dijawab null — foto tetap terkirim tanpa koordinat, dan driver tidak
/// tertahan menunggu satelit sambil truk mengantre bongkar.
class ServisLokasi {
  ServisLokasi._();

  static const Duration _batasWaktu = Duration(seconds: 8);

  /// Apakah lokasi bisa diambil tanpa memunculkan dialog izin.
  ///
  /// Dipakai pemanggil yang ingin menyalakan GPS berbarengan dengan kamera:
  /// dialog izin yang terbit di atas kamera tidak terbaca dan sering tertekan
  /// asal oleh driver.
  static Future<bool> bisaTanpaDialog() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return false;

      final izin = await Geolocator.checkPermission();

      return izin == LocationPermission.always ||
          izin == LocationPermission.whileInUse;
    } catch (_) {
      return false;
    }
  }

  static Future<TitikLokasi?> ambil() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      var izin = await Geolocator.checkPermission();

      if (izin == LocationPermission.denied) {
        izin = await Geolocator.requestPermission();
      }

      if (izin == LocationPermission.denied ||
          izin == LocationPermission.deniedForever) {
        return null;
      }

      final posisi = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: _batasWaktu,
      );

      return TitikLokasi(
        latitude: posisi.latitude,
        longitude: posisi.longitude,
        akurasi: posisi.accuracy,
        palsu: posisi.isMocked,
      );
    } catch (_) {
      // Termasuk TimeoutException saat GPS tidak terkunci dalam batas waktu.
      return null;
    }
  }
}
