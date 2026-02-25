import 'package:screen_time_checkup/models/app_settings.dart';
import 'package:screen_time_checkup/models/log_entry.dart';
import 'package:screen_time_checkup/services/storage_service_interface.dart';

/// In-memory storage implementation for testing without platform dependencies.
class InMemoryStorageService implements StorageServiceInterface {
  AppSettings _settings = AppSettings();
  List<LogEntry> _logs = [];

  /// Counter to track how many times loadLogs is called (for verifying cache behavior).
  int loadLogsCallCount = 0;

  /// Counter to track how many times saveLogs is called.
  int saveLogsCallCount = 0;

  /// Counter to track how many times addLog is called.
  int addLogCallCount = 0;

  @override
  Future<AppSettings> loadSettings() async {
    return _settings;
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    _settings = settings;
  }

  @override
  Future<List<LogEntry>> loadLogs() async {
    loadLogsCallCount++;
    return List.from(_logs);
  }

  @override
  Future<void> saveLogs(List<LogEntry> logs) async {
    saveLogsCallCount++;
    _logs = List.from(logs);
  }

  @override
  Future<void> addLog(LogEntry log) async {
    addLogCallCount++;
    _logs.add(log);
  }

  @override
  Future<void> clearLogs() async {
    _logs.clear();
  }

  DateTime? _notificationTapTime;

  @override
  Future<void> saveNotificationTapTime(DateTime time) async {
    _notificationTapTime = time;
  }

  @override
  Future<DateTime?> loadNotificationTapTime() async {
    return _notificationTapTime;
  }

  @override
  Future<void> clearNotificationTapTime() async {
    _notificationTapTime = null;
  }

  /// Reset counters for a fresh test.
  void resetCounters() {
    loadLogsCallCount = 0;
    saveLogsCallCount = 0;
    addLogCallCount = 0;
  }

  /// Direct access to logs for test assertions.
  List<LogEntry> get logs => List.from(_logs);

  /// Direct access to settings for test assertions.
  AppSettings get settings => _settings;
}
