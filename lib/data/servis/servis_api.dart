import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:flutter/widgets.dart';
import 'package:logger/logger.dart';

import '../../inti/konstanta/konstanta_api.dart';
import 'hasil_api.dart';
import 'servis_penyimpanan_aman.dart';

/// Satu pintu keluar untuk semua panggilan jaringan.
///
/// Berbeda dari aplikasi sales, kelas ini tidak mengompres gambar. Kompresi
/// dilakukan sekali saja di servis kamera; di sana gambar sempat dikompres dua
/// kali sehingga kualitas turun tanpa perlu.
class ServisApi {
  ServisApi._();

  static final _logger = Logger(
    printer: PrettyPrinter(methodCount: 0, lineLength: 80),
  );

  static Dio? _dio;

  /// Dipasang di main.dart untuk melempar pengguna ke layar login.
  static void Function()? onUnauthorized;

  static bool _sedangMenanganiUnauthorized = false;

  /// Penanda di `Options.extra` untuk permintaan non-GET yang tetap aman
  /// diulang otomatis karena servernya idempoten.
  static const String _bolehDiulang = 'boleh_diulang';

  static final Map<String, CancelToken> _requestAktif = {};
  static int _penghitungRequest = 0;

  static Dio get dio => _dio ??= _buatDio();

  static Dio _buatDio() {
    final dio = Dio(BaseOptions(
      baseUrl: KonstantaApi.baseUrl,
      connectTimeout: KonstantaApi.connectTimeout,
      receiveTimeout: KonstantaApi.timeout,
      sendTimeout: KonstantaApi.sendTimeout,
      validateStatus: (status) => status != null && status < 500,
      headers: {'Accept': 'application/json'},
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await ServisPenyimpananAman.ambilToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        if (KonstantaApi.isDebug) {
          _logger.d('→ ${options.method} ${options.path}');
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        if (KonstantaApi.isDebug) {
          _logger.d('← ${response.statusCode} ${response.requestOptions.path}');
        }

        // Sebagian endpoint Laravel membalas 200 dengan body "Unauthenticated."
        if (response.statusCode == 401 ||
            (response.data is Map &&
                response.data['message'] == 'Unauthenticated.')) {
          _tanganiUnauthorized();
        }

        handler.next(response);
      },
      onError: (error, handler) {
        if (error.type == DioExceptionType.cancel) {
          handler.reject(error);
          return;
        }
        if (error.response?.statusCode == 401) {
          _tanganiUnauthorized();
        }
        handler.next(error);
      },
    ));

    dio.interceptors.add(RetryInterceptor(
      dio: dio,
      retries: 3,
      // Jeda dinaikkan dari 1/2/3 detik. Sinyal yang sedang tersendat jarang
      // pulih dalam sedetik, dan mencoba lagi terlalu cepat hanya menumpuk
      // permintaan yang sama-sama gagal.
      retryDelays: const [
        Duration(seconds: 2),
        Duration(seconds: 5),
        Duration(seconds: 10),
      ],
      retryEvaluator: (error, attempt) {
        if (error.type == DioExceptionType.cancel) return false;
        if (error.response?.statusCode == 401) return false;

        // GET/HEAD selalu boleh diulang. POST hanya bila ditandai aman oleh
        // pemanggilnya: server bisa saja sudah memproses POST walau responsnya
        // telat sampai, dan mengulang yang tidak idempoten menghasilkan
        // transisi status atau foto ganda. Unggah foto bukti ditandai aman
        // karena server mengenalinya lewat client_uuid.
        final method = error.requestOptions.method.toUpperCase();
        final aman = error.requestOptions.extra[_bolehDiulang] == true;
        if (method != 'GET' && method != 'HEAD' && !aman) return false;

        return error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.sendTimeout ||
            error.type == DioExceptionType.receiveTimeout ||
            error.type == DioExceptionType.connectionError;
      },
    ));

    return dio;
  }

  static void _tanganiUnauthorized() async {
    if (_sedangMenanganiUnauthorized) return;
    _sedangMenanganiUnauthorized = true;

    try {
      await ServisPenyimpananAman.hapusSesi();
      final aksi = onUnauthorized;
      if (aksi != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => aksi());
      }
    } finally {
      await Future.delayed(const Duration(seconds: 3));
      _sedangMenanganiUnauthorized = false;
    }
  }

  static void batalkanSemuaRequest() {
    for (final token in _requestAktif.values) {
      if (!token.isCancelled) token.cancel('Sesi berakhir');
    }
    _requestAktif.clear();
  }

  static void reset() {
    batalkanSemuaRequest();
    _dio = null;
  }

  // ── Metode HTTP ───────────────────────────────────────────────

  static Future<HasilApi<dynamic>> get(String endpoint) =>
      _jalankan((dio, token) => dio.get(endpoint, cancelToken: token));

  static Future<HasilApi<dynamic>> post(
    String endpoint, [
    Map<String, dynamic>? body,
  ]) =>
      _jalankan(
          (dio, token) => dio.post(endpoint, data: body, cancelToken: token));

  static Future<HasilApi<dynamic>> delete(String endpoint) =>
      _jalankan((dio, token) => dio.delete(endpoint, cancelToken: token));

  /// Unggah satu berkas beserta kolom pendampingnya.
  ///
  /// Gambar dikirim apa adanya: kompresi sudah dilakukan sekali di
  /// [ServisKamera] saat foto dijepret, dan mengompresnya lagi di sini hanya
  /// menurunkan kualitas tanpa menghemat apa pun.
  ///
  /// Berkasnya dibaca dari path, bukan dari memori, supaya foto yang menunggu
  /// giliran di antrian tidak menahan RAM.
  static Future<HasilApi<dynamic>> unggah(
    String endpoint, {
    required String namaField,
    required String path,
    Map<String, dynamic> kolom = const {},
  }) async {
    final berkas = File(path);

    // Bentuk asinkron, bukan existsSync/lengthSync: yang sinkron menahan
    // isolate tampilan sampai cakram menjawab, dan unggahan foto bisa
    // dijalankan berbarengan dengan sopir menggulir layarnya.
    if (!await berkas.exists()) {
      return HasilApi.gagal('Berkas fotonya sudah tidak ada di HP.');
    }

    // Jatah waktu dihitung dari besar berkasnya. Foto 1,5 MB di sinyal satu
    // bar butuh jauh lebih lama daripada 200 KB di WiFi, dan satu angka mati
    // untuk keduanya berarti salah satunya pasti dipotong percuma.
    final mb = await berkas.length() / (1024 * 1024);
    final kirimTimeout =
        KonstantaApi.unggahDasar + KonstantaApi.unggahPerMb * mb;

    return _jalankan((dio, token) async {
      // FormData dibangun di dalam aksi, bukan di luar, karena isinya habis
      // terpakai sekali kirim dan tidak bisa dipakai ulang.
      //
      // MultipartFileRecreatable, bukan MultipartFile: hanya bentuk ini yang
      // bisa disusun ulang oleh RetryInterceptor. Dengan MultipartFile biasa,
      // percobaan kedua mengirim badan permintaan yang sudah habis terbaca.
      final form = FormData.fromMap({
        ...kolom,
        namaField: MultipartFileRecreatable.fromFileSync(
          path,
          filename: path.split('/').last,
        ),
      });

      return dio.post(
        endpoint,
        data: form,
        cancelToken: token,
        options: Options(
          sendTimeout: kirimTimeout,
          receiveTimeout: KonstantaApi.unggahTerima,
          // Unggah foto bukti aman diulang: server mengenali client_uuid dan
          // menjawab foto yang sama, tidak membuat duplikat.
          extra: const {_bolehDiulang: true},
        ),
      );
    });
  }

  static Future<HasilApi<dynamic>> _jalankan(
    Future<Response> Function(Dio dio, CancelToken token) aksi,
  ) async {
    final cancelToken = CancelToken();
    final id = 'req_${++_penghitungRequest}';
    _requestAktif[id] = cancelToken;

    try {
      return _bacaRespons(await aksi(dio, cancelToken));
    } on DioException catch (e) {
      return _bacaError(e);
    } finally {
      _requestAktif.remove(id);
    }
  }

  // ── Penerjemah respons ────────────────────────────────────────

  /// Endpoint driver selalu membalas {success, message, data}, jadi tidak ada
  /// lagi pengecekan ganda status/success seperti di aplikasi sales.
  static HasilApi<dynamic> _bacaRespons(Response response) {
    final body = response.data;

    if (body is! Map) {
      return HasilApi.gagal('Respons server tidak dikenali');
    }

    if (body['success'] == true) {
      return HasilApi.sukses(body['data'], body['message']?.toString() ?? '');
    }

    return HasilApi.gagal(
      body['message']?.toString() ?? 'Permintaan ditolak server',
      kode: body['code']?.toString(),
    );
  }

  static HasilApi<dynamic> _bacaError(DioException e) {
    final offline = switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError =>
        true,
      _ => false,
    };

    if (offline) {
      // Tidak menjanjikan "akan dikirim ulang": yang punya antrian hanya foto
      // bukti. Laporan dan perubahan status tidak diantrikan, dan janji yang
      // tidak ditepati membuat driver mengira pekerjaannya sudah terkirim.
      // Pemanggil yang memang punya antrian menuliskan janjinya sendiri.
      final lambat = e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout;

      return HasilApi.gagal(
        lambat
            ? 'Jaringan sedang lambat, kiriman belum tuntas. Coba lagi.'
            : 'Tidak ada koneksi ke server.',
        offline: true,
      );
    }

    final body = e.response?.data;
    if (body is Map) {
      var pesan = body['message']?.toString() ?? 'Terjadi kesalahan';

      // Pesan validasi Laravel diratakan jadi satu kalimat.
      final errors = body['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final rinci =
            errors.values.expand((v) => v is List ? v : [v]).take(3).join(', ');
        if (rinci.isNotEmpty) pesan = rinci;
      }

      return HasilApi.gagal(pesan, kode: body['code']?.toString());
    }

    return HasilApi.gagal('Terjadi kesalahan pada server');
  }
}
