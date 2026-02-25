import '../models/app_settings.dart';
import '../models/log_entry.dart';

class StorageException implements Exception {
  final String message;
  StorageException(this.message);

  @override
  String toString() => message;
}

abstract class StorageServiceInterface {
  Future<AppSettings> loadSettings();
  Future<void> saveSettings(AppSettings settings);
  Future<List<LogEntry>> loadLogs();
  Future<void> saveLogs(List<LogEntry> logs);
  Future<void> addLog(LogEntry log);
  Future<void> clearLogs();
  Future<void> saveNotificationTapTime(DateTime time);
  Future<DateTime?> loadNotificationTapTime();
  Future<void> clearNotificationTapTime();
}
