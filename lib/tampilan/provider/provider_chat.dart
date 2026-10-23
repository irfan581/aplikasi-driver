import 'package:flutter/foundation.dart';

import '../../data/model/model_chat.dart';
import '../../data/repositori/repositori_chat.dart';
import '../../data/servis/servis_realtime.dart';
import '../../inti/konstanta/konstanta_api.dart';

/// Grup chat laporan kiriman, dari sisi sopir.
///
/// Hanya satu grup yang dipedulikan — grup laporan tempat setiap laporan
/// bongkar otomatis muncul. Kalau nanti sopir dimasukkan ke grup lain,
/// [grup] tetap memuat semuanya dan layar tinggal memilih.
class ProviderChat extends ChangeNotifier {
  ProviderChat(this._repo);

  final RepositoriChat _repo;
  final _realtime = ServisRealtime.instance;

  /// Id sopir yang sedang login. Dipakai menentukan pesan mana milik sendiri:
  /// siaran realtime selalu mengirim is_me = false karena satu siaran dibaca
  /// banyak orang, jadi penentuannya harus di sisi aplikasi.
  int? _idSopir;

  void setSopir(int? id) => _idSopir = id;

  List<ModelGrupChat> _grup = [];
  List<ModelPesanChat> _pesan = [];

  bool _memuat = false;
  bool _mengirim = false;
  String? _galat;

  /// Grup yang sedang dibuka layarnya. null berarti percakapannya belum
  /// pernah diambil.
  int? _grupAktif;

  /// Grup yang didengarkan siarannya. Diisi sejak aplikasi dibuka, tanpa
  /// menunggu tabnya dibuka — kalau menunggu, pesan yang masuk selagi sopir
  /// ada di tab lain tidak akan pernah sampai dan lencananya diam terus.
  int? _grupDipantau;
  int _halaman = 1;
  bool _adaLagi = true;
  bool _memuatLagi = false;
  int _belumDibaca = 0;

  /// Tab Grup sedang ditampilkan atau tidak. IndexedStack membangun keempat
  /// layar sekaligus, jadi "layarnya hidup" bukan berarti "sedang dilihat" —
  /// tanpa penanda ini setiap pesan masuk akan dianggap sudah terbaca.
  bool _sedangDilihat = false;

  List<ModelGrupChat> get grup => _grup;
  List<ModelPesanChat> get pesan => _pesan;
  bool get memuat => _memuat;
  bool get mengirim => _mengirim;
  bool get memuatLagi => _memuatLagi;
  bool get adaLagi => _adaLagi;
  String? get galat => _galat;
  int? get grupAktif => _grupAktif;

  /// Jumlah pesan yang belum dibaca, untuk lencana di navigasi bawah.
  ///
  /// Dihitung sendiri, bukan dibaca ulang dari server tiap saat: pesan masuk
  /// lewat siaran realtime, jadi angkanya harus bergerak saat itu juga —
  /// menunggu permintaan jaringan berarti sopir baru tahu ada pesan setelah
  /// membuka tabnya, yang justru menghapus gunanya lencana.
  int get belumDibaca => _belumDibaca;

  ModelGrupChat? get grupUtama => _grup.isEmpty ? null : _grup.first;

  // ── Daftar grup ─────────────────────────────────────────────

  Future<void> muatGrup() async {
    _memuat = true;
    _galat = null;
    notifyListeners();

    final hasil = await _repo.grup();

    if (hasil.sukses) {
      _grup = hasil.data ?? [];
      _belumDibaca = _grup.fold(0, (jumlah, g) => jumlah + g.belumDibaca);
    } else {
      _galat = hasil.pesan;
    }

    _memuat = false;
    notifyListeners();

    final utama = grupUtama;
    if (utama == null) return;

    _sambungRealtime(utama.id);

    // Percakapannya baru diambil kalau tabnya memang sedang dilihat.
    // Mengambilnya lebih awal berarti server menandai semuanya terbaca padahal
    // sopir belum melihat apa pun — dan lencananya tidak akan pernah muncul.
    if (_sedangDilihat) await bukaGrup(utama.id);
  }

  // ── Isi percakapan ──────────────────────────────────────────

  Future<void> bukaGrup(int grupId) async {
    _grupAktif = grupId;
    _halaman = 1;
    _adaLagi = true;
    _pesan = [];
    _memuat = true;
    _galat = null;
    notifyListeners();

    final hasil = await _repo.pesan(grupId);

    if (hasil.sukses) {
      _pesan = hasil.data ?? [];
      _adaLagi = _pesan.length >= 50;
      // Server menandai terbaca saat pesannya diambil, jadi penghitung lokal
      // ikut dinolkan di sini — bukan ditebak, tapi mengikuti apa yang baru
      // saja terjadi di server.
      _belumDibaca = 0;
      _tandaiTerbaca(grupId);
    } else {
      _galat = hasil.pesan;
    }

    _memuat = false;
    notifyListeners();

    if (_grupDipantau != grupId) _sambungRealtime(grupId);
  }

  /// Menggali pesan lama saat sopir menggulir ke atas. Kegagalannya tidak
  /// menghapus yang sudah tampil — di sinyal buruk itu berarti percakapan
  /// yang sedang dibaca tiba-tiba kosong.
  Future<void> muatLebihLama() async {
    if (_memuatLagi || !_adaLagi || _grupAktif == null) return;

    _memuatLagi = true;
    notifyListeners();

    final hasil = await _repo.pesan(_grupAktif!, halaman: _halaman + 1);

    if (hasil.sukses) {
      final lama = hasil.data ?? [];
      if (lama.isEmpty) {
        _adaLagi = false;
      } else {
        _halaman++;
        _pesan = [...lama, ..._pesan];
        _adaLagi = lama.length >= 50;
      }
    }

    _memuatLagi = false;
    notifyListeners();
  }

  // ── Kirim ───────────────────────────────────────────────────

  Future<String?> kirimTeks(String teks) async {
    final isi = teks.trim();
    if (isi.isEmpty || _grupAktif == null) return null;

    _mengirim = true;
    notifyListeners();

    final hasil = await _repo.kirimTeks(_grupAktif!, isi);

    _mengirim = false;

    if (!hasil.sukses) {
      notifyListeners();
      return hasil.pesan;
    }

    _tambahSekali(hasil.data!);
    notifyListeners();
    return null;
  }

  Future<String?> kirimFoto(String path, {String teks = ''}) async {
    if (_grupAktif == null) return null;

    _mengirim = true;
    notifyListeners();

    final hasil = await _repo.kirimFoto(_grupAktif!, path, teks: teks);

    _mengirim = false;

    if (!hasil.sukses) {
      notifyListeners();
      return hasil.pesan;
    }

    _tambahSekali(hasil.data!);
    notifyListeners();
    return null;
  }

  // ── Realtime ────────────────────────────────────────────────

  void _sambungRealtime(int grupId) {
    _grupDipantau = grupId;
    final channel = KonstantaApi.channelGrup(grupId);

    // Pendengar lama dibuang lebih dulu. ServisRealtime.on() menumpuk handler
    // tanpa memeriksa duplikat, sedangkan bukaGrup() bisa dipanggil berkali-
    // kali — tiap kali sopir menekan "Coba Lagi" setelah sinyal putus, dan tiap
    // kali grupnya dibuka ulang. Tanpa ini pendengarnya beranak: satu pesan
    // masuk memicu handler lima kali di HP yang sinyalnya sering putus.
    _realtime.offChannel(channel);

    _realtime.connect();
    _realtime.subscribe(channel);

    // Didengarkan dengan dan tanpa titik di depan: Reverb mengirim nama event
    // ber-titik untuk broadcastAs, sedangkan sebagian jalur memakai nama
    // polos. Aplikasi sales melakukan hal yang sama.
    _realtime.on(channel, 'ChatMessageSent', _pesanMasuk);
    _realtime.on(channel, '.ChatMessageSent', _pesanMasuk);
  }

  void _pesanMasuk(Map<String, dynamic> data) {
    final isi = data['message'];
    if (isi is! Map) return;

    final json = isi.cast<String, dynamic>();

    // Dibandingkan dengan grup yang dipantau, bukan yang sedang dibuka:
    // pesan harus tetap dihitung walau percakapannya belum pernah diambil.
    if ((json['group_id'] as num?)?.toInt() != _grupDipantau) return;

    final dariSaya = _idSopir != null &&
        (json['sender_id'] as num?)?.toInt() == _idSopir &&
        json['sender_type']?.toString().endsWith('drivers') == true;

    final masuk = ModelPesanChat.fromJson(json).salinDariSaya(dariSaya);

    final sebelum = _pesan.length;
    _tambahSekali(masuk);

    // Hanya yang benar-benar baru dan bukan kiriman sendiri. Pesan yang datang
    // dua kali — lewat balasan kirim dan lewat siaran — tidak boleh menaikkan
    // angkanya dua kali.
    if (!dariSaya && !_sedangDilihat && _pesan.length > sebelum) {
      _belumDibaca++;
    }

    notifyListeners();
  }

  /// Menolak pesan yang id-nya sudah ada. Satu pesan bisa datang dua kali:
  /// lewat balasan kirim dan lewat siaran realtime.
  void _tambahSekali(ModelPesanChat pesanBaru) {
    if (pesanBaru.id != 0 && _pesan.any((p) => p.id == pesanBaru.id)) return;
    _pesan = [..._pesan, pesanBaru];
  }

  void _tandaiTerbaca(int grupId) {
    _grup = [
      for (final g in _grup)
        g.id == grupId
            ? ModelGrupChat(
                id: g.id,
                nama: g.nama,
                jumlahAnggota: g.jumlahAnggota,
                belumDibaca: 0,
                pesanTerakhir: g.pesanTerakhir,
                waktuTerakhir: g.waktuTerakhir,
              )
            : g,
    ];
  }

  /// Dipanggil navigasi bawah saat tab Grup dibuka atau ditinggalkan.
  ///
  /// Saat dibuka dan ada yang belum dibaca, percakapannya diambil ulang: itu
  /// sekaligus menandai terbaca di server, supaya lencana tidak muncul lagi
  /// di HP lain milik sopir yang sama.
  void setSedangDilihat(bool nilai) {
    if (_sedangDilihat == nilai) return;

    _sedangDilihat = nilai;

    final utama = grupUtama;

    // Diambil saat pertama kali tabnya dibuka, dan tiap kali ada yang belum
    // dibaca. Kalau tidak ada yang baru dan isinya sudah termuat, tidak ada
    // yang perlu diminta ke server.
    if (nilai && utama != null && (_grupAktif == null || _belumDibaca > 0)) {
      bukaGrup(utama.id);
      return;
    }

    notifyListeners();
  }

  void tutupGrup() {
    if (_grupAktif != null) {
      final channel = KonstantaApi.channelGrup(_grupAktif!);
      _realtime.offChannel(channel);
      _realtime.unsubscribe(channel);
    }
    _grupAktif = null;
    _grupDipantau = null;
    _pesan = [];
  }

  /// Dipanggil saat logout — kalau tidak, percakapan sopir sebelumnya tersisa
  /// saat sopir lain masuk di HP yang sama.
  void bersihkan() {
    tutupGrup();
    _realtime.disconnect();
    _grup = [];
    _galat = null;
    _memuat = false;
    _belumDibaca = 0;
    _sedangDilihat = false;
    notifyListeners();
  }
}
