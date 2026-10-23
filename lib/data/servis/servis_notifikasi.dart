import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../inti/konstanta/konstanta_api.dart';
import 'servis_api.dart';
import 'servis_penyimpanan_aman.dart';

/// Notifikasi dari kantor ke HP driver, terutama "muatan baru".
///
/// Saat aplikasi di latar atau tertutup, Android sendiri yang menampilkannya.
/// Saat aplikasi terbuka FCM diam, jadi notifikasinya dimunculkan di sini.
class ServisNotifikasi {
  ServisNotifikasi._();

  static const String tipeMuatanBaru = 'muatan_baru';

  /// Nama berkas nada di `android/app/src/main/res/raw`, tanpa ekstensi.
  static const String _nadaMuatan = 'muatan_baru';

  /// Id channel harus sama dengan yang dikirim server (KirimNotifikasiDriverJob
  /// dan FcmService). Bunyi channel tidak bisa diubah setelah dibuat: mengganti
  /// nada berarti mengganti id channel-nya, di sini dan di server.
  static const AndroidNotificationChannel _channelMuatan =
      AndroidNotificationChannel(
    'muatan_baru',
    'Muatan baru',
    description: 'Kabar saat kantor memberi Anda muatan.',
    importance: Importance.max,
    sound: RawResourceAndroidNotificationSound(_nadaMuatan),
    enableVibration: true,
  );

  static const AndroidNotificationChannel _channelUmum =
      AndroidNotificationChannel(
    'high_importance_channel',
    'Pemberitahuan kantor',
    description: 'Kabar lain dari kantor.',
    importance: Importance.max,
  );

  static final FlutterLocalNotificationsPlugin _lokal =
      FlutterLocalNotificationsPlugin();

  static bool _aktif = false;
  static int? _ritTertunda;

  static VoidCallback? saatMuatanBaru;
  static void Function(int ritId)? saatBukaRit;

  /// False bila Firebase gagal menyala, misalnya `google-services.json` belum
  /// dipasang. Aplikasinya tetap jalan, hanya tanpa notifikasi.
  static bool get aktif => _aktif;

  static Future<void> siapkan() async {
    if (_aktif) return;

    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('[Notifikasi] Firebase tidak menyala, notifikasi mati: $e');
      return;
    }

    await _lokal.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_truk'),
      ),
      onDidReceiveNotificationResponse: (respons) =>
          _bukaRit(int.tryParse(respons.payload ?? '')),
    );

    final android = _lokal.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(_channelMuatan);
    await android?.createNotificationChannel(_channelUmum);

    _aktif = true;

    FirebaseMessaging.onMessage.listen(_saatPesanDiDepan);
    FirebaseMessaging.onMessageOpenedApp.listen(_saatNotifikasiDiketuk);
    FirebaseMessaging.instance.onTokenRefresh.listen(_kirimToken);

    // Dibuka dari keadaan tertutup lewat notifikasi: layar utama belum ada,
    // jadi rit-nya dicatat dulu untuk [bukaRitTertunda].
    final pembuka = await FirebaseMessaging.instance.getInitialMessage();
    if (pembuka != null) _ritTertunda = _idRit(pembuka.data);

    // Sama, untuk notifikasi yang dulu dimunculkan aplikasi ini sendiri.
    final peluncur = await _lokal.getNotificationAppLaunchDetails();
    if (peluncur?.didNotificationLaunchApp ?? false) {
      _ritTertunda ??=
          int.tryParse(peluncur?.notificationResponse?.payload ?? '');
    }
  }

  /// Meminta izin notifikasi lalu mendaftarkan HP ini ke akun driver.
  static Future<void> daftarkanPerangkat() async {
    if (!_aktif) return;

    try {
      await FirebaseMessaging.instance.requestPermission();

      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _kirimToken(token);
    } catch (e) {
      debugPrint('[Notifikasi] Gagal mendaftarkan perangkat: $e');
    }
  }

  static void bukaRitTertunda() {
    final ritId = _ritTertunda;
    _ritTertunda = null;
    _bukaRit(ritId);
  }

  static void lupakanRitTertunda() => _ritTertunda = null;

  static Future<void> _kirimToken(String token) async {
    // Tanpa sesi, server menjawab 401 dan itu memicu "sesi berakhir".
    if (await ServisPenyimpananAman.ambilToken() == null) return;

    final hasil =
        await ServisApi.post(KonstantaApi.fcmToken, {'fcm_token': token});
    if (!hasil.sukses) {
      debugPrint('[Notifikasi] Token belum tersimpan: ${hasil.pesan}');
    }
  }

  static Future<void> _saatPesanDiDepan(RemoteMessage pesan) async {
    final muatanBaru = pesan.data['type'] == tipeMuatanBaru;
    if (muatanBaru) saatMuatanBaru?.call();

    final isi = pesan.notification;
    if (isi == null) return;

    final channel = muatanBaru ? _channelMuatan : _channelUmum;

    await _lokal.show(
      pesan.hashCode,
      isi.title,
      isi.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: Importance.max,
          priority: Priority.high,
          sound: channel.sound,
          styleInformation: BigTextStyleInformation(isi.body ?? ''),
          color: const Color(0xFFEA580C),
        ),
      ),
      payload: _idRit(pesan.data)?.toString(),
    );
  }

  static void _saatNotifikasiDiketuk(RemoteMessage pesan) =>
      _bukaRit(_idRit(pesan.data));

  static void _bukaRit(int? ritId) {
    if (ritId == null) return;
    saatBukaRit?.call(ritId);
  }

  static int? _idRit(Map<String, dynamic> data) =>
      int.tryParse(data['daftar_muat_id']?.toString() ?? '');
}
