import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'env.dart'; // <-- Pull API base URL and mode

class TokenManager {
  static const _storage = FlutterSecureStorage();

  /// Build the base API URL using Environment.baseUrl
  static String get _apiBase {
    final url = Environment.baseUrl; // defined in env.dart (already includes port)
    print('[TokenManager] Using API Base URL: $url');
    return url;
  }

  /// Request a token from your backend (uses env.dart)
  static Future<String?> requestToken(
      String name, String dob, String login, String unionId) async {
    print('[TokenManager] Requesting token for user: $name, email: $login');
    final uri = Uri.parse("$_apiBase/consumer/register");

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "name": name,
          "email": login,
          "dob": dob,              // YYYY-MM-DD
          "union_name": unionId,   // MUST MATCH BACKEND
          "gender": null,          // backend needs gender param present
        }),
      );

      print('[TokenManager] Response status: ${response.statusCode}');
      print('[TokenManager] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final token = data['singleUseToken'];
        final userId = data['userId'];

        if (token != null) {
          await _storage.write(key: 'auth_token', value: token);
          if (userId != null) {
            await _storage.write(key: 'userId', value: userId.toString());
          }

          print('[TokenManager] Token and userId stored.');
          return token;
        } else {
          print("[TokenManager] Missing 'singleUseToken' in response.");
        }
      } else {
        print("[TokenManager] Registration failed.");
      }
    } catch (e, stack) {
      print('[TokenManager] Exception during requestToken: $e');
      print(stack);
    }

    return null;
  }

  /// Submit measurement with token validation
  static Future<bool> submitMeasurement(
      Map<String, dynamic> measurement) async {
    print('[TokenManager] Submitting measurement...');

    try {
      final token = await _storage.read(key: 'auth_token');
      final userId = await _storage.read(key: 'userId');

      if (token == null || userId == null) {
        print('[TokenManager] No token or userId found → aborting.');
        return false;
      }

      final uri = Uri.parse("$_apiBase/consumer/token");

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "userId": userId,
          "token": token,
          "measurement": measurement,
        }),
      );

      print('[TokenManager] Response status: ${response.statusCode}');
      print('[TokenManager] Response body: ${response.body}');

      return response.statusCode == 200;
    } catch (e, stack) {
      print('[TokenManager] Exception: $e');
      print(stack);
      return false;
    }
  }
}
