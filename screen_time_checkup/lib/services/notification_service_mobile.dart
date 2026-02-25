import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'notification_service_interface.dart';

class NotificationServiceImpl implements NotificationServiceInterface {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const int _checkInAlarmId = 0;
  static const int _notificationId = 1;
  static const int _scheduledAlarmIdBase = 100; // IDs 100-199 for scheduled times
  static List<String> _scheduledTimes = [];

  static void Function()? _onTapCallback;
  static (String, String) Function()? _messagePicker;
  static String _currentTitle = 'Time to check in!';
  static String _currentBody = 'What are you doing right now?';

  static const String _channelId = 'screen_time_checkup';
  static const String _channelName = 'Screen Time Checkup';
  static const String _channelDescription = 'Periodic check-in reminders';

  @override
  Future<void> initialize() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    await AndroidAlarmManager.initialize();
  }

  @override
  Future<bool> requestPermissions() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  @override
  Future<void> scheduleCheckIn(int intervalMinutes) async {
    await cancelCheckIn();

    await AndroidAlarmManager.periodic(
      Duration(minutes: intervalMinutes),
      _checkInAlarmId,
      _alarmCallback,
      exact: true,
      wakeup: false,
      rescheduleOnReboot: true,
    );
  }

  @override
  Future<void> cancelCheckIn() async {
    await AndroidAlarmManager.cancel(_checkInAlarmId);
  }

  @pragma('vm:entry-point')
  static Future<void> _alarmCallback() async {
    await _showCheckInNotification();
  }

  @override
  void setMessagePicker((String, String) Function() picker) {
    _messagePicker = picker;
    // Pre-select a message now so the static callback has something to use.
    final selected = picker();
    _currentTitle = selected.$1;
    _currentBody = selected.$2;
  }

  static Future<void> _showCheckInNotification() async {
    // Refresh message selection if picker is available (main isolate only).
    if (_messagePicker != null) {
      final selected = _messagePicker!();
      _currentTitle = selected.$1;
      _currentBody = selected.$2;
    }

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      ticker: _currentTitle,
    );

    final details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      id: _notificationId,
      title: _currentTitle,
      body: _currentBody,
      notificationDetails: details,
    );
  }

  static void _onNotificationTapped(NotificationResponse response) {
    _onTapCallback?.call();
  }

  @override
  Future<void> showTestNotification() async {
    await _showCheckInNotification();
  }

  @override
  void setOnNotificationTap(void Function() callback) {
    _onTapCallback = callback;
  }

  @override
  Future<void> scheduleAtTimes(List<String> times) async {
    await cancelScheduledTimes();
    _scheduledTimes = List.from(times);

    for (int i = 0; i < _scheduledTimes.length && i < 100; i++) {
      final timeStr = _scheduledTimes[i];
      final parts = timeStr.split(':');
      if (parts.length != 2) continue;

      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) continue;

      // Calculate next occurrence of this time
      final now = DateTime.now();
      var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);

      // If time already passed today, schedule for tomorrow
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      await AndroidAlarmManager.periodic(
        const Duration(days: 1),
        _scheduledAlarmIdBase + i,
        _alarmCallback,
        startAt: scheduledDate,
        exact: true,
        wakeup: false,
        rescheduleOnReboot: true,
      );
    }
  }

  @override
  Future<void> cancelScheduledTimes() async {
    // Cancel all possible scheduled time alarms
    for (int i = 0; i < 100; i++) {
      await AndroidAlarmManager.cancel(_scheduledAlarmIdBase + i);
    }
    _scheduledTimes = [];
  }

  @override
  Future<void> snoozeCheckIn(Duration delay) async {
    await AndroidAlarmManager.cancel(_checkInAlarmId);
    await AndroidAlarmManager.oneShot(
      delay,
      _checkInAlarmId,
      _alarmCallback,
      exact: true,
      wakeup: false,
    );
  }
}

NotificationServiceInterface createNotificationService() =>
    NotificationServiceImpl();
