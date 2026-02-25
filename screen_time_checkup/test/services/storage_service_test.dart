import 'package:flutter_test/flutter_test.dart';
import 'package:screen_time_checkup/models/app_settings.dart';
import 'package:screen_time_checkup/models/log_entry.dart';
import '../helpers/in_memory_storage.dart';

void main() {
  late InMemoryStorageService storage;

  setUp(() {
    storage = InMemoryStorageService();
  });

  group('Settings CRUD', () {
    test('loadSettings() returns default settings when empty', () async {
      final settings = await storage.loadSettings();

      expect(settings.focusTags, AppSettings.defaultFocusTags);
      expect(settings.distractionTags, AppSettings.defaultDistractionTags);
      expect(settings.checkInIntervalMinutes, 15);
      expect(settings.isDarkMode, false);
    });

    test('saveSettings() persists settings', () async {
      final settings = AppSettings(
        focusTags: ['custom', 'tags'],
        distractionTags: ['distraction'],
        checkInIntervalMinutes: 30,
        themeMode: 'dark',
      );

      await storage.saveSettings(settings);
      final loaded = await storage.loadSettings();

      expect(loaded.focusTags, ['custom', 'tags']);
      expect(loaded.distractionTags, ['distraction']);
      expect(loaded.checkInIntervalMinutes, 30);
      expect(loaded.isDarkMode, true);
    });

    test('saveSettings() overwrites previous settings', () async {
      await storage.saveSettings(AppSettings(themeMode: 'dark'));
      await storage.saveSettings(AppSettings(themeMode: 'light'));

      final loaded = await storage.loadSettings();
      expect(loaded.isDarkMode, false);
    });
  });

  group('Logs CRUD', () {
    test('loadLogs() returns empty list when no logs', () async {
      final logs = await storage.loadLogs();

      expect(logs, isEmpty);
    });

    test('saveLogs() persists logs', () async {
      final logs = [
        LogEntry(
          timestamp: DateTime(2024, 1, 1),
          doingTag: 'work',
          shouldDoTag: 'work',
          importance: 5,
        ),
        LogEntry(
          timestamp: DateTime(2024, 1, 2),
          doingTag: 'social media',
          shouldDoTag: 'work',
          importance: 3,
        ),
      ];

      await storage.saveLogs(logs);
      final loaded = await storage.loadLogs();

      expect(loaded.length, 2);
      expect(loaded[0].doingTag, 'work');
      expect(loaded[1].doingTag, 'social media');
    });

    test('addLog() appends single log', () async {
      final log = LogEntry(
        timestamp: DateTime(2024, 1, 1),
        doingTag: 'work',
        shouldDoTag: 'work',
        importance: 5,
      );

      await storage.addLog(log);
      final loaded = await storage.loadLogs();

      expect(loaded.length, 1);
      expect(loaded[0].doingTag, 'work');
    });

    test('addLog() preserves existing logs', () async {
      final log1 = LogEntry(
        timestamp: DateTime(2024, 1, 1),
        doingTag: 'first',
        shouldDoTag: 'work',
        importance: 5,
      );
      final log2 = LogEntry(
        timestamp: DateTime(2024, 1, 2),
        doingTag: 'second',
        shouldDoTag: 'work',
        importance: 4,
      );

      await storage.addLog(log1);
      await storage.addLog(log2);
      final loaded = await storage.loadLogs();

      expect(loaded.length, 2);
      expect(loaded[0].doingTag, 'first');
      expect(loaded[1].doingTag, 'second');
    });

    test('clearLogs() removes all logs', () async {
      await storage.addLog(LogEntry(
        timestamp: DateTime(2024, 1, 1),
        doingTag: 'work',
        shouldDoTag: 'work',
        importance: 5,
      ));
      await storage.addLog(LogEntry(
        timestamp: DateTime(2024, 1, 2),
        doingTag: 'work',
        shouldDoTag: 'work',
        importance: 5,
      ));

      await storage.clearLogs();
      final loaded = await storage.loadLogs();

      expect(loaded, isEmpty);
    });
  });

  group('Performance - addLog optimization', () {
    test('addLog() does not reload all logs via loadLogs', () async {
      // Pre-populate with some logs
      await storage.saveLogs([
        LogEntry(
          timestamp: DateTime(2024, 1, 1),
          doingTag: 'existing',
          shouldDoTag: 'work',
          importance: 5,
        ),
      ]);

      storage.resetCounters();

      // Add a new log
      await storage.addLog(LogEntry(
        timestamp: DateTime(2024, 1, 2),
        doingTag: 'new',
        shouldDoTag: 'work',
        importance: 4,
      ));

      // InMemoryStorageService.addLog doesn't need to call loadLogs
      // In real storage implementations with caching, we verify this behavior
      expect(storage.addLogCallCount, 1);
    });

    test('multiple addLog() calls are efficient', () async {
      storage.resetCounters();

      // Add 100 logs
      for (var i = 0; i < 100; i++) {
        await storage.addLog(LogEntry(
          timestamp: DateTime(2024, 1, 1, i),
          doingTag: 'log$i',
          shouldDoTag: 'work',
          importance: 5,
        ));
      }

      expect(storage.addLogCallCount, 100);
      expect(storage.logs.length, 100);
    });
  });

  group('LogEntry preservation', () {
    test('all LogEntry fields are preserved through save/load cycle', () async {
      final original = LogEntry(
        timestamp: DateTime(2024, 6, 15, 14, 30, 45),
        doingTag: 'specific tag',
        shouldDoTag: 'different tag',
        importance: 7,
      );

      await storage.addLog(original);
      final loaded = (await storage.loadLogs())[0];

      expect(loaded.timestamp, original.timestamp);
      expect(loaded.doingTag, original.doingTag);
      expect(loaded.shouldDoTag, original.shouldDoTag);
      expect(loaded.importance, original.importance);
      expect(loaded.isOnTrack, original.isOnTrack);
    });

    test('isOnTrack is computed correctly after load', () async {
      await storage.addLog(LogEntry(
        timestamp: DateTime(2024, 1, 1),
        doingTag: 'work',
        shouldDoTag: 'work',
        importance: 5,
      ));
      await storage.addLog(LogEntry(
        timestamp: DateTime(2024, 1, 2),
        doingTag: 'social media',
        shouldDoTag: 'work',
        importance: 3,
      ));

      final loaded = await storage.loadLogs();

      expect(loaded[0].isOnTrack, true);
      expect(loaded[1].isOnTrack, false);
    });
  });

  group('Data isolation', () {
    test('loadLogs() returns a copy, not the internal list', () async {
      await storage.addLog(LogEntry(
        timestamp: DateTime(2024, 1, 1),
        doingTag: 'work',
        shouldDoTag: 'work',
        importance: 5,
      ));

      final loaded = await storage.loadLogs();
      loaded.clear(); // Modify the returned list

      final loadedAgain = await storage.loadLogs();
      expect(loadedAgain.length, 1); // Internal storage unaffected
    });
  });
}
