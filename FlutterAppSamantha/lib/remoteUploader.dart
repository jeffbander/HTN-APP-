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
    dev.log("[Remote] sendDataToBackend started...");

    try {
      dev.log("[Remote] [user info redacted]");
      dev.log("[Remote] Device ID: $deviceId");
      dev.log("[Remote] Data count: ${bloodPressureData.length}");

      final parts = userInfo.split(',');
      if (parts.length < 2) {
        dev.log("[Remote] Invalid userInfo format: [redacted]");
        return;
      }
      final email = parts[1].trim();

      for (var i = 0; i < bloodPressureData.length; i++) {
        dev.log("[Remote] Sending reading ${i + 1}/${bloodPressureData.length}");

        // ---- Step 1: Get a single-use token ----
        final loginPayload = jsonEncode({"email": email});
        dev.log("[Remote] [Login Request] [payload redacted]");

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
          dev.log("[Remote] Login request took ${stopwatch.elapsedMilliseconds} ms");
        } on SocketException catch (e) {
          dev.log("[Remote] Network error during login: $e");
          continue;
        } on TimeoutException {
          dev.log("[Remote] Login request timed out!");
          continue;
        } catch (e, st) {
          dev.log("[Remote] Unexpected login error: $e\n$st");
          continue;
        }

        if (loginResp.statusCode != 200) {
          dev.log("[Remote] Login failed: status ${loginResp.statusCode}");
          continue;
        }

        final loginData = jsonDecode(loginResp.body);
        final token = loginData['singleUseToken'];
        if (token == null) {
          dev.log("[Remote] Missing singleUseToken in response");
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
        dev.log("[Remote] [Reading Request] sending reading...");

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
          dev.log("[Remote] Reading upload took ${stopwatch.elapsedMilliseconds} ms");

          if (resp.statusCode == 200) {
            dev.log("[Remote] Reading ${i + 1} uploaded successfully!");
          } else {
            dev.log("[Remote] Upload failed: status ${resp.statusCode}");
          }
        } on SocketException catch (e) {
          dev.log("[Remote] Network error during reading upload: $e");
        } on TimeoutException {
          dev.log("[Remote] Reading upload timed out!");
        } catch (e, st) {
          dev.log("[Remote] Unexpected reading upload error: $e\n$st");
        }
      }

      dev.log("[Remote] All readings processed for [email redacted]");
    } catch (e, stack) {
      dev.log("[Remote] Fatal error in sendDataToBackend: $e\n$stack");
    } finally {
      client.close();
      dev.log("[Remote] HTTP client closed");
    }
  }
}
