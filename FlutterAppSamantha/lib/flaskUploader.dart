import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'dart:developer' as dev;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'env.dart';
import 'services/sync_service.dart';

class FlaskUploader {
  // Use Environment base URL (without /consumer path — endpoints add it)
  String get baseUrl => Environment.baseUrl;

  final storage = const FlutterSecureStorage();
  final SyncService _syncService = SyncService.instance;

  /// Custom HTTP client — SSL bypass only in debug builds, never in release.
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
    dev.log("sendDataToBackend started...");

    try {
      dev.log("sendDataToBackend: [user info redacted]");
      dev.log("Device ID: $deviceId");
      dev.log("Data count: ${bloodPressureData.length}");

      final parts = userInfo.split(',');
      if (parts.length < 2) {
        dev.log("Invalid userInfo format: [redacted]");
        return;
      }
      final email = parts[1].trim();

      for (var i = 0; i < bloodPressureData.length; i++) {
        dev.log("Sending reading ${i + 1}/${bloodPressureData.length}");

        final measurement = bloodPressureData[i];
        final date = measurement.keys.first;
        final values = measurement.values.first;

        final systolic = int.tryParse(values[0].toString()) ?? 0;
        final diastolic = int.tryParse(values[1].toString()) ?? 0;
        final heartRate = int.tryParse(values[2].toString()) ?? 0;

        // Try to send directly first
        final success = await _trySendReading(
          client: client,
          email: email,
          systolic: systolic,
          diastolic: diastolic,
          heartRate: heartRate,
          readingDate: date,
        );

        // If direct send failed, queue for later
        if (!success) {
          dev.log("Direct send failed, queuing reading for later sync");
          await _syncService.queueReading(
            systolic: systolic,
            diastolic: diastolic,
            heartRate: heartRate,
            readingDate: date,
            deviceId: deviceId,
            userEmail: email,
          );
        }
      }

      dev.log("All readings processed for [email redacted]");
    } catch (e, stack) {
      dev.log("Fatal error in sendDataToBackend: $e\n$stack");
    } finally {
      client.close();
      dev.log("HTTP client closed");
    }
  }

  /// Attempts to send a single reading directly to the backend
  /// Returns true if successful, false if failed (should be queued)
  Future<bool> _trySendReading({
    required http.Client client,
    required String email,
    required int systolic,
    required int diastolic,
    required int heartRate,
    required DateTime readingDate,
  }) async {
    try {
      // ---- Step 1: Get auth token from secure storage ----
      final token = await storage.read(key: 'auth_token');
      dev.log("_trySendReading: auth_token=${token != null ? 'present' : 'NULL'}");
      if (token == null) {
        dev.log("No auth token available — user must log in first");
        return false;
      }

      // ---- Step 2: Submit reading ----
      final readingPayload = {
        "systolic": systolic,
        "diastolic": diastolic,
        "heartRate": heartRate,
        "readingDate": readingDate.toIso8601String(),
      };
      dev.log("Reading Request: $readingPayload");

      try {
        final readingUri = Uri.parse("$baseUrl/consumer/readings");
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
        dev.log("Reading upload took ${stopwatch.elapsedMilliseconds} ms");

        dev.log("Reading upload response: ${resp.statusCode}");
        if (resp.statusCode == 200 || resp.statusCode == 201) {
          dev.log("Reading uploaded successfully!");
          return true;
        } else {
          dev.log("Upload failed: status ${resp.statusCode}");
          return false;
        }
      } on SocketException catch (e) {
        dev.log("Network error during reading upload: $e");
        return false;
      } on TimeoutException {
        dev.log("Reading upload timed out!");
        return false;
      } catch (e, st) {
        dev.log("Unexpected reading upload error: $e\n$st");
        return false;
      }
    } catch (e) {
      dev.log("Error in _trySendReading: $e");
      return false;
    }
  }
}
