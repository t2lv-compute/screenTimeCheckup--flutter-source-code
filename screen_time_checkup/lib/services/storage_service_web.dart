import 'dart:convert';
import 'package:web/web.dart' as web;
import '../models/app_settings.dart';
import '../models/log_entry.dart';
import 'storage_service_interface.dart';
import 'logger_service.dart';

class StorageServiceImpl implements StorageServiceInterface {
  static const String _settingsKey = 'screen_time_settings';
  static const String _logsKey = 'screen_time_logs';
  static const String _notificationTapKey = 'screen_time_notification_tap';
  final _logger = LoggerService();

  // In-memory cache for logs
  List<LogEntry>? _logsCache;
  bool _cacheValid = false;

  web.Storage get _localStorage => web.window.localStorage;

  @override
  Future<AppSettings> loadSettings() async {
    try {
      final data = _localStorage.getItem(_settingsKey);
      if (data == null) {
        _logger.debug('No settings found, using defaults', 'StorageWeb');
        return AppSettings();
      }
      final json = jsonDecode(data) as Map<String, dynamic>;
      _logger.debug('Settings loaded successfully', 'StorageWeb');
      return AppSettings.fromJson(json);
    } catch (e, stack) {
      _logger.error('Failed to load settings', e, stack, 'StorageWeb');
      return AppSettings();
    }
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    try {
      final json = jsonEncode(settings.toJson());
      _localStorage.setItem(_settingsKey, json);
      _logger.debug('Settings saved successfully', 'StorageWeb');
    } catch (e, stack) {
      _logger.error('Failed to save settings', e, stack, 'StorageWeb');
      throw StorageException('Failed to save settings');
    }
  }

  @override
  Future<List<LogEntry>> loadLogs() async {
    if (_cacheValid && _logsCache != null) {
      _logger.debug('Returning ${_logsCache!.length} logs from cache', 'StorageWeb');
      return List.from(_logsCache!);
    }

    try {
      final data = _localStorage.getItem(_logsKey);
      if (data == null) {
        _logger.debug('No logs found, returning empty list', 'StorageWeb');
        _logsCache = [];
        _cacheValid = true;
        return [];
      }
      final List<dynamic> jsonList = jsonDecode(data);
      _logger.debug('Loaded ${jsonList.length} logs', 'StorageWeb');
      final result = jsonList
          .map((json) => LogEntry.fromJson(json as Map<String, dynamic>))
          .toList();
      _logsCache = result;
      _cacheValid = true;
      return List.from(result);
    } catch (e, stack) {
      _logger.error('Failed to load logs', e, stack, 'StorageWeb');
      return [];
    }
  }

  @override
  Future<void> saveLogs(List<LogEntry> logs) async {
    try {
      final jsonList = logs.map((log) => log.toJson()).toList();
      final json = jsonEncode(jsonList);
      _localStorage.setItem(_logsKey, json);
      _invalidateCache();
      _logger.debug('Saved ${logs.length} logs', 'StorageWeb');
    } catch (e, stack) {
      _logger.error('Failed to save logs', e, stack, 'StorageWeb');
      throw StorageException('Failed to save logs');
    }
  }

  @override
  Future<void> addLog(LogEntry log) async {
    // Ensure cache is populated
    if (!_cacheValid) await loadLogs();
    _logsCache!.add(log);

    // Optimized append to JSON string - avoids parsing/serializing entire list
    try {
      final existing = _localStorage.getItem(_logsKey);
      String newJson;
      if (existing == null || existing == '[]') {
        newJson = '[${jsonEncode(log.toJson())}]';
      } else {
        // Append to existing JSON array: remove trailing ']', add comma and new entry
        newJson = '${existing.substring(0, existing.length - 1)},${jsonEncode(log.toJson())}]';
      }
      _localStorage.setItem(_logsKey, newJson);
      _logger.debug('Appended log entry', 'StorageWeb');
    } catch (e, stack) {
      _logger.error('Failed to add log', e, stack, 'StorageWeb');
      throw StorageException('Failed to add log');
    }
  }

  void _invalidateCache() {
    _cacheValid = false;
    _logsCache = null;
  }

  @override
  Future<void> clearLogs() async {
    try {
      _localStorage.removeItem(_logsKey);
      _invalidateCache();
      _logger.info('Logs cleared', 'StorageWeb');
    } catch (e, stack) {
      _logger.error('Failed to clear logs', e, stack, 'StorageWeb');
      throw StorageException('Failed to clear logs');
    }
  }

  @override
  Future<void> saveNotificationTapTime(DateTime time) async {
    try {
      _localStorage.setItem(_notificationTapKey, time.toIso8601String());
      _logger.debug('Notification tap time saved', 'StorageWeb');
    } catch (e, stack) {
      _logger.error('Failed to save notification tap time', e, stack, 'StorageWeb');
    }
  }

  @override
  Future<DateTime?> loadNotificationTapTime() async {
    try {
      final data = _localStorage.getItem(_notificationTapKey);
      if (data == null) return null;
      return DateTime.parse(data);
    } catch (e, stack) {
      _logger.error('Failed to load notification tap time', e, stack, 'StorageWeb');
      return null;
    }
  }

  @override
  Future<void> clearNotificationTapTime() async {
    try {
      _localStorage.removeItem(_notificationTapKey);
      _logger.debug('Notification tap time cleared', 'StorageWeb');
    } catch (e, stack) {
      _logger.error('Failed to clear notification tap time', e, stack, 'StorageWeb');
    }
  }
}

StorageServiceInterface createStorageService() => StorageServiceImpl();
