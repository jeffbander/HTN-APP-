import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:developer' as dev;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'env.dart';

// Conditional imports for platform-specific HTTP client
import 'http_client_stub.dart'
    if (dart.library.io) 'http_client_io.dart' as platform_http;

/// Result class for API responses with structured error handling
class ApiResult {
  final int statusCode;
  final dynamic data;
  final String? error;
  final String? errorType;

  ApiResult({
    required this.statusCode,
    this.data,
    this.error,
    this.errorType,
  });

  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  /// Human-readable error message for display
  String get displayError {
    if (error != null) return error!;
    switch (statusCode) {
      case 400:
        return 'Invalid information provided. Please check your entries.';
      case 401:
        return 'Session expired. Please log in again.';
      case 403:
        return 'Your account is pending approval or has been deactivated.';
      case 404:
        return 'Account not found.';
      case 409:
        return 'An account with this email already exists.';
      case 500:
        return 'Server error. Please try again later.';
      case 0:
        return 'Unable to connect. Please check your internet connection.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}

class FlaskRegUsr {
  final storage = const FlutterSecureStorage();
  static const Duration _timeout = Duration(seconds: 10);

  String get baseUrl => Environment.baseUrl;

  /// HTTP client for union fetch — SSL bypass only in debug builds.
  http.Client get _unionClient {
    if (kDebugMode && !kIsWeb) {
      return platform_http.createHttpClient(
        skipCertificateValidation: true,
        timeout: _timeout,
      );
    } else {
      return http.Client();
    }
  }

  /// HTTP client for registration — SSL bypass only in debug builds.
  http.Client get _secureClient {
    if (kDebugMode && !kIsWeb) {
      return platform_http.createHttpClient(
        skipCertificateValidation: true,
        timeout: _timeout,
      );
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

  /// Fetches unions from backend (skips SSL)
  Future<Map<int, String>> fetchUnions() async {
    final client = _unionClient;
    try {
      final uri = Uri.parse("$baseUrl/consumer/unions");
      dev.log("Fetching unions from $uri");

      final resp = await client.get(uri);
      dev.log("Response status: ${resp.statusCode}");
      dev.log("Response body: ${resp.body}");

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final unionsMap = data.map((key, value) => MapEntry(int.parse(key), value as String));
        dev.log("unions fetched in flaskUsr: ${unionsMap.toString()}");
        return unionsMap;
      } else {
        dev.log("Failed to fetch unions: ${resp.statusCode}");
        return {};
      }
    } catch (e, stack) {
      dev.log("Error fetching unions: $e\n$stack");
      return {};
    } finally {
      client.close();
    }
  }


  /// Login user by email (passwordless). Returns status code and data.
  Future<Map<String, dynamic>> loginUser(String email) async {
    final client = _unionClient;
    try {
      final payload = jsonEncode({"email": email.trim()});
      final uri = Uri.parse("$baseUrl/consumer/login");
      dev.log("Sending login request to $uri");

      final resp = await client.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: payload,
      );

      dev.log("Login response status: ${resp.statusCode}");
      dev.log("Login response body: ${resp.body}");

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);

        // MFA required — return session info instead of token
        if (data['mfa_required'] == true) {
          return {
            'status': 200,
            'mfa_required': true,
            'mfa_type': data['mfa_type'],
            'mfa_session_token': data['mfa_session_token'],
            'user_status': data['user_status'],
          };
        }

        // MFA setup required (admin users) — not supported in mobile app
        if (data['mfa_setup_required'] == true) {
          return {
            'status': 403,
            'error': 'MFA setup is required. Please use the admin dashboard to set up MFA.',
          };
        }

        return {
          'status': 200,
          'token': data['singleUseToken'],
          'userId': data['userId'],
          'user_status': data['user_status'],
        };
      } else {
        final data = jsonDecode(resp.body);
        return {
          'status': resp.statusCode,
          'error': data['error'] ?? 'Login failed',
          'user_status': data['user_status'],
        };
      }
    } catch (e, stack) {
      dev.log("Error during login: $e\n$stack");
      return {'status': 0, 'error': 'Connection error'};
    } finally {
      client.close();
    }
  }

  /// Verify MFA code and get JWT token.
  Future<Map<String, dynamic>> verifyMfa(String mfaSessionToken, String code) async {
    final client = _unionClient;
    try {
      final payload = jsonEncode({
        'mfa_session_token': mfaSessionToken,
        'code': code.trim(),
      });
      final uri = Uri.parse("$baseUrl/consumer/verify-mfa");
      dev.log("Sending MFA verification to $uri");

      final resp = await client.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: payload,
      );

      dev.log("MFA verify response status: ${resp.statusCode}");

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return {
          'status': 200,
          'token': data['singleUseToken'],
          'userId': data['userId'],
          'user_status': data['user_status'],
        };
      } else {
        final data = jsonDecode(resp.body);
        return {
          'status': resp.statusCode,
          'error': data['error'] ?? 'Verification failed',
        };
      }
    } catch (e, stack) {
      dev.log("Error during MFA verification: $e\n$stack");
      return {'status': 0, 'error': 'Connection error'};
    } finally {
      client.close();
    }
  }

  /// Resend MFA email OTP code.
  Future<Map<String, dynamic>> resendMfaCode(String mfaSessionToken) async {
    final client = _unionClient;
    try {
      final payload = jsonEncode({'mfa_session_token': mfaSessionToken});
      final uri = Uri.parse("$baseUrl/consumer/resend-mfa-code");
      dev.log("Resending MFA code");

      final resp = await client.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: payload,
      );

      dev.log("Resend MFA response status: ${resp.statusCode}");

      if (resp.statusCode == 200) {
        return {'status': 200, 'message': 'Code resent'};
      } else {
        final data = jsonDecode(resp.body);
        return {
          'status': resp.statusCode,
          'error': data['error'] ?? 'Failed to resend code',
        };
      }
    } catch (e, stack) {
      dev.log("Error resending MFA code: $e\n$stack");
      return {'status': 0, 'error': 'Connection error'};
    } finally {
      client.close();
    }
  }

  /// Fetches the authenticated user's blood pressure readings from the backend.
  Future<List<Map<String, dynamic>>?> getReadings(String token) async {
    final client = _unionClient;
    try {
      final uri = Uri.parse("$baseUrl/consumer/readings");
      dev.log("Fetching readings from $uri");

      final resp = await client.get(
        uri,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      dev.log("Readings response status: ${resp.statusCode}");

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as List;
        return data.cast<Map<String, dynamic>>();
      } else {
        dev.log("Failed to fetch readings: ${resp.statusCode} ${resp.body}");
        return null;
      }
    } catch (e, stack) {
      dev.log("Error fetching readings: $e\n$stack");
      return null;
    } finally {
      client.close();
    }
  }

  /// Fetches the authenticated user's profile.
  Future<Map<String, dynamic>?> getProfile(String token) async {
    final client = _unionClient;
    try {
      final uri = Uri.parse("$baseUrl/consumer/profile");
      dev.log("Fetching profile from $uri");

      final resp = await client.get(
        uri,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      dev.log("Profile response status: ${resp.statusCode}");

      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      } else {
        dev.log("Failed to fetch profile: ${resp.statusCode} ${resp.body}");
        return null;
      }
    } catch (e, stack) {
      dev.log("Error fetching profile: $e\n$stack");
      return null;
    } finally {
      client.close();
    }
  }

  /// Updates lifestyle data for the authenticated user.
  Future<Map<String, dynamic>> updateLifestyleData(
    String token, {
    int? exerciseDaysPerWeek,
    int? exerciseMinutesPerSession,
    Map<String, String>? foodFrequency,
    String? financialStress,
    String? stressLevel,
    String? loneliness,
    int? sleepQuality,
  }) async {
    final client = _secureClient;
    try {
      final Map<String, dynamic> body = {};

      if (exerciseDaysPerWeek != null) body['exercise_days_per_week'] = exerciseDaysPerWeek;
      if (exerciseMinutesPerSession != null) body['exercise_minutes_per_session'] = exerciseMinutesPerSession;
      if (foodFrequency != null) body['food_frequency'] = foodFrequency;
      if (financialStress != null) body['financial_stress'] = financialStress;
      if (stressLevel != null) body['stress_level'] = stressLevel;
      if (loneliness != null) body['loneliness'] = loneliness;
      if (sleepQuality != null) body['sleep_quality'] = sleepQuality;

      final payload = jsonEncode(body);
      final uri = Uri.parse("$baseUrl/consumer/profile/lifestyle");
      dev.log("Updating lifestyle data: $payload");

      final resp = await client.put(
        uri,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: payload,
      );

      dev.log("Lifestyle update response status: ${resp.statusCode}");

      if (resp.statusCode == 200) {
        return {'status': 200, 'data': jsonDecode(resp.body)};
      } else {
        final data = jsonDecode(resp.body);
        return {'status': resp.statusCode, 'error': data['error'] ?? 'Update failed'};
      }
    } catch (e, stack) {
      dev.log("Error updating lifestyle data: $e\n$stack");
      return {'status': 0, 'error': 'Connection error'};
    } finally {
      client.close();
    }
  }

  /// Request a blood pressure cuff to be shipped.
  Future<Map<String, dynamic>> requestCuff(String token, String address) async {
    final client = _secureClient;
    try {
      final payload = jsonEncode({'address': address});
      final uri = Uri.parse("$baseUrl/consumer/cuff-request");
      dev.log("Requesting cuff with address");

      final resp = await client.post(
        uri,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: payload,
      );

      dev.log("Cuff request response status: ${resp.statusCode}");

      if (resp.statusCode == 201) {
        return {'status': 201, 'request': jsonDecode(resp.body)};
      } else if (resp.statusCode == 409) {
        final data = jsonDecode(resp.body);
        return {'status': 409, 'error': data['error'], 'existing_request': data['existing_request']};
      } else {
        final data = jsonDecode(resp.body);
        return {'status': resp.statusCode, 'error': data['error'] ?? 'Request failed'};
      }
    } catch (e, stack) {
      dev.log("Error requesting cuff: $e\n$stack");
      return {'status': 0, 'error': 'Connection error'};
    } finally {
      client.close();
    }
  }

  /// Get the status of the current cuff request.
  Future<Map<String, dynamic>> getCuffRequestStatus(String token) async {
    final client = _unionClient;
    try {
      final uri = Uri.parse("$baseUrl/consumer/cuff-request");
      dev.log("Fetching cuff request status");

      final resp = await client.get(
        uri,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      dev.log("Cuff status response: ${resp.statusCode}");

      if (resp.statusCode == 200) {
        return {'status': 200, ...jsonDecode(resp.body)};
      } else {
        final data = jsonDecode(resp.body);
        return {'status': resp.statusCode, 'error': data['error'] ?? 'Failed to get status'};
      }
    } catch (e, stack) {
      dev.log("Error getting cuff status: $e\n$stack");
      return {'status': 0, 'error': 'Connection error'};
    } finally {
      client.close();
    }
  }

  /// Register a device token for push notifications.
  Future<Map<String, dynamic>> registerDeviceToken(
    String token,
    String deviceToken, {
    String? platform,
    String? deviceModel,
    String? appVersion,
  }) async {
    final client = _secureClient;
    try {
      final Map<String, dynamic> body = {'token': deviceToken};
      if (platform != null) body['platform'] = platform;
      if (deviceModel != null) body['device_model'] = deviceModel;
      if (appVersion != null) body['app_version'] = appVersion;

      final payload = jsonEncode(body);
      final uri = Uri.parse("$baseUrl/consumer/device-token");
      dev.log("Registering device token");

      final resp = await client.post(
        uri,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: payload,
      );

      dev.log("Device token registration response: ${resp.statusCode}");

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        return {'status': resp.statusCode, ...jsonDecode(resp.body)};
      } else {
        final data = jsonDecode(resp.body);
        return {'status': resp.statusCode, 'error': data['error'] ?? 'Registration failed'};
      }
    } catch (e, stack) {
      dev.log("Error registering device token: $e\n$stack");
      return {'status': 0, 'error': 'Connection error'};
    } finally {
      client.close();
    }
  }

  /// Registers a user with all demographic and health fields.
  /// Returns ApiResult with structured error handling.
  Future<ApiResult> registerUserInfoWithResult(
      String name, String email, String birthday, int unionId,
      {String? bearerToken,
      String? gender,
      String? race,
      String? ethnicity,
      String? phone,
      String? address,
      String? workStatus,
      String? rank,
      int? heightFeet,
      int? heightInches,
      int? weight,
      List<String>? chronicConditions,
      bool? hasHighBloodPressure,
      String? medications,
      String? smokingStatus,
      bool? onBPMedication,
      int? missedDoses}) async {
    final client = _secureClient;
    try {
      final Map<String, dynamic> body = {
        "name": name,
        "email": email,
        "dob": _formatBirthday(birthday),
        "union_id": unionId,
      };

      // Add optional demographic fields
      if (gender != null) body["gender"] = gender;
      if (race != null) body["race"] = race;
      if (ethnicity != null) body["ethnicity"] = ethnicity;
      if (phone != null) body["phone"] = phone;
      if (address != null) body["address"] = address;
      if (workStatus != null) body["work_status"] = workStatus;
      if (rank != null) body["rank"] = rank;

      // Height: send total inches
      if (heightFeet != null) {
        body["height_inches"] = (heightFeet * 12) + (heightInches ?? 0);
      }
      if (weight != null) body["weight_lbs"] = weight;

      // Health fields
      if (chronicConditions != null) body["chronic_conditions"] = chronicConditions;
      if (hasHighBloodPressure != null) body["has_high_blood_pressure"] = hasHighBloodPressure;
      if (medications != null) body["medications"] = medications;
      if (smokingStatus != null) body["smoking_status"] = smokingStatus;
      if (onBPMedication != null) body["on_bp_medication"] = onBPMedication;
      if (missedDoses != null) body["missed_doses"] = missedDoses;

      final payload = jsonEncode(body);

      final headers = {
        "Content-Type": "application/json",
        if (bearerToken != null) "Authorization": "Bearer $bearerToken",
      };

      final uri = Uri.parse("$baseUrl/consumer/register");
      dev.log("[FlaskRegUsr] Sending registration to: $uri");
      dev.log("[FlaskRegUsr] Payload: $payload");

      final resp = await client.post(uri, headers: headers, body: payload).timeout(_timeout);

      dev.log("[FlaskRegUsr] Response status: ${resp.statusCode}");
      dev.log("[FlaskRegUsr] Response body: ${resp.body}");

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        final data = jsonDecode(resp.body);
        final token = data['singleUseToken'];
        if (token != null) {
          dev.log("[FlaskRegUsr] Registration successful, received token");
          return ApiResult(statusCode: resp.statusCode, data: {'token': token, 'userId': data['userId']});
        } else {
          dev.log("[FlaskRegUsr] Registration response missing token: $data");
          return ApiResult(statusCode: resp.statusCode, data: data);
        }
      } else {
        // Parse error message from response
        String? errorMsg;
        String? errorType;
        try {
          final errorData = jsonDecode(resp.body);
          errorMsg = errorData['error'] ?? errorData['message'];
          errorType = errorData['error_type'];
        } catch (_) {
          errorMsg = resp.body;
        }
        dev.log("[FlaskRegUsr] Registration failed: ${resp.statusCode} - $errorMsg");
        return ApiResult(
          statusCode: resp.statusCode,
          error: errorMsg,
          errorType: errorType,
        );
      }
    } on TimeoutException {
      dev.log("[FlaskRegUsr] Registration request timed out");
      return ApiResult(statusCode: 0, error: 'Connection timed out. Please try again.', errorType: 'timeout');
    } catch (e, stack) {
      dev.log("[FlaskRegUsr] Error registering user: $e\n$stack");
      // Check if it's a network-related error
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('socket') || errorStr.contains('connection') || errorStr.contains('network')) {
        return ApiResult(statusCode: 0, error: 'Unable to connect to server. Please check your connection.', errorType: 'network');
      }
      return ApiResult(statusCode: 0, error: 'An unexpected error occurred.', errorType: 'unknown');
    } finally {
      client.close();
    }
  }

  /// Updates editable profile fields (phone, address, medical history).
  Future<Map<String, dynamic>> updateProfile(
    String token, {
    String? phone,
    String? address,
    String? medicalHistory,
  }) async {
    final client = _secureClient;
    try {
      final Map<String, dynamic> body = {};
      if (phone != null) body['phone'] = phone;
      if (address != null) body['address'] = address;
      if (medicalHistory != null) body['medical_history'] = medicalHistory;

      final payload = jsonEncode(body);
      final uri = Uri.parse("$baseUrl/consumer/profile");
      dev.log("Updating profile: $payload");

      final resp = await client.put(
        uri,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: payload,
      );

      dev.log("Profile update response status: ${resp.statusCode}");

      if (resp.statusCode == 200) {
        return {'status': 200, 'data': jsonDecode(resp.body)};
      } else {
        final data = jsonDecode(resp.body);
        return {'status': resp.statusCode, 'error': data['error'] ?? 'Update failed'};
      }
    } catch (e, stack) {
      dev.log("Error updating profile: $e\n$stack");
      return {'status': 0, 'error': 'Connection error'};
    } finally {
      client.close();
    }
  }

  /// Legacy method - returns just the token or null
  /// @deprecated Use registerUserInfoWithResult for better error handling
  Future<String?> registerUserInfo(
      String name, String email, String birthday, int unionId,
      {String? bearerToken,
      String? gender,
      String? race,
      String? ethnicity,
      String? phone,
      String? address,
      String? workStatus,
      String? rank,
      int? heightFeet,
      int? heightInches,
      int? weight,
      List<String>? chronicConditions,
      bool? hasHighBloodPressure,
      String? medications,
      String? smokingStatus,
      bool? onBPMedication,
      int? missedDoses}) async {
    final result = await registerUserInfoWithResult(
      name, email, birthday, unionId,
      bearerToken: bearerToken,
      gender: gender,
      race: race,
      ethnicity: ethnicity,
      phone: phone,
      address: address,
      workStatus: workStatus,
      rank: rank,
      heightFeet: heightFeet,
      heightInches: heightInches,
      weight: weight,
      chronicConditions: chronicConditions,
      hasHighBloodPressure: hasHighBloodPressure,
      medications: medications,
      smokingStatus: smokingStatus,
      onBPMedication: onBPMedication,
      missedDoses: missedDoses,
    );
    if (result.isSuccess && result.data != null) {
      return result.data['token'];
    }
    return null;
  }
}
