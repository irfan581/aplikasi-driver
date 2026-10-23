import 'dart:convert';
import 'dart:io';

import 'package:driver_tmk/data/servis/servis_realtime.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Server Reverb tiruan: socket_id baru dikirim sesaat setelah tersambung,
/// seperti server sungguhan. Izin channel private tidak boleh diminta sebelum
/// socket_id itu diterima.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Binding uji memblokir HTTP sungguhan; uji ini butuh server lokal.
  HttpOverrides.global = null;
  FlutterSecureStorage.setMockInitialValues({});

  test('izin channel private memakai socket_id dari koneksi', () async {
    final socketIdDiminta = <String?>[];
    final pesanMasuk = <String>[];

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      if (req.uri.path.startsWith('/app/')) {
        final ws = await WebSocketTransformer.upgrade(req);
        ws.listen((m) => pesanMasuk.add(m as String));
        await Future<void>.delayed(const Duration(milliseconds: 300));
        ws.add(jsonEncode({
          'event': 'pusher:connection_established',
          'data': jsonEncode({'socket_id': '123.456'}),
        }));
      } else if (req.uri.path == '/broadcasting/auth') {
        final isi = Uri.splitQueryString(await utf8.decodeStream(req));
        socketIdDiminta.add(isi['socket_id']);
        req.response
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'auth': 'kunci:tanda'}));
        await req.response.close();
      }
    });

    dotenv.loadFromString(envString: '''
REVERB_HOST=127.0.0.1
REVERB_PORT=${server.port}
REVERB_KEY=kunci
REVERB_SCHEME=http
BASE_URL=http://127.0.0.1:${server.port}/api
''');

    final realtime = ServisRealtime.instance;
    realtime.subscribe('private-chat.group.1');
    await realtime.connect();
    await Future<void>.delayed(const Duration(seconds: 1));

    expect(socketIdDiminta, ['123.456']);
    expect(pesanMasuk.where((m) => m.contains('pusher:subscribe')), hasLength(1));

    await realtime.disconnect();
    await server.close(force: true);
  });
}
