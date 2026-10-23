import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'servis_penyimpanan_aman.dart';

typedef RealtimeHandler = void Function(Map<String, dynamic> data);

/// Sambungan WebSocket ke server Reverb, protokol Pusher ditulis langsung.
///
/// Disalin dari aplikasi sales dan dibiarkan sama persis: keduanya menyambung
/// ke server yang sama, jadi perbedaan sekecil apa pun di sini akan menjadi
/// bug yang cuma muncul di salah satu aplikasi dan sulit dilacak.
///
/// Ditulis tangan, bukan memakai paket Pusher, karena Reverb dijalankan di
/// host sendiri dan paket-paket itu mengunci alamatnya ke layanan Pusher.
class ServisRealtime {
  ServisRealtime._();
  static final ServisRealtime instance = ServisRealtime._();

  WebSocket? _socket;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  bool _disposed = false;
  bool _intentionalClose = false;
  String? _socketId; // diterima dari pusher:connection_established

  // listeners[channel][event] = [handler1, handler2, ...]
  final Map<String, Map<String, List<RealtimeHandler>>> _listeners = {};
  final Set<String> _subscribedChannels = {};

  bool get isConnected =>
      _socket != null && _socket!.readyState == WebSocket.open;

  // ── CONNECT ──────────────────────────────────────────────────

  Future<void> connect() async {
    if (isConnected) return;

    // Reset flag dari disconnect() sebelumnya — tanpa ini, reconnect otomatis
    // (_scheduleReconnect) tetap mati permanen walau sudah login ulang.
    _disposed = false;
    _intentionalClose = false;

    final host = dotenv.env['REVERB_HOST'] ?? '127.0.0.1';
    final port = dotenv.env['REVERB_PORT'] ?? '8080';
    final key = dotenv.env['REVERB_KEY'] ?? '';
    final scheme = dotenv.env['REVERB_SCHEME'] ?? 'http';
    final wsScheme = scheme == 'https' ? 'wss' : 'ws';

    // Endpoint Pusher/Reverb WebSocket
    final uri = '$wsScheme://$host:$port/app/$key'
        '?protocol=7&client=dart&version=1.0&flash=false';

    _socketId = null;

    try {
      _socket = await WebSocket.connect(uri);
      debugPrint('[Realtime] Connected: $uri');

      _socket!.listen(
        _onData,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );

      _startPing();
      // Berlangganan ulang menunggu pusher:connection_established, karena
      // channel private butuh socket_id dari koneksi ini.
    } catch (e) {
      debugPrint('[Realtime] Connect error: $e');
      _scheduleReconnect();
    }
  }

  // ── DISCONNECT ───────────────────────────────────────────────

  Future<void> disconnect() async {
    _intentionalClose = true;
    _disposed = true;
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    await _socket?.close();
    _socket = null;
    _listeners.clear();
    _subscribedChannels.clear();
    debugPrint('[Realtime] Disconnected');
  }

  // ── SUBSCRIBE / UNSUBSCRIBE ──────────────────────────────────

  void subscribe(String channel) {
    if (_subscribedChannels.contains(channel)) return;
    _subscribedChannels.add(channel);
    _listeners.putIfAbsent(channel, () => {});

    if (isConnected) {
      _sendSubscribe(channel); // fire-and-forget — async internally
    }
  }

  void unsubscribe(String channel) {
    _subscribedChannels.remove(channel);
    _listeners.remove(channel);
    if (isConnected) {
      _send({
        'event': 'pusher:unsubscribe',
        'data': {'channel': channel}
      });
    }
    debugPrint('[Realtime] Unsubscribed: $channel');
  }

  Future<void> _sendSubscribe(String channel) async {
    if (channel.startsWith('private-')) {
      // Belum ada socket_id: akan dikirim oleh _resubscribeAll saat koneksi siap.
      if (_socketId == null) return;
      // Private channel butuh auth handshake ke /broadcasting/auth
      await _sendPrivateSubscribe(channel);
    } else {
      _send({
        'event': 'pusher:subscribe',
        'data': {'channel': channel}
      });
    }
    debugPrint('[Realtime] Subscribed: $channel');
  }

  Future<void> _sendPrivateSubscribe(String channel) async {
    try {
      final token = await ServisPenyimpananAman.ambilToken();
      final baseUrl = dotenv.env['BASE_URL'] ?? '';
      // BASE_URL biasanya berakhiran /api — ganti dengan /broadcasting/auth
      final authUrl =
          baseUrl.replaceAll(RegExp(r'/api/?$'), '/broadcasting/auth');

      final dio = Dio();
      final res = await dio.post(
        authUrl,
        data: {
          'socket_id': _socketId,
          'channel_name': channel,
        },
        options: Options(headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded',
        }),
      );

      final auth = res.data['auth'] as String?;
      if (auth == null) {
        debugPrint(
            '[Realtime] Auth failed for $channel — no auth token in response');
        return;
      }

      _send({
        'event': 'pusher:subscribe',
        'data': {'channel': channel, 'auth': auth},
      });
    } catch (e) {
      debugPrint('[Realtime] Private channel auth error for $channel: $e');
    }
  }

  void _resubscribeAll() {
    for (final ch in _subscribedChannels) {
      _sendSubscribe(ch);
    }
  }

  // ── LISTENER REGISTRATION ────────────────────────────────────

  void on(String channel, String event, RealtimeHandler handler) {
    _listeners.putIfAbsent(channel, () => {});
    _listeners[channel]!.putIfAbsent(event, () => []);
    _listeners[channel]![event]!.add(handler);
  }

  void off(String channel, String event, RealtimeHandler handler) {
    _listeners[channel]?[event]?.remove(handler);
  }

  void offChannel(String channel) {
    _listeners[channel]?.clear();
  }

  // ── SEND ─────────────────────────────────────────────────────

  void _send(Map<String, dynamic> payload) {
    if (!isConnected) return;
    try {
      _socket!.add(jsonEncode(payload));
    } catch (e) {
      debugPrint('[Realtime] Send error: $e');
    }
  }

  // ── DATA HANDLING ────────────────────────────────────────────

  void _onData(dynamic raw) {
    try {
      final envelope = jsonDecode(raw as String) as Map<String, dynamic>;
      final event = envelope['event'] as String? ?? '';
      final channel = envelope['channel'] as String? ?? '';
      final rawData =
          envelope['data']; // declare early — needed for connection_established

      // Simpan socket_id dari koneksi awal — diperlukan untuk private channel auth
      if (event == 'pusher:connection_established') {
        final connData = rawData is String ? jsonDecode(rawData) : rawData;
        if (connData is Map) _socketId = connData['socket_id']?.toString();
        debugPrint('[Realtime] socket_id: $_socketId');
        _resubscribeAll();
        return;
      }

      // Balas ping Reverb
      if (event == 'pusher:ping') {
        _send({'event': 'pusher:pong', 'data': {}});
        return;
      }

      // Abaikan event internal Pusher
      if (event.startsWith('pusher:') || event.startsWith('pusher_internal:')) {
        return;
      }

      // Parse data (bisa string JSON atau object)
      Map<String, dynamic> data = {};
      if (rawData is String && rawData.isNotEmpty) {
        try {
          data = Map<String, dynamic>.from(jsonDecode(rawData));
        } catch (_) {}
      } else if (rawData is Map) {
        data = Map<String, dynamic>.from(rawData);
      }

      _dispatch(channel, event, data);
    } catch (e) {
      debugPrint('[Realtime] Parse error: $e');
    }
  }

  void _dispatch(String channel, String rawEvent, Map<String, dynamic> data) {
    // Reverb kirim event sebagai: "App\Events\ChatMessageSent"
    // Normalize ke: "ChatMessageSent"
    final normalized = rawEvent.contains('\\')
        ? rawEvent.split('\\').last
        : rawEvent.startsWith('.')
            ? rawEvent.substring(1)
            : rawEvent;

    debugPrint('[Realtime] ← $normalized on $channel');

    final channelListeners = _listeners[channel];
    if (channelListeners == null) return;

    // Coba berbagai format nama event
    final candidates = [rawEvent, normalized, '.$normalized'];
    for (final name in candidates) {
      final handlers = channelListeners[name];
      if (handlers != null && handlers.isNotEmpty) {
        for (final h in List<RealtimeHandler>.from(handlers)) {
          h(data);
        }
        return;
      }
    }
  }

  // ── PING / KEEPALIVE ─────────────────────────────────────────

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      _send({'event': 'pusher:ping', 'data': {}});
    });
  }

  // ── RECONNECT ────────────────────────────────────────────────

  void _onError(dynamic error) {
    debugPrint('[Realtime] Socket error: $error');
    _scheduleReconnect();
  }

  void _onDone() {
    debugPrint('[Realtime] Socket closed');
    _pingTimer?.cancel();
    if (!_intentionalClose && !_disposed) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_disposed || _intentionalClose) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      debugPrint('[Realtime] Reconnecting...');
      connect();
    });
  }
}
