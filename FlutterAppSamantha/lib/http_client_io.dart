// Native implementation for iOS, Android, macOS, etc.
import 'dart:io';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

http.Client createHttpClient({
  bool skipCertificateValidation = false,
  Duration? timeout,
}) {
  final ioc = HttpClient();

  // Only allow skipping SSL in debug builds — never in release.
  if (skipCertificateValidation && kDebugMode) {
    ioc.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }

  if (timeout != null) {
    ioc.connectionTimeout = timeout;
  }

  return IOClient(ioc);
}
