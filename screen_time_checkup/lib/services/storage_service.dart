import '../models/app_settings.dart';
import '../models/log_entry.dart';
import 'storage_service_interface.dart';
import 'storage_service_web.dart'
    if (dart.library.io) 'storage_service_mobile.dart';

class StorageService implements StorageServiceInterface {
  final StorageServiceInterface _impl = createStorageService();

  @override
  Future<AppSettings> loadSettings() => _impl.loadSettings();

  @override
  Future<void> saveSettings(AppSettings settings) =>
      _impl.saveSettings(settings);

  @override
  Future<List<LogEntry>> loadLogs() => _impl.loadLogs();

  @override
  Future<void> saveLogs(List<LogEntry> logs) => _impl.saveLogs(logs);

  @override
  Future<void> addLog(LogEntry log) => _impl.addLog(log);

  @override
  Future<void> clearLogs() => _impl.clearLogs();

  @override
  Future<void> saveNotificationTapTime(DateTime time) =>
      _impl.saveNotificationTapTime(time);

  @override
  Future<DateTime?> loadNotificationTapTime() =>
      _impl.loadNotificationTapTime();

  @override
  Future<void> clearNotificationTapTime() =>
      _impl.clearNotificationTapTime();
}
