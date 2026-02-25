import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:screen_time_checkup/models/app_settings.dart';
import 'package:screen_time_checkup/models/log_entry.dart';
import 'package:screen_time_checkup/providers/app_state.dart';
import 'package:screen_time_checkup/services/logger_service.dart';
import 'package:screen_time_checkup/services/storage_service_interface.dart';
import '../mocks.dart';

void main() {
  late MockStorageService mockStorage;
  late MockNotificationService mockNotifications;
  late LoggerService logger;
  late AppState appState;

  setUpAll(() {
    registerFallbackValues();
  });

  setUp(() {
    mockStorage = MockStorageService();
    mockNotifications = MockNotificationService();
    logger = LoggerService();
    logger.reset();

    // Default stubs
    when(() => mockStorage.loadSettings())
        .thenAnswer((_) async => AppSettings());
    when(() => mockStorage.loadLogs()).thenAnswer((_) async => []);
    when(() => mockStorage.saveSettings(any())).thenAnswer((_) async {});
    when(() => mockStorage.saveLogs(any())).thenAnswer((_) async {});
    when(() => mockStorage.addLog(any())).thenAnswer((_) async {});
    when(() => mockStorage.clearLogs()).thenAnswer((_) async {});

    when(() => mockStorage.loadNotificationTapTime())
        .thenAnswer((_) async => null);
    when(() => mockStorage.saveNotificationTapTime(any()))
        .thenAnswer((_) async {});
    when(() => mockStorage.clearNotificationTapTime())
        .thenAnswer((_) async {});

    when(() => mockNotifications.initialize()).thenAnswer((_) async {});
    when(() => mockNotifications.setOnNotificationTap(any())).thenReturn(null);
    when(() => mockNotifications.setMessagePicker(any())).thenReturn(null);
    when(() => mockNotifications.requestPermissions())
        .thenAnswer((_) async => true);
    when(() => mockNotifications.scheduleCheckIn(any()))
        .thenAnswer((_) async {});
    when(() => mockNotifications.showTestNotification())
        .thenAnswer((_) async {});
    when(() => mockNotifications.scheduleAtTimes(any()))
        .thenAnswer((_) async {});
    when(() => mockNotifications.snoozeCheckIn(any()))
        .thenAnswer((_) async {});

    appState = AppState(
      storage: mockStorage,
      notifications: mockNotifications,
      logger: logger,
    );
  });

  group('Initialization', () {
    test('loadData() loads settings and logs from storage', () async {
      final testSettings = AppSettings(
        focusTags: ['tag1', 'tag2'],
        checkInIntervalMinutes: 30,
        themeMode: 'dark',
      );
      final testLogs = [
        LogEntry(
          timestamp: DateTime(2024, 1, 1, 10, 0),
          doingTag: 'work',
          shouldDoTag: 'work',
          importance: 5,
        ),
      ];

      when(() => mockStorage.loadSettings())
          .thenAnswer((_) async => testSettings);
      when(() => mockStorage.loadLogs()).thenAnswer((_) async => testLogs);

      await appState.loadData();

      expect(appState.settings.focusTags, ['tag1', 'tag2']);
      expect(appState.settings.checkInIntervalMinutes, 30);
      expect(appState.settings.isDarkMode, true);
      expect(appState.logs.length, 1);
    });

    test('loadData() sets isLoading correctly', () async {
      expect(appState.isLoading, true);

      await appState.loadData();

      expect(appState.isLoading, false);
    });

    test('loadData() initializes notifications', () async {
      await appState.loadData();

      verify(() => mockNotifications.initialize()).called(1);
      verify(() => mockNotifications.setOnNotificationTap(any())).called(1);
    });
  });

  group('Settings', () {
    test('updateFocusTags() updates focus tags and persists to storage', () async {
      await appState.loadData();
      await appState.updateFocusTags(['new', 'tags']);

      expect(appState.settings.focusTags, ['new', 'tags']);
      verify(() => mockStorage.saveSettings(any())).called(1);
    });

    test('updateDistractionTags() updates distraction tags and persists to storage', () async {
      await appState.loadData();
      await appState.updateDistractionTags(['distraction1']);

      expect(appState.settings.distractionTags, ['distraction1']);
      verify(() => mockStorage.saveSettings(any())).called(1);
    });

    test('markTutorialSeen() sets hasSeenTutorial and persists', () async {
      await appState.loadData();
      await appState.markTutorialSeen();

      expect(appState.settings.hasSeenTutorial, true);
      verify(() => mockStorage.saveSettings(any())).called(1);
    });

    test('updateInterval() updates interval and schedules notifications',
        () async {
      await appState.loadData();
      // loadData() auto-schedules, so clear interaction history
      clearInteractions(mockNotifications);

      await appState.updateInterval(45);

      expect(appState.settings.checkInIntervalMinutes, 45);
      verify(() => mockStorage.saveSettings(any())).called(1);
      verify(() => mockNotifications.requestPermissions()).called(1);
      verify(() => mockNotifications.scheduleCheckIn(45)).called(1);
    });

    test('setThemeMode() updates theme mode setting', () async {
      await appState.loadData();
      await appState.setThemeMode('dark');

      expect(appState.settings.isDarkMode, true);
      verify(() => mockStorage.saveSettings(any())).called(1);
    });
  });

  group('Log Management', () {
    test('addLogEntry() creates entry and calls storage', () async {
      await appState.loadData();
      await appState.addLogEntry('working', 'working');

      expect(appState.logs.length, 1);
      expect(appState.logs[0].doingTag, 'working');
      expect(appState.logs[0].shouldDoTag, 'working');
      expect(appState.logs[0].importance, isNull);
      verify(() => mockStorage.addLog(any())).called(1);
    });

    test('addLogEntry() invalidates statistics cache', () async {
      final testLogs = [
        LogEntry(
          timestamp: DateTime(2024, 1, 1),
          doingTag: 'work',
          shouldDoTag: 'work',
          importance: 5,
        ),
      ];
      when(() => mockStorage.loadLogs()).thenAnswer((_) async => testLogs);

      await appState.loadData();

      // Access to populate cache
      expect(appState.onTrackCount, 1);

      await appState.addLogEntry('social media', 'work');

      // Cache should be invalidated and recalculated
      expect(appState.onTrackCount, 1); // 1 on track out of 2
    });

    test('clearAllLogs() removes all logs', () async {
      final testLogs = [
        LogEntry(
          timestamp: DateTime(2024, 1, 1),
          doingTag: 'work',
          shouldDoTag: 'work',
          importance: 5,
        ),
      ];
      when(() => mockStorage.loadLogs()).thenAnswer((_) async => testLogs);

      await appState.loadData();
      expect(appState.logs.length, 1);

      await appState.clearAllLogs();

      expect(appState.logs.length, 0);
      verify(() => mockStorage.clearLogs()).called(1);
    });
  });

  group('Statistics', () {
    test('totalLogs returns correct count', () async {
      final testLogs = List.generate(
        5,
        (i) => LogEntry(
          timestamp: DateTime(2024, 1, i + 1),
          doingTag: 'work',
          shouldDoTag: 'work',
          importance: 5,
        ),
      );
      when(() => mockStorage.loadLogs()).thenAnswer((_) async => testLogs);

      await appState.loadData();

      expect(appState.totalLogs, 5);
    });

    test('onTrackCount calculates correctly', () async {
      final testLogs = [
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
        LogEntry(
          timestamp: DateTime(2024, 1, 3),
          doingTag: 'school',
          shouldDoTag: 'school',
          importance: 4,
        ),
      ];
      when(() => mockStorage.loadLogs()).thenAnswer((_) async => testLogs);

      await appState.loadData();

      expect(appState.onTrackCount, 2);
    });

    test('onTrackPercentage calculates correctly', () async {
      final testLogs = [
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
      when(() => mockStorage.loadLogs()).thenAnswer((_) async => testLogs);

      await appState.loadData();

      expect(appState.onTrackPercentage, 50.0);
    });

    test('onTrackPercentage returns 0 when no logs', () async {
      await appState.loadData();

      expect(appState.onTrackPercentage, 0);
    });

    test('tagUsageStats counts tags correctly', () async {
      final testLogs = [
        LogEntry(
          timestamp: DateTime(2024, 1, 1),
          doingTag: 'work',
          shouldDoTag: 'work',
          importance: 5,
        ),
        LogEntry(
          timestamp: DateTime(2024, 1, 2),
          doingTag: 'work',
          shouldDoTag: 'work',
          importance: 3,
        ),
        LogEntry(
          timestamp: DateTime(2024, 1, 3),
          doingTag: 'social media',
          shouldDoTag: 'work',
          importance: 4,
        ),
      ];
      when(() => mockStorage.loadLogs()).thenAnswer((_) async => testLogs);

      await appState.loadData();

      expect(appState.tagUsageStats, {'work': 2, 'social media': 1});
    });
  });

  group('Pagination', () {
    test('displayedLogs returns limited results', () async {
      final testLogs = List.generate(
        30,
        (i) => LogEntry(
          timestamp: DateTime(2024, 1, 1, i),
          doingTag: 'work',
          shouldDoTag: 'work',
          importance: 5,
        ),
      );
      when(() => mockStorage.loadLogs()).thenAnswer((_) async => testLogs);

      await appState.loadData();

      expect(appState.displayedLogs.length, 20); // Default page size
    });

    test('loadMoreLogs() increases displayed count', () async {
      final testLogs = List.generate(
        50,
        (i) => LogEntry(
          timestamp: DateTime(2024, 1, 1, i),
          doingTag: 'work',
          shouldDoTag: 'work',
          importance: 5,
        ),
      );
      when(() => mockStorage.loadLogs()).thenAnswer((_) async => testLogs);

      await appState.loadData();
      expect(appState.displayedLogs.length, 20);

      appState.loadMoreLogs();
      expect(appState.displayedLogs.length, 40);
    });

    test('hasMoreLogs returns correct value', () async {
      final testLogs = List.generate(
        25,
        (i) => LogEntry(
          timestamp: DateTime(2024, 1, 1, i),
          doingTag: 'work',
          shouldDoTag: 'work',
          importance: 5,
        ),
      );
      when(() => mockStorage.loadLogs()).thenAnswer((_) async => testLogs);

      await appState.loadData();

      expect(appState.hasMoreLogs, true);

      appState.loadMoreLogs();
      expect(appState.hasMoreLogs, false);
    });

  });

  group('Import/Export', () {
    test('exportLogsToJson() creates valid JSON', () async {
      final testLogs = [
        LogEntry(
          timestamp: DateTime(2024, 1, 1, 10, 0),
          doingTag: 'work',
          shouldDoTag: 'work',
          importance: 5,
        ),
      ];
      when(() => mockStorage.loadLogs()).thenAnswer((_) async => testLogs);

      await appState.loadData();
      final json = appState.exportLogsToJson();
      final data = jsonDecode(json) as Map<String, dynamic>;

      expect(data['version'], 1);
      expect(data['logs'], isA<List>());
      expect((data['logs'] as List).length, 1);
      expect(data['settings'], isA<Map>());
    });

    test('importLogsFromJson() adds new logs', () async {
      await appState.loadData();

      final importData = jsonEncode({
        'version': 1,
        'logs': [
          {
            'timestamp': DateTime(2024, 1, 1).toIso8601String(),
            'doingTag': 'imported',
            'shouldDoTag': 'work',
            'importance': 4,
          },
        ],
      });

      final result = await appState.importLogsFromJson(importData);

      expect(result, true);
      expect(appState.logs.length, 1);
      expect(appState.logs[0].doingTag, 'imported');
    });

    test('importLogsFromJson() handles duplicate timestamps', () async {
      final existingLog = LogEntry(
        timestamp: DateTime(2024, 1, 1),
        doingTag: 'existing',
        shouldDoTag: 'work',
        importance: 5,
      );
      when(() => mockStorage.loadLogs())
          .thenAnswer((_) async => [existingLog]);

      await appState.loadData();

      final importData = jsonEncode({
        'version': 1,
        'logs': [
          {
            'timestamp': DateTime(2024, 1, 1).toIso8601String(), // Duplicate
            'doingTag': 'duplicate',
            'shouldDoTag': 'work',
            'importance': 4,
          },
          {
            'timestamp': DateTime(2024, 1, 2).toIso8601String(), // New
            'doingTag': 'new',
            'shouldDoTag': 'work',
            'importance': 3,
          },
        ],
      });

      final result = await appState.importLogsFromJson(importData);

      expect(result, true);
      expect(appState.logs.length, 2); // 1 existing + 1 new (duplicate skipped)
    });

    test('importLogsFromJson() returns false for invalid JSON', () async {
      await appState.loadData();

      final result = await appState.importLogsFromJson('invalid json');

      expect(result, false);
      expect(appState.errorMessage, isNotNull);
    });

    test('importLogsFromJson() returns false when logs key is missing',
        () async {
      await appState.loadData();

      final result = await appState.importLogsFromJson('{"version": 1}');

      expect(result, false);
      expect(appState.errorMessage, 'Invalid backup file: no logs found');
    });
  });

  group('Error Handling', () {
    test('storage failures set errorMessage for updateFocusTags', () async {
      when(() => mockStorage.saveSettings(any()))
          .thenThrow(StorageException('Storage error'));

      await appState.loadData();
      await appState.updateFocusTags(['test']);

      // Settings are still updated locally even on storage failure
      expect(appState.settings.focusTags, ['test']);
      expect(appState.errorMessage, 'Storage error');
    });

    test('clearError() resets errorMessage', () async {
      when(() => mockStorage.saveSettings(any()))
          .thenThrow(StorageException('Storage error'));

      await appState.loadData();
      await appState.updateFocusTags(['test']);

      appState.clearError();
      expect(appState.errorMessage, isNull);
    });
  });
}
