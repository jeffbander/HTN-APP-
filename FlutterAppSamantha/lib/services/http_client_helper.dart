import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../env.dart';

// Conditional import for dart:io
import 'http_client_io.dart' if (dart.library.html) 'http_client_web.dart' as platform;

/// Creates an HTTP client appropriate for the current platform
http.Client createHttpClient() {
  return platform.createPlatformHttpClient();
}
