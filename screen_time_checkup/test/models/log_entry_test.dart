import 'package:flutter_test/flutter_test.dart';
import 'package:screen_time_checkup/models/log_entry.dart';

void main() {
  group('LogEntry', () {
    test('creates with required fields', () {
      final entry = LogEntry(
        timestamp: DateTime(2024, 1, 15, 10, 30),
        doingTag: 'social media',
        shouldDoTag: 'work',
        importance: 3,
      );

      expect(entry.doingTag, 'social media');
      expect(entry.shouldDoTag, 'work');
      expect(entry.importance, 3);
      expect(entry.timestamp, DateTime(2024, 1, 15, 10, 30));
    });

    group('isOnTrack', () {
      test('returns true when doing matches shouldDo', () {
        final entry = LogEntry(
          timestamp: DateTime.now(),
          doingTag: 'work',
          shouldDoTag: 'work',
          importance: 5,
        );

        expect(entry.isOnTrack, true);
      });

      test('returns true when doing matches shouldDo case-insensitively', () {
        final entry = LogEntry(
          timestamp: DateTime.now(),
          doingTag: 'Work',
          shouldDoTag: 'work',
          importance: 5,
        );

        expect(entry.isOnTrack, true);
      });

      test('returns false when doing does not match shouldDo', () {
        final entry = LogEntry(
          timestamp: DateTime.now(),
          doingTag: 'social media',
          shouldDoTag: 'work',
          importance: 3,
        );

        expect(entry.isOnTrack, false);
      });
    });

    group('responseTimeSeconds', () {
      test('isFromNotification returns false when responseTimeSeconds is null',
          () {
        final entry = LogEntry(
          timestamp: DateTime.now(),
          doingTag: 'work',
          shouldDoTag: 'work',
          importance: 5,
        );

        expect(entry.isFromNotification, false);
        expect(entry.responseTimeSeconds, isNull);
      });

      test('isFromNotification returns true when responseTimeSeconds is set',
          () {
        final entry = LogEntry(
          timestamp: DateTime.now(),
          doingTag: 'work',
          shouldDoTag: 'work',
          importance: 5,
          responseTimeSeconds: 120,
        );

        expect(entry.isFromNotification, true);
        expect(entry.responseTimeSeconds, 120);
      });

      test('isQuickResponse returns true when response is under 3 minutes', () {
        final entry = LogEntry(
          timestamp: DateTime.now(),
          doingTag: 'work',
          shouldDoTag: 'work',
          importance: 5,
          responseTimeSeconds: 60, // 1 minute
        );

        expect(entry.isQuickResponse, true);
      });

      test('isQuickResponse returns true at exactly 3 minutes', () {
        final entry = LogEntry(
          timestamp: DateTime.now(),
          doingTag: 'work',
          shouldDoTag: 'work',
          importance: 5,
          responseTimeSeconds: 180, // exactly 3 minutes
        );

        expect(entry.isQuickResponse, true);
      });

      test('isQuickResponse returns false when response is over 3 minutes', () {
        final entry = LogEntry(
          timestamp: DateTime.now(),
          doingTag: 'work',
          shouldDoTag: 'work',
          importance: 5,
          responseTimeSeconds: 200, // over 3 minutes
        );

        expect(entry.isQuickResponse, false);
      });

      test('isQuickResponse returns false when not from notification', () {
        final entry = LogEntry(
          timestamp: DateTime.now(),
          doingTag: 'work',
          shouldDoTag: 'work',
          importance: 5,
        );

        expect(entry.isQuickResponse, false);
      });
    });

    group('JSON serialization', () {
      test('toJson serializes correctly', () {
        final timestamp = DateTime(2024, 1, 15, 10, 30);
        final entry = LogEntry(
          timestamp: timestamp,
          doingTag: 'email',
          shouldDoTag: 'school',
          importance: 4,
        );

        final json = entry.toJson();

        expect(json['timestamp'], timestamp.toIso8601String());
        expect(json['doingTag'], 'email');
        expect(json['shouldDoTag'], 'school');
        expect(json['importance'], 4);
      });

      test('fromJson deserializes correctly', () {
        final json = {
          'timestamp': '2024-01-15T10:30:00.000',
          'doingTag': 'websurfing',
          'shouldDoTag': 'work',
          'importance': 2,
        };

        final entry = LogEntry.fromJson(json);

        expect(entry.timestamp, DateTime(2024, 1, 15, 10, 30));
        expect(entry.doingTag, 'websurfing');
        expect(entry.shouldDoTag, 'work');
        expect(entry.importance, 2);
      });

      test('round-trip serialization preserves data', () {
        final original = LogEntry(
          timestamp: DateTime(2024, 6, 20, 14, 45),
          doingTag: 'other',
          shouldDoTag: 'other',
          importance: 1,
        );

        final json = original.toJson();
        final restored = LogEntry.fromJson(json);

        expect(restored.timestamp, original.timestamp);
        expect(restored.doingTag, original.doingTag);
        expect(restored.shouldDoTag, original.shouldDoTag);
        expect(restored.importance, original.importance);
        expect(restored.isOnTrack, original.isOnTrack);
      });

      test('toJson includes responseTimeSeconds when set', () {
        final entry = LogEntry(
          timestamp: DateTime(2024, 1, 15, 10, 30),
          doingTag: 'work',
          shouldDoTag: 'work',
          importance: 5,
          responseTimeSeconds: 90,
        );

        final json = entry.toJson();

        expect(json['responseTimeSeconds'], 90);
      });

      test('toJson excludes responseTimeSeconds when null', () {
        final entry = LogEntry(
          timestamp: DateTime(2024, 1, 15, 10, 30),
          doingTag: 'work',
          shouldDoTag: 'work',
          importance: 5,
        );

        final json = entry.toJson();

        expect(json.containsKey('responseTimeSeconds'), false);
      });

      test('fromJson handles responseTimeSeconds', () {
        final json = {
          'timestamp': '2024-01-15T10:30:00.000',
          'doingTag': 'work',
          'shouldDoTag': 'work',
          'importance': 5,
          'responseTimeSeconds': 120,
        };

        final entry = LogEntry.fromJson(json);

        expect(entry.responseTimeSeconds, 120);
        expect(entry.isFromNotification, true);
      });

      test('fromJson handles missing responseTimeSeconds', () {
        final json = {
          'timestamp': '2024-01-15T10:30:00.000',
          'doingTag': 'work',
          'shouldDoTag': 'work',
          'importance': 5,
        };

        final entry = LogEntry.fromJson(json);

        expect(entry.responseTimeSeconds, isNull);
        expect(entry.isFromNotification, false);
      });

      test('toJson excludes importance when null', () {
        final entry = LogEntry(
          timestamp: DateTime(2024, 1, 15, 10, 30),
          doingTag: 'work',
          shouldDoTag: 'work',
        );

        final json = entry.toJson();

        expect(json.containsKey('importance'), false);
      });

      test('fromJson handles missing importance', () {
        final json = {
          'timestamp': '2024-01-15T10:30:00.000',
          'doingTag': 'work',
          'shouldDoTag': 'work',
        };

        final entry = LogEntry.fromJson(json);

        expect(entry.importance, isNull);
      });

      test('toJson includes intentionAdherence when set', () {
        final entry = LogEntry(
          timestamp: DateTime(2024, 1, 15, 10, 30),
          doingTag: 'work',
          shouldDoTag: 'work',
          intentionAdherence: 8,
        );

        final json = entry.toJson();

        expect(json['intentionAdherence'], 8);
      });

      test('toJson excludes intentionAdherence when null', () {
        final entry = LogEntry(
          timestamp: DateTime(2024, 1, 15, 10, 30),
          doingTag: 'work',
          shouldDoTag: 'work',
        );

        final json = entry.toJson();

        expect(json.containsKey('intentionAdherence'), false);
      });

      test('fromJson handles intentionAdherence', () {
        final json = {
          'timestamp': '2024-01-15T10:30:00.000',
          'doingTag': 'work',
          'shouldDoTag': 'work',
          'intentionAdherence': 7,
        };

        final entry = LogEntry.fromJson(json);

        expect(entry.intentionAdherence, 7);
      });

      test('fromJson handles missing intentionAdherence', () {
        final json = {
          'timestamp': '2024-01-15T10:30:00.000',
          'doingTag': 'work',
          'shouldDoTag': 'work',
          'importance': 5,
        };

        final entry = LogEntry.fromJson(json);

        expect(entry.intentionAdherence, isNull);
      });
    });
  });
}
