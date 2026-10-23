import 'package:flutter/material.dart';

/// Dipakai untuk navigasi dari luar widget tree, misalnya saat interceptor
/// jaringan mendeteksi token kedaluwarsa dan harus melempar ke layar login.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
