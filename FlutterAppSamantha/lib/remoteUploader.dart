import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'dart:developer' as dev;
import 'env.dart';

class RemoteUploader {
  // Use Environment for remote backend URL
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

  Future<void> sendDataToBackend(
    String userInfo,
    String deviceId,
    List<Map<DateTime, List<dynamic>>> bloodPressureData,
  ) async {
    final client = _httpClient;
    print("[Remote] sendDataToBackend started...");

    try {
      print("[Remote] User info: $userInfo");
      print("[Remote] Device ID: $deviceId");
      print("[Remote] Data count: ${bloodPressureData.length}");

      final parts = userInfo.split(',');
      if (parts.length < 2) {
        print("[Remote] Invalid userInfo format: $userInfo");
        return;
      }
      final email = parts[1].trim();

      for (var i = 0; i < bloodPressureData.length; i++) {
        print("[Remote] Sending reading ${i + 1}/${bloodPressureData.length}");

        // ---- Step 1: Get a single-use token ----
        final loginPayload = jsonEncode({"email": email});
        print("[Remote] [Login Request] $loginPayload");

        http.Response loginResp;
        try {
          final loginUri = Uri.parse("$baseUrl/login");
          final stopwatch = Stopwatch()..start();
          loginResp = await client
              .post(
                loginUri,
                headers: {"Content-Type": "application/json"},
                body: loginPayload,
              )
              .timeout(const Duration(seconds: 8));
          print("[Remote] Login request took ${stopwatch.elapsedMilliseconds} ms");
        } on SocketException catch (e) {
          print("[Remote] Network error during login: $e");
          continue;
        } on TimeoutException {
          print("[Remote] Login request timed out!");
          continue;
        } catch (e, st) {
          print("[Remote] Unexpected login error: $e\n$st");
          continue;
        }

        if (loginResp.statusCode != 200) {
          print("[Remote] Login failed (${loginResp.statusCode}): ${loginResp.body}");
          continue;
        }

        final loginData = jsonDecode(loginResp.body);
        final token = loginData['singleUseToken'];
        if (token == null) {
          print("[Remote] Missing singleUseToken in response: $loginData");
          continue;
        }

        // ---- Step 2: Submit reading ----
        final measurement = bloodPressureData[i];
        final date = measurement.keys.first.toIso8601String();
        final values = measurement.values.first;

        final systolic = int.tryParse(values[0].toString()) ?? 0;
        final diastolic = int.tryParse(values[1].toString()) ?? 0;
        final heartRate = int.tryParse(values[2].toString()) ?? 0;

        final readingPayload = {
          "systolic": systolic,
          "diastolic": diastolic,
          "heartRate": heartRate,
          "readingDate": date,
        };
        print("[Remote] [Reading Request] $readingPayload");

        try {
          final readingUri = Uri.parse("$baseUrl/readings");
          final stopwatch = Stopwatch()..start();
          final resp = await client
              .post(
                readingUri,
                headers: {
                  "Content-Type": "application/json",
                  "Authorization": "Bearer $token",
                },
                body: jsonEncode(readingPayload),
              )
              .timeout(const Duration(seconds: 8));
          print("[Remote] Reading upload took ${stopwatch.elapsedMilliseconds} ms");

          if (resp.statusCode == 200) {
            print("[Remote] Reading ${i + 1} uploaded successfully!");
          } else {
            print("[Remote] Upload failed (${resp.statusCode}): ${resp.body}");
          }
        } on SocketException catch (e) {
          print("[Remote] Network error during reading upload: $e");
        } on TimeoutException {
          print("[Remote] Reading upload timed out!");
        } catch (e, st) {
          print("[Remote] Unexpected reading upload error: $e\n$st");
        }
      }

      print("[Remote] All readings processed for $email");
    } catch (e, stack) {
      print("[Remote] Fatal error in sendDataToBackend: $e\n$stack");
    } finally {
      client.close();
      print("[Remote] HTTP client closed");
    }
  }
}
