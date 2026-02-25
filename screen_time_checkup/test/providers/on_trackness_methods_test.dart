import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:screen_time_checkup/models/app_settings.dart';
import 'package:screen_time_checkup/models/log_entry.dart';
import 'package:screen_time_checkup/providers/app_state.dart';
import 'package:screen_time_checkup/services/logger_service.dart';
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

    when(() => mockStorage.loadSettings()).thenAnswer((_) async => AppSettings());
    when(() => mockStorage.loadLogs()).thenAnswer((_) async => []);
    when(() => mockStorage.saveSettings(any())).thenAnswer((_) async {});
    when(() => mockStorage.saveLogs(any())).thenAnswer((_) async {});
    when(() => mockStorage.addLog(any())).thenAnswer((_) async {});
    when(() => mockStorage.clearLogs()).thenAnswer((_) async {});
    when(() => mockStorage.loadNotificationTapTime()).thenAnswer((_) async => null);
    when(() => mockStorage.saveNotificationTapTime(any())).thenAnswer((_) async {});
    when(() => mockStorage.clearNotificationTapTime()).thenAnswer((_) async {});

    when(() => mockNotifications.initialize()).thenAnswer((_) async {});
    when(() => mockNotifications.setOnNotificationTap(any())).thenReturn(null);
    when(() => mockNotifications.requestPermissions()).thenAnswer((_) async => true);
    when(() => mockNotifications.scheduleCheckIn(any())).thenAnswer((_) async {});
    when(() => mockNotifications.scheduleAtTimes(any())).thenAnswer((_) async {});
    when(() => mockNotifications.snoozeCheckIn(any())).thenAnswer((_) async {});

    appState = AppState(
      storage: mockStorage,
      notifications: mockNotifications,
      logger: logger,
    );
  });

  /// Helper to create a non-missed log for the given datetime and on-track status.
  LogEntry makeLog(DateTime ts, {bool onTrack = true}) {
    return LogEntry(
      timestamp: ts,
      doingTag: onTrack ? 'work' : 'social media',
      shouldDoTag: 'work',
    );
  }

  group('hourlyOnTracknessForDay', () {
    test('returns empty map when no logs on that day', () async {
      when(() => mockStorage.loadLogs()).thenAnswer((_) async => []);
      await appState.loadData();

      final result = appState.hourlyOnTracknessForDay(DateTime(2024, 6, 1));
      expect(result, isEmpty);
    });

    test('correctly groups logs by hour', () async {
      final day = DateTime(2024, 6, 1);
      final logs = [
        makeLog(DateTime(2024, 6, 1, 9, 0), onTrack: true),
        makeLog(DateTime(2024, 6, 1, 9, 30), onTrack: false),
        makeLog(DateTime(2024, 6, 1, 14, 0), onTrack: true),
        makeLog(DateTime(2024, 6, 2, 9, 0), onTrack: true), // different day — ignored
      ];
      when(() => mockStorage.loadLogs()).thenAnswer((_) async => logs);
      await appState.loadData();

      final result = appState.hourlyOnTracknessForDay(day);

      expect(result.length, 2);
      expect(result[9], 0.5); // 1 on-track out of 2
      expect(result[14], 1.0); // 1 on-track out of 1
    });

    test('excludes missed entries', () async {
      final day = DateTime(2024, 6, 1);
      final logs = [
        makeLog(DateTime(2024, 6, 1, 10, 0), onTrack: true),
        LogEntry.missed(timestamp: DateTime(2024, 6, 1, 11, 0)),
      ];
      when(() => mockStorage.loadLogs()).thenAnswer((_) async => logs);
      await appState.loadData();

      final result = appState.hourlyOnTracknessForDay(day);
      // Only hour 10 should appear; missed entry at 11 is excluded
      expect(result.containsKey(11), false);
      expect(result[10], 1.0);
    });
  });

  group('dailyOnTracknessForWeek', () {
    test('returns empty map when no logs in that week', () async {
      when(() => mockStorage.loadLogs()).thenAnswer((_) async => []);
      await appState.loadData();

      final result = appState.dailyOnTracknessForWeek(DateTime(2024, 6, 3)); // Monday
      expect(result, isEmpty);
    });

    test('groups logs by weekday (0=Mon) within ISO week', () async {
      // Week of 3 Jun 2024 (Mon) to 9 Jun 2024 (Sun)
      final monday = DateTime(2024, 6, 3); // weekday index 0
      final logs = [
        makeLog(DateTime(2024, 6, 3, 9, 0), onTrack: true),   // Mon
        makeLog(DateTime(2024, 6, 3, 14, 0), onTrack: false),  // Mon
        makeLog(DateTime(2024, 6, 5, 10, 0), onTrack: true),   // Wed
        makeLog(DateTime(2024, 6, 10, 9, 0), onTrack: true),   // next Mon — ignored
      ];
      when(() => mockStorage.loadLogs()).thenAnswer((_) async => logs);
      await appState.loadData();

      final result = appState.dailyOnTracknessForWeek(monday);

      expect(result.length, 2);
      expect(result[0], 0.5);  // Mon: 1/2
      expect(result[2], 1.0);  // Wed: 1/1
      expect(result.containsKey(1), false); // Tue: no data
    });

    test('cursor does not need to be Monday', () async {
      // Passing a Wednesday should still return the full Mon-Sun week
      final logs = [
        makeLog(DateTime(2024, 6, 3, 9, 0), onTrack: true),   // Mon of same week
        makeLog(DateTime(2024, 6, 9, 10, 0), onTrack: false),  // Sun of same week
      ];
      when(() => mockStorage.loadLogs()).thenAnswer((_) async => logs);
      await appState.loadData();

      final result = appState.dailyOnTracknessForWeek(DateTime(2024, 6, 5)); // Wednesday

      expect(result[0], 1.0);  // Mon
      expect(result[6], 0.0);  // Sun
    });
  });

  group('dailyOnTracknessForMonth', () {
    test('returns empty map when no logs in that month', () async {
      when(() => mockStorage.loadLogs()).thenAnswer((_) async => []);
      await appState.loadData();

      final result = appState.dailyOnTracknessForMonth(2024, 6);
      expect(result, isEmpty);
    });

    test('groups logs by day-of-month', () async {
      final logs = [
        makeLog(DateTime(2024, 6, 1, 9, 0), onTrack: true),
        makeLog(DateTime(2024, 6, 1, 14, 0), onTrack: false),
        makeLog(DateTime(2024, 6, 15, 10, 0), onTrack: true),
        makeLog(DateTime(2024, 7, 1, 9, 0), onTrack: true), // different month — ignored
      ];
      when(() => mockStorage.loadLogs()).thenAnswer((_) async => logs);
      await appState.loadData();

      final result = appState.dailyOnTracknessForMonth(2024, 6);

      expect(result.length, 2);
      expect(result[1], 0.5);   // day 1: 1/2
      expect(result[15], 1.0);  // day 15: 1/1
    });

    test('excludes missed entries', () async {
      final logs = [
        makeLog(DateTime(2024, 6, 5, 10, 0), onTrack: true),
        LogEntry.missed(timestamp: DateTime(2024, 6, 5, 11, 0)),
      ];
      when(() => mockStorage.loadLogs()).thenAnswer((_) async => logs);
      await appState.loadData();

      final result = appState.dailyOnTracknessForMonth(2024, 6);
      // Only 1 non-missed entry on day 5
      expect(result[5], 1.0);
      expect(result.length, 1);
    });
  });
}
