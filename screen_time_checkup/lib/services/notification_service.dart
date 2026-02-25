import 'notification_service_interface.dart';
import 'notification_service_web.dart'
    if (dart.library.io) 'notification_service_mobile.dart';

class NotificationService implements NotificationServiceInterface {
  final NotificationServiceInterface _impl = createNotificationService();

  @override
  Future<void> initialize() => _impl.initialize();

  @override
  Future<bool> requestPermissions() => _impl.requestPermissions();

  @override
  Future<void> scheduleCheckIn(int intervalMinutes) =>
      _impl.scheduleCheckIn(intervalMinutes);

  @override
  Future<void> cancelCheckIn() => _impl.cancelCheckIn();

  @override
  Future<void> showTestNotification() => _impl.showTestNotification();

  @override
  void setOnNotificationTap(void Function() callback) =>
      _impl.setOnNotificationTap(callback);

  @override
  Future<void> scheduleAtTimes(List<String> times) =>
      _impl.scheduleAtTimes(times);

  @override
  Future<void> cancelScheduledTimes() => _impl.cancelScheduledTimes();

  @override
  Future<void> snoozeCheckIn(Duration delay) => _impl.snoozeCheckIn(delay);

  @override
  void setMessagePicker((String, String) Function() picker) =>
      _impl.setMessagePicker(picker);
}
