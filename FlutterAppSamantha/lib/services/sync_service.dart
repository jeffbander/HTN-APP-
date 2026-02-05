import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:developer' as dev;
import 'offline_queue_service.dart';
import '../env.dart';
import 'http_client_helper.dart';

/// Service for synchronizing offline queue with the backend
class SyncService extends ChangeNotifier {
  static SyncService? _instance;

  final OfflineQueueService _queue = OfflineQueueService.instance;
  final _storage = const FlutterSecureStorage();
  final Connectivity _connectivity = Connectivity();

  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  Timer? _syncTimer;

  bool _isSyncing = false;
  bool _isConnected = true;
  int _pendingCount = 0;
  int _failedCount = 0;
  String? _lastSyncError;
  DateTime? _lastSyncTime;

  bool get isSyncing => _isSyncing;
  bool get isConnected => _isConnected;
  int get pendingCount => _pendingCount;
  int get failedCount => _failedCount;
  String? get lastSyncError => _lastSyncError;
  DateTime? get lastSyncTime => _lastSyncTime;

  String get baseUrl => Environment.baseUrl;

  SyncService._();

  static SyncService get instance {
    _instance ??= SyncService._();
    return _instance!;
  }

  /// HTTP client appropriate for current platform
  http.Client get _httpClient => createHttpClient();

  /// Initialize the sync service
  Future<void> initialize() async {
    dev.log('Initializing SyncService');

    // Skip on web - sqflite doesn't work on web
    if (kIsWeb) {
      dev.log('SyncService: Skipping initialization on web (sqflite not supported)');
      _isConnected = true;
      notifyListeners();
      return;
    }

    // Check initial connectivity
    final result = await _connectivity.checkConnectivity();
    _isConnected = result != ConnectivityResult.none;

    // Listen for connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);

    // Update pending count
    await _updateCounts();

    // Start periodic sync timer (every 5 minutes)
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) => syncPendingReadings());

    // If connected, sync immediately
    if (_isConnected) {
      syncPendingReadings();
    }

    notifyListeners();
  }

  void _onConnectivityChanged(ConnectivityResult result) {
    final wasConnected = _isConnected;
    _isConnected = result != ConnectivityResult.none;

    dev.log('Connectivity changed: $_isConnected (was: $wasConnected)');

    // If we just got connected, trigger sync
    if (!wasConnected && _isConnected) {
      dev.log('Network restored, starting sync...');
      syncPendingReadings();
    }

    notifyListeners();
  }

  Future<void> _updateCounts() async {
    if (kIsWeb) return;
    _pendingCount = await _queue.getPendingCount();
    final failed = await _queue.getFailedReadings();
    _failedCount = failed.length;
    notifyListeners();
  }

  /// Queue a reading for offline sync
  Future<void> queueReading({
    required int systolic,
    required int diastolic,
    required int heartRate,
    required DateTime readingDate,
    required String deviceId,
    required String userEmail,
  }) async {
    if (kIsWeb) {
      dev.log('SyncService: Cannot queue readings on web');
      return;
    }
    await _queue.queueReading(
      systolic: systolic,
      diastolic: diastolic,
      heartRate: heartRate,
      readingDate: readingDate,
      deviceId: deviceId,
      userEmail: userEmail,
    );

    await _updateCounts();

    // If connected, try to sync immediately
    if (_isConnected && !_isSyncing) {
      syncPendingReadings();
    }
  }

  /// Sync all pending readings to the backend
  Future<SyncResult> syncPendingReadings() async {
    if (kIsWeb) {
      return SyncResult(synced: 0, failed: 0, skipped: 0);
    }

    if (_isSyncing) {
      dev.log('Sync already in progress, skipping');
      return SyncResult(synced: 0, failed: 0, skipped: 0);
    }

    if (!_isConnected) {
      dev.log('No network connection, skipping sync');
      return SyncResult(synced: 0, failed: 0, skipped: 0);
    }

    _isSyncing = true;
    _lastSyncError = null;
    notifyListeners();

    int synced = 0;
    int failed = 0;
    int skipped = 0;

    try {
      final pending = await _queue.getPendingReadings();
      dev.log('Starting sync of ${pending.length} pending readings');

      if (pending.isEmpty) {
        dev.log('No pending readings to sync');
        return SyncResult(synced: 0, failed: 0, skipped: 0);
      }

      // Group readings by user email for efficient token reuse
      final byUser = <String, List<QueuedReading>>{};
      for (final reading in pending) {
        byUser.putIfAbsent(reading.userEmail, () => []).add(reading);
      }

      for (final entry in byUser.entries) {
        final email = entry.key;
        final readings = entry.value;

        // Get auth token for this user
        final token = await _getAuthToken(email);
        if (token == null) {
          dev.log('Could not get token for $email, skipping ${readings.length} readings');
          skipped += readings.length;
          continue;
        }

        // Sync each reading
        for (final reading in readings) {
          final success = await _syncSingleReading(reading, token);
          if (success) {
            synced++;
          } else {
            failed++;
          }
        }
      }

      _lastSyncTime = DateTime.now();
      dev.log('Sync complete: $synced synced, $failed failed, $skipped skipped');

    } catch (e, stack) {
      _lastSyncError = e.toString();
      dev.log('Sync error: $e\n$stack');
    } finally {
      _isSyncing = false;
      await _updateCounts();
      notifyListeners();
    }

    return SyncResult(synced: synced, failed: failed, skipped: skipped);
  }

  Future<String?> _getAuthToken(String email) async {
    // Use the stored auth token from login/MFA verification
    // instead of calling /consumer/login (which now requires email OTP)
    final token = await _storage.read(key: 'auth_token');
    if (token == null) {
      dev.log('No auth token available for $email — user must log in first');
    }
    return token;
  }

  Future<bool> _syncSingleReading(QueuedReading reading, String token) async {
    final client = _httpClient;

    try {
      final payload = jsonEncode({
        "systolic": reading.systolic,
        "diastolic": reading.diastolic,
        "heartRate": reading.heartRate,
        "readingDate": reading.readingDate.toIso8601String(),
      });

      final uri = Uri.parse("$baseUrl/consumer/readings");

      final resp = await client.post(
        uri,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: payload,
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        await _queue.markSynced(reading.id!);
        dev.log('Synced reading ID ${reading.id}');
        return true;
      } else {
        await _queue.markFailed(reading.id!, 'HTTP ${resp.statusCode}: ${resp.body}');
        dev.log('Failed to sync reading ID ${reading.id}: ${resp.statusCode}');
        return false;
      }
    } on TimeoutException {
      await _queue.markFailed(reading.id!, 'Request timed out');
      return false;
    } catch (e) {
      await _queue.markFailed(reading.id!, e.toString());
      return false;
    } finally {
      client.close();
    }
  }

  /// Retry failed readings
  Future<void> retryFailedReadings() async {
    if (kIsWeb) return;
    final failed = await _queue.getFailedReadings();
    for (final reading in failed) {
      await _queue.resetRetryCount(reading.id!);
    }
    await _updateCounts();
    syncPendingReadings();
  }

  /// Clear all pending readings
  Future<void> clearQueue() async {
    if (kIsWeb) return;
    await _queue.clearQueue();
    await _updateCounts();
  }

  /// Dispose resources
  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _syncTimer?.cancel();
    super.dispose();
  }
}

/// Result of a sync operation
class SyncResult {
  final int synced;
  final int failed;
  final int skipped;

  SyncResult({
    required this.synced,
    required this.failed,
    required this.skipped,
  });

  int get total => synced + failed + skipped;
  bool get hasFailures => failed > 0;
  bool get isComplete => synced > 0 && failed == 0 && skipped == 0;
}
