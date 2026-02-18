import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'dart:developer' as dev;
import 'env.dart';

class RemoteRegUsr {
  String get baseUrl => Environment.remoteApiUrl();

  /// HTTP client — SSL bypass only in debug builds, never in release.
  http.Client get _httpClient {
    if (kDebugMode) {
      final ioc = HttpClient()
        ..badCertificateCallback =
            (X509Certificate cert, String host, int port) => true;
      return IOClient(ioc);
    } else {
      return http.Client();
    }
  }

  /// Converts MM/DD/YYYY to YYYY-MM-DD
  String _formatBirthday(String dob) {
    final parts = dob.split("/");
    if (parts.length != 3) return dob;
    return "${parts[2]}-${parts[0].padLeft(2, '0')}-${parts[1].padLeft(2, '0')}";
  }

  /// Fetches unions from remote backend
  Future<Map<int, String>> fetchUnions() async {
    final client = _httpClient;
    try {
      final uri = Uri.parse("$baseUrl/unions");
      dev.log("[Remote] Fetching unions from $uri");

      final resp = await client.get(uri).timeout(const Duration(seconds: 8));
      dev.log("[Remote] Response status: ${resp.statusCode}");

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final unionsMap = data.map((key, value) => MapEntry(int.parse(key), value as String));
        dev.log("[Remote] Unions fetched: ${unionsMap.toString()}");
        return unionsMap;
      } else {
        dev.log("[Remote] Failed to fetch unions: ${resp.statusCode}");
        return {};
      }
    } catch (e, stack) {
      dev.log("[Remote] Error fetching unions: $e\n$stack");
      return {};
    } finally {
      client.close();
    }
  }

  /// Registers a user on the remote backend
  Future<String?> registerUserInfo(
      String name, String email, String birthday, int unionId,
      {String? bearerToken}) async {
    final client = _httpClient;
    try {
      final payload = jsonEncode({
        "name": name,
        "email": email,
        "birthday": _formatBirthday(birthday),
        "union_id": unionId,
      });

      final headers = {
        "Content-Type": "application/json",
        if (bearerToken != null) "Authorization": "Bearer $bearerToken",
      };

      final uri = Uri.parse("$baseUrl/register");
      dev.log("[Remote] Sending registration payload: $payload to $uri");

      final resp = await client
          .post(uri, headers: headers, body: payload)
          .timeout(const Duration(seconds: 8));

      if (resp.statusCode != 200) {
        dev.log("[Remote] Registration failed: ${resp.statusCode}");
        dev.log("[Remote] Response: ${resp.body}");
        return null;
      }

      final data = jsonDecode(resp.body);
      final token = data['singleUseToken'];
      if (token != null) {
        dev.log("[Remote] Registration successful, token present");
      } else {
        dev.log("[Remote] Registration response missing token");
      }

      return token;
    } catch (e, stack) {
      dev.log("[Remote] Error registering user: $e\n$stack");
      return null;
    } finally {
      client.close();
    }
  }
}
