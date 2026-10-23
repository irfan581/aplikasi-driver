import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../inti/tema/warna_app.dart';

/// Kepala dashboard: sapaan, nama driver, dan tanggal — dibungkus kartu
/// oranye.
///
/// Sengaja kartu, bukan blok oranye selebar layar seperti dulu. Blok penuh
/// membuat beranda terasa dari aplikasi yang berbeda dengan Splash dan Login
/// yang sudah putih bersih; kartu yang berdiri di atas halaman putih tetap
/// membawa warna brand tapi ikut aturan tata letak yang sama dengan kartu rit
/// dan kartu ringkasan di bawahnya — jadi halamannya terbaca terstruktur.
///
/// Isinya sengaja tidak menampilkan angka rit: begitu ada rit berjalan,
/// angka yang sama muncul lagi di kartu "Sedang dikerjakan" tepat di bawah.
class KepalaBeranda extends StatelessWidget {
  const KepalaBeranda({super.key, required this.nama});

  final String nama;

  @override
  Widget build(BuildContext context) {
    final atas = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Yang menyentuh area status bar adalah latar halaman (terang), bukan
      // kartunya — jadi jam dan baterai tetap harus gelap.
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, atas + 16, 24, 8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [WarnaApp.primary, WarnaApp.primaryDark],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              // Bayangan sangat tipis berwarna oranye, bukan hitam: kartunya
              // jadi terasa mengambang di atas halaman tanpa kotoran abu.
              BoxShadow(
                color: WarnaApp.primary.withValues(alpha: 0.22),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _salam(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      nama,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        height: 1.15,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      DateFormat('EEEE, d MMMM yyyy', 'id_ID')
                          .format(DateTime.now()),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_shipping_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _salam() {
    final jam = DateTime.now().hour;
    if (jam < 11) return 'Selamat pagi';
    if (jam < 15) return 'Selamat siang';
    if (jam < 18) return 'Selamat sore';
    return 'Selamat malam';
  }
}
