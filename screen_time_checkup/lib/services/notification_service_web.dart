import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'notification_service_interface.dart';

class NotificationServiceImpl implements NotificationServiceInterface {
  Timer? _checkInTimer;
  int? _currentIntervalMinutes;
  void Function()? _onTapCallback;
  (String, String) Function()? _messagePicker;
  Timer? _scheduledTimer;
  Timer? _snoozeTimer;
  List<String> _scheduledTimes = [];
  String? _lastFiredTime;

  /// Tracks when any notification last fired so we can catch up after
  /// the tab is backgrounded (Chrome throttles/pauses timers when hidden).
  DateTime? _lastNotificationFiredAt;

  @override
  Future<void> initialize() async {
    // Listen for messages posted back from the service worker.
    // The SW sends {type: 'snooze', minutes: N} when a snooze action is tapped,
    // and {type: 'tap'} when the notification body itself is tapped.
    try {
      web.window.navigator.serviceWorker.addEventListener(
        'message',
        ((web.MessageEvent event) {
          final data = event.data.dartify();
          if (data is Map) {
            final type = data['type'] as String?;
            if (type == 'snooze') {
              final minutes = (data['minutes'] as num?)?.toInt() ?? 5;
              snoozeCheckIn(Duration(minutes: minutes));
            } else if (type == 'tap') {
              _onTapCallback?.call();
              web.window.focus();
            }
          }
        }).toJS,
      );
    } catch (e) {
      web.console.log('SW message listener not available: $e'.toJS);
    }

    web.document.addEventListener(
      'visibilitychange',
      ((web.Event event) {
        if (!web.document.hidden) {
          _handleVisibilityRestored();
        }
      }).toJS,
    );
  }

  /// Called when the tab becomes visible again.
  /// Fires any overdue interval notification immediately, then resumes the
  /// timer for only the remaining portion of the interval.
  /// Also catches up on any scheduled times that fired while the tab was hidden.
  void _handleVisibilityRestored() {
    // Catch up on scheduled times first.
    if (_scheduledTimes.isNotEmpty) {
      _checkScheduledTimes(catchUp: true);
    }

    // Catch up on the interval notification.
    if (_currentIntervalMinutes != null) {
      _checkInTimer?.cancel();
      final interval = Duration(minutes: _currentIntervalMinutes!);
      final now = DateTime.now();

      if (_lastNotificationFiredAt == null) {
        // No baseline yet — start a fresh periodic timer.
        _checkInTimer = Timer.periodic(interval, (_) => _showNotification());
        return;
      }

      final elapsed = now.difference(_lastNotificationFiredAt!);
      if (elapsed >= interval) {
        // Overdue — fire immediately, then run periodically.
        _showNotification();
        _checkInTimer = Timer.periodic(interval, (_) => _showNotification());
      } else {
        // Still within the interval — wait only for the remaining time,
        // then switch to a full periodic schedule.
        final remaining = interval - elapsed;
        _checkInTimer = Timer(remaining, () {
          _showNotification();
          _checkInTimer =
              Timer.periodic(interval, (_) => _showNotification());
        });
      }
    }
  }

  @override
  Future<bool> requestPermissions() async {
    try {
      web.console.log('Checking notification permission...'.toJS);

      final currentPermission = web.Notification.permission;
      web.console.log('Current permission: $currentPermission'.toJS);

      if (currentPermission == 'granted') return true;
      if (currentPermission == 'denied') return false;

      final permission = await web.Notification.requestPermission().toDart
          .timeout(const Duration(seconds: 30), onTimeout: () {
        web.console.warn('Notification permission request timed out'.toJS);
        return 'denied'.toJS;
      });
      web.console.log('Permission result: ${permission.toDart}'.toJS);
      return permission.toDart == 'granted';
    } catch (e) {
      web.console.error('Error requesting notification permission: $e'.toJS);
      return false;
    }
  }

  @override
  Future<void> scheduleCheckIn(int intervalMinutes) async {
    await cancelCheckIn();

    try {
      final permission = web.Notification.permission;
      if (permission != 'granted') {
        web.console
            .log('Notifications not scheduled - permission: $permission'.toJS);
        return;
      }
    } catch (e) {
      web.console.log('Error checking notification permission: $e'.toJS);
      return;
    }

    _currentIntervalMinutes = intervalMinutes;
    _lastNotificationFiredAt = DateTime.now(); // baseline for catch-up logic

    _checkInTimer = Timer.periodic(
      Duration(minutes: intervalMinutes),
      (_) => _showNotification(),
    );
    web.console.log('Notifications scheduled every $intervalMinutes minutes'.toJS);
  }

  @override
  Future<void> cancelCheckIn() async {
    _checkInTimer?.cancel();
    _checkInTimer = null;
    _currentIntervalMinutes = null;
  }

  @override
  void setMessagePicker((String, String) Function() picker) {
    _messagePicker = picker;
  }

  Future<void> _showNotification() async {
    _lastNotificationFiredAt = DateTime.now();
    if (web.Notification.permission != 'granted') {
      web.console.warn(
          'Notification permission not granted: ${web.Notification.permission}'
              .toJS);
      return;
    }

    final (title, body) = _messagePicker?.call() ??
        ('Time to check in!', 'What are you doing right now?');

    // Use serviceWorker.ready (not .controller) so this works even on the
    // very first page load, before the SW has claimed the client.
    // On Android, new Notification() from a page context is not allowed —
    // registration.showNotification() via SW is required.
    try {
      final reg = await web.window.navigator.serviceWorker.ready.toDart;
      final active = reg.active;
      if (active != null) {
        active.postMessage(
          <String, String>{
            'type': 'showNotification',
            'title': title,
            'body': body,
          }.jsify(),
        );
        web.console.log('Notification sent via service worker'.toJS);
        return;
      }
    } catch (e) {
      web.console.log('SW not available, using fallback notification: $e'.toJS);
    }

    _showFallbackNotification(title, body);
  }

  /// Plain notification without action buttons — used when the SW is not yet
  /// controlling the page (e.g. very first load before SW activates).
  void _showFallbackNotification(String title, String body) {
    final options = web.NotificationOptions(
      body: body,
      icon: 'icons/Icon-192.png',
      requireInteraction: true,
    );
    final notification = web.Notification(title, options);
    web.console.log('Fallback notification created'.toJS);

    notification.addEventListener(
      'click',
      ((web.Event event) {
        _onTapCallback?.call();
        web.window.focus();
        notification.close();
      }).toJS,
    );

    notification.addEventListener(
      'error',
      ((web.Event event) {
        web.console.error('Notification error occurred'.toJS);
      }).toJS,
    );
  }

  @override
  Future<void> showTestNotification() async {
    if (web.Notification.permission != 'granted') {
      final granted = await requestPermissions();
      if (!granted) return;
    }
    _showNotification();
  }

  @override
  void setOnNotificationTap(void Function() callback) {
    _onTapCallback = callback;
  }

  @override
  Future<void> scheduleAtTimes(List<String> times) async {
    await cancelScheduledTimes();
    _scheduledTimes = List.from(times);

    if (_scheduledTimes.isEmpty) return;

    if (web.Notification.permission != 'granted') {
      web.console
          .log('Scheduled times not set - permission not granted'.toJS);
      return;
    }

    _scheduledTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _checkScheduledTimes(),
    );

    _checkScheduledTimes();
    web.console
        .log('Scheduled ${_scheduledTimes.length} time-based reminders'.toJS);
  }

  /// [catchUp] mode: fire at most one notification for a scheduled time that
  /// was missed within the last 5 minutes (e.g. while the tab was hidden).
  void _checkScheduledTimes({bool catchUp = false}) {
    final now = DateTime.now();

    if (catchUp) {
      for (final time in _scheduledTimes) {
        final parts = time.split(':');
        if (parts.length != 2) continue;
        final h = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (h == null || m == null) continue;
        final scheduled = DateTime(now.year, now.month, now.day, h, m);
        final diff = now.difference(scheduled);
        // Missed within last 5 minutes and not the one we already fired.
        if (diff.inSeconds >= 0 && diff.inMinutes < 5 &&
            _lastFiredTime != time) {
          _lastFiredTime = time;
          _showNotification();
          return; // fire at most one catch-up notification per restore
        }
      }
      return;
    }

    // Normal 1-minute tick.
    final currentTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    if (_lastFiredTime == currentTime) return;
    if (_scheduledTimes.contains(currentTime)) {
      _lastFiredTime = currentTime;
      _showNotification();
    }
  }

  @override
  Future<void> cancelScheduledTimes() async {
    _scheduledTimer?.cancel();
    _scheduledTimer = null;
    _scheduledTimes = [];
    _lastFiredTime = null;
  }

  @override
  Future<void> snoozeCheckIn(Duration delay) async {
    _checkInTimer?.cancel();
    _checkInTimer = null;
    _snoozeTimer?.cancel();
    _snoozeTimer = Timer(delay, () {
      _snoozeTimer = null;
      _showNotification();
      if (_currentIntervalMinutes != null) {
        _checkInTimer = Timer.periodic(
          Duration(minutes: _currentIntervalMinutes!),
          (_) => _showNotification(),
        );
      }
    });
  }
}

NotificationServiceInterface createNotificationService() =>
    NotificationServiceImpl();
