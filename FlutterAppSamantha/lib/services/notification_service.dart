import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:developer' as dev;

/// Service for managing push notifications
///
/// NOTE: Firebase is not configured. To enable push notifications:
/// 1. Run: flutterfire configure
/// 2. Uncomment firebase packages in pubspec.yaml
/// 3. Replace this stub with the full implementation
class NotificationService extends ChangeNotifier {
  static NotificationService? _instance;

  String? _fcmToken;
  bool _isInitialized = false;
  bool _hasPermission = false;

  String? get fcmToken => _fcmToken;
  bool get isInitialized => _isInitialized;
  bool get hasPermission => _hasPermission;

  // Stream controller for notification events
  final _notificationController = StreamController<NotificationEvent>.broadcast();
  Stream<NotificationEvent> get notificationStream => _notificationController.stream;

  NotificationService._();

  static NotificationService get instance {
    _instance ??= NotificationService._();
    return _instance!;
  }

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    dev.log('NotificationService: Firebase not configured - notifications disabled');
    dev.log('To enable notifications:');
    dev.log('  1. Run: flutterfire configure');
    dev.log('  2. Uncomment firebase packages in pubspec.yaml');
    dev.log('  3. Replace this stub with full implementation');

    _isInitialized = true;
    notifyListeners();
  }

  /// Manually refresh the token and register it
  Future<void> refreshToken() async {
    dev.log('NotificationService: refreshToken called but Firebase not configured');
  }

  /// Subscribe to a topic
  Future<void> subscribeToTopic(String topic) async {
    dev.log('NotificationService: subscribeToTopic called but Firebase not configured');
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    dev.log('NotificationService: unsubscribeFromTopic called but Firebase not configured');
  }

  @override
  void dispose() {
    _notificationController.close();
    super.dispose();
  }
}

/// Types of notification events
enum NotificationType {
  foreground,
  background,
  tap,
}

/// Event emitted when a notification is received or tapped
class NotificationEvent {
  final NotificationType type;
  final String? title;
  final String? body;
  final Map<String, dynamic> data;

  NotificationEvent({
    required this.type,
    this.title,
    this.body,
    this.data = const {},
  });
}
