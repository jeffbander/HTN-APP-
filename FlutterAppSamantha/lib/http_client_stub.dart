// Stub implementation for web platform
import 'package:http/http.dart' as http;

http.Client createHttpClient({
  bool skipCertificateValidation = false,
  Duration? timeout,
}) {
  // Web platform doesn't support custom certificate handling
  // Just return a regular client
  return http.Client();
}
