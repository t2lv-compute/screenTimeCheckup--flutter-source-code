import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/app_settings.dart';
import '../models/log_entry.dart';
import 'storage_service_interface.dart';
import 'logger_service.dart';

class StorageServiceImpl implements StorageServiceInterface {
  static const String _settingsFileName = 'settings.stc';
  static const String _logsFileName = 'logs.stc';
  static const String _notificationTapFileName = 'notification_tap.tmp';
  final _logger = LoggerService();

  // In-memory cache for logs
  List<LogEntry>? _logsCache;
  bool _cacheValid = false;

  Future<Directory> get _appDir async {
    return await getApplicationDocumentsDirectory();
  }

  Future<File> get _settingsFile async {
    final dir = await _appDir;
    return File('${dir.path}/$_settingsFileName');
  }

  Future<File> get _logsFile async {
    final dir = await _appDir;
    return File('${dir.path}/$_logsFileName');
  }

  @override
  Future<AppSettings> loadSettings() async {
    try {
      final file = await _settingsFile;
      if (!await file.exists()) {
        _logger.debug('No settings file found, using defaults', 'StorageMobile');
        return AppSettings();
      }
      final contents = await file.readAsString();
      final json = jsonDecode(contents) as Map<String, dynamic>;
      _logger.debug('Settings loaded successfully', 'StorageMobile');
      return AppSettings.fromJson(json);
    } catch (e, stack) {
      _logger.error('Failed to load settings', e, stack, 'StorageMobile');
      return AppSettings();
    }
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    try {
      final file = await _settingsFile;
      final json = jsonEncode(settings.toJson());
      await file.writeAsString(json);
      _logger.debug('Settings saved successfully', 'StorageMobile');
    } catch (e, stack) {
      _logger.error('Failed to save settings', e, stack, 'StorageMobile');
      throw StorageException('Failed to save settings');
    }
  }

  @override
  Future<List<LogEntry>> loadLogs() async {
    if (_cacheValid && _logsCache != null) {
      _logger.debug('Returning ${_logsCache!.length} logs from cache', 'StorageMobile');
      return List.from(_logsCache!);
    }

    try {
      final file = await _logsFile;
      if (!await file.exists()) {
        _logger.debug('No logs file found, returning empty list', 'StorageMobile');
        _logsCache = [];
        _cacheValid = true;
        return [];
      }
      final contents = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(contents);
      _logger.debug('Loaded ${jsonList.length} logs', 'StorageMobile');
      final result = jsonList
          .map((json) => LogEntry.fromJson(json as Map<String, dynamic>))
          .toList();
      _logsCache = result;
      _cacheValid = true;
      return List.from(result);
    } catch (e, stack) {
      _logger.error('Failed to load logs', e, stack, 'StorageMobile');
      return [];
    }
  }

  @override
  Future<void> saveLogs(List<LogEntry> logs) async {
    try {
      final file = await _logsFile;
      final jsonList = logs.map((log) => log.toJson()).toList();
      final json = jsonEncode(jsonList);
      await file.writeAsString(json);
      _invalidateCache();
      _logger.debug('Saved ${logs.length} logs', 'StorageMobile');
    } catch (e, stack) {
      _logger.error('Failed to save logs', e, stack, 'StorageMobile');
      throw StorageException('Failed to save logs');
    }
  }

  @override
  Future<void> addLog(LogEntry log) async {
    // Ensure cache is populated
    if (!_cacheValid) await loadLogs();
    _logsCache!.add(log);

    // Optimized file append - avoids reading/writing entire file
    try {
      final file = await _logsFile;
      if (!await file.exists() || (await file.length()) <= 2) {
        // Empty or new file - write fresh array
        await file.writeAsString('[${jsonEncode(log.toJson())}]');
      } else {
        // Append to existing file using random access
        final raf = await file.open(mode: FileMode.append);
        try {
          // Move to position before final ']'
          await raf.setPosition(await raf.length() - 1);
          // Write comma + new entry + closing bracket
          await raf.writeString(',${jsonEncode(log.toJson())}]');
        } finally {
          await raf.close();
        }
      }
      _logger.debug('Appended log entry', 'StorageMobile');
    } catch (e, stack) {
      _logger.error('Failed to add log', e, stack, 'StorageMobile');
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
      final file = await _logsFile;
      if (await file.exists()) {
        await file.delete();
        _invalidateCache();
        _logger.info('Logs cleared', 'StorageMobile');
      }
    } catch (e, stack) {
      _logger.error('Failed to clear logs', e, stack, 'StorageMobile');
      throw StorageException('Failed to clear logs');
    }
  }

  Future<File> get _notificationTapFile async {
    final dir = await _appDir;
    return File('${dir.path}/$_notificationTapFileName');
  }

  @override
  Future<void> saveNotificationTapTime(DateTime time) async {
    try {
      final file = await _notificationTapFile;
      await file.writeAsString(time.toIso8601String());
      _logger.debug('Notification tap time saved', 'StorageMobile');
    } catch (e, stack) {
      _logger.error('Failed to save notification tap time', e, stack, 'StorageMobile');
    }
  }

  @override
  Future<DateTime?> loadNotificationTapTime() async {
    try {
      final file = await _notificationTapFile;
      if (!await file.exists()) return null;
      final contents = await file.readAsString();
      return DateTime.parse(contents);
    } catch (e, stack) {
      _logger.error('Failed to load notification tap time', e, stack, 'StorageMobile');
      return null;
    }
  }

  @override
  Future<void> clearNotificationTapTime() async {
    try {
      final file = await _notificationTapFile;
      if (await file.exists()) {
        await file.delete();
        _logger.debug('Notification tap time cleared', 'StorageMobile');
      }
    } catch (e, stack) {
      _logger.error('Failed to clear notification tap time', e, stack, 'StorageMobile');
    }
  }
}

StorageServiceInterface createStorageService() => StorageServiceImpl();
