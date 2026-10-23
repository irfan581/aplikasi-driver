# Changelog

## 2026-08-29 — Perbaikan bug antrian foto & kompresi

### 1. Race condition di antrian upload foto bukti bongkar
**File:** `lib/data/servis/servis_antrian_foto.dart`

**Masalah:** `kirimTertunda()` membaca snapshot antrian di awal, menjalankan
upload sequential (bisa berlangsung beberapa detik per foto), lalu menimpa
penyimpanan dengan hasil akhirnya. Kalau driver menjepret foto baru lewat
`tambah()` saat upload sebelumnya masih berjalan, foto baru itu bisa
tertimpa dan hilang dari antrian tanpa error apa pun.

**Perbaikan:**
- Ditambah mutex sederhana (`_terkunci` / `_gembok`) yang menyerialkan semua
  operasi baca-ubah-tulis pada penyimpanan (`tambah`, `buang`, dan tahap
  commit di `kirimTertunda`).
- `kirimTertunda()` tidak lagi menimpa penyimpanan dengan snapshot lama.
  Hasil upload dicatat per `clientUuid`, lalu digabungkan ke state
  penyimpanan **terkini** saat commit — sehingga foto yang ditambahkan
  selama proses upload berjalan tetap aman.

### 2. Kompresi foto tidak membatasi sisi terpanjang sesuai maksud
**File:** `lib/data/servis/servis_kamera.dart`

**Masalah:** `minWidth`/`minHeight` pada `flutter_image_compress` diisi sama
(`_lebarMaks` = 1280 untuk keduanya). Library ini menskalakan gambar sampai
**kedua** sisi memenuhi nilai minimum tersebut, bukan membatasi sisi
terpanjang. Untuk foto potret khas kamera HP (mis. 3024×4032), hasilnya
sisi pendek pas 1280px tapi sisi panjang melebihi itu (~1706px) — meleset
dari maksud komentar "1280px sisi terpanjang".

**Perbaikan:**
- Ditambah `_ukuranGambar()` yang membaca dimensi asli foto lewat `dart:ui`
  (tanpa dependency baru).
- `_kompres()` sekarang mendeteksi orientasi foto (potret/lanskap) dan hanya
  memberi batas 1280px ke sisi yang memang lebih panjang; sisi pendek
  dibiarkan bebas (min 1px) sehingga skalanya benar-benar menjadikan sisi
  terpanjang 1280px.
- Jika dimensi gagal dibaca, fallback ke perilaku lama (batas simetris)
  supaya kompresi tetap berjalan.

**Verifikasi:** `dart analyze` bersih untuk kedua file.
