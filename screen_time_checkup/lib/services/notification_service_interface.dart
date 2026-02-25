abstract class NotificationServiceInterface {
  Future<void> initialize();
  Future<bool> requestPermissions();
  Future<void> scheduleCheckIn(int intervalMinutes);
  Future<void> cancelCheckIn();
  Future<void> showTestNotification();
  void setOnNotificationTap(void Function() callback);
  /// Schedule notifications at specific times of day (HH:mm format)
  Future<void> scheduleAtTimes(List<String> times);
  /// Cancel all scheduled time-based notifications
  Future<void> cancelScheduledTimes();
  /// Pause interval notifications for [delay], then resume.
  Future<void> snoozeCheckIn(Duration delay);
  /// Provide a callback that returns (title, body) for the next notification.
  /// Called each time a notification is about to fire.
  void setMessagePicker((String, String) Function() picker);
}
