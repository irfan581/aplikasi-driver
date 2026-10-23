# Aplikasi Driver

Aplikasi Android (Flutter) untuk sopir pengiriman sebuah distributor pupuk.
Sopir melihat kiriman yang ditugaskan admin, melaporkan bongkar di tiap tujuan
lengkap dengan foto bukti, dan melihat riwayat kirimannya.

> **Catatan salinan portofolio.** Repo ini salinan dari proyek nyata yang saya
> kerjakan untuk sebuah distributor pupuk di Jawa Timur. Nama usaha, domain,
> alamat, nomor telepon, nama karyawan, foto, logo, kunci Firebase, dan
> konfigurasi server sudah diganti atau dihapus. "Tani Makmur" adalah nama
> samaran. Riwayat commit tidak disertakan.

Backend dan panel admin ada di repo
[`sistem-distribusi-admin`](https://github.com/irfan581/sistem-distribusi-admin).

## Fitur

- **Beranda:** rit yang sedang dikerjakan dan rit lain hari ini
- **Detail rit:** daftar tujuan, navigasi, keterangan dari admin
- **Laporan bongkar:** foto dari kamera, dikirim lewat antrean supaya tetap
  terkirim walau sinyal putus
- **Riwayat:** rit yang sudah lewat
- **Notifikasi muatan baru:** pop-up dengan nada sendiri saat admin memberi rit
- **Chat grup laporan:** realtime lewat Reverb

## Teknologi

Flutter, Provider, Dio, Geolocator, Image Picker, Firebase Messaging,
flutter_local_notifications. Minimal Android 7.0 (SDK 24).

## Menjalankan

```bash
cp .env.example .env.development
cp .env.example .env.production
flutter pub get
flutter run
```

Tambahkan `android/app/google-services.json` dari proyek Firebase Anda sendiri;
berkas itu sengaja tidak disertakan.

## Uji

```bash
flutter analyze
flutter test
```
