import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:developer' as dev;

/// Service wrapping flutter_local_notifications for scheduling BP reading reminders.
class LocalNotificationService {
  LocalNotificationService._();
  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(_resolveTimeZone()));

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings);
    _initialized = true;
    dev.log('[LocalNotificationService] Initialized');
  }

  /// Request notification permissions (iOS).
  Future<bool> requestPermission() async {
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    // Android permissions are granted by default on most versions
    return true;
  }

  /// Schedule a daily notification at the given hour/minute.
  /// Uses a stable [id] so updates replace the previous schedule.
  Future<void> scheduleDaily({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
    List<int>? daysOfWeek,
  }) async {
    if (!_initialized) return;

    const androidDetails = AndroidNotificationDetails(
      'bp_reminders',
      'BP Reading Reminders',
      channelDescription: 'Reminders to take your blood pressure reading',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    if (daysOfWeek != null && daysOfWeek.isNotEmpty) {
      // Schedule for specific days of the week
      for (final day in daysOfWeek) {
        final scheduledDate = _nextInstanceOfDayTime(day, hour, minute);
        await _plugin.zonedSchedule(
          id * 10 + day, // Unique ID per day
          title,
          body,
          scheduledDate,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
    } else {
      // Schedule daily
      final scheduledDate = _nextInstanceOfTime(hour, minute);
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }

    dev.log('[LocalNotificationService] Scheduled notification id=$id at $hour:$minute');
  }

  /// Cancel a specific notification by id.
  Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }

  /// Cancel all scheduled notifications.
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
    dev.log('[LocalNotificationService] All notifications cancelled');
  }

  /// Get pending notification requests.
  Future<List<PendingNotificationRequest>> getScheduled() async {
    return await _plugin.pendingNotificationRequests();
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  tz.TZDateTime _nextInstanceOfDayTime(int dayOfWeek, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    // dayOfWeek: 0=Sunday..6=Saturday, DateTime.weekday: 1=Monday..7=Sunday
    final targetWeekday = dayOfWeek == 0 ? 7 : dayOfWeek;

    while (scheduled.weekday != targetWeekday || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  String _resolveTimeZone() {
    try {
      final offset = DateTime.now().timeZoneOffset;
      // Use a common US timezone as fallback
      if (offset.inHours == -5) return 'America/New_York';
      if (offset.inHours == -6) return 'America/Chicago';
      if (offset.inHours == -7) return 'America/Denver';
      if (offset.inHours == -8) return 'America/Los_Angeles';
      return 'America/New_York'; // Default fallback
    } catch (_) {
      return 'America/New_York';
    }
  }
}
