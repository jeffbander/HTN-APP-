import 'dart:io';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Creates an HTTP client for mobile/desktop platforms.
/// SSL verification is only skipped in debug builds (never in release).
http.Client createPlatformHttpClient() {
  if (kDebugMode) {
    final ioc = HttpClient()
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
    return IOClient(ioc);
  } else {
    return http.Client();
  }
}
