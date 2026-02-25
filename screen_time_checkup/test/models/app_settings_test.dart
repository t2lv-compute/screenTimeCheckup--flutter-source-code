import 'package:flutter_test/flutter_test.dart';
import 'package:screen_time_checkup/models/app_settings.dart';

void main() {
  group('AppSettings', () {
    test('creates with default values', () {
      final settings = AppSettings();

      expect(settings.focusTags, AppSettings.defaultFocusTags);
      expect(settings.distractionTags, AppSettings.defaultDistractionTags);
      expect(settings.checkInIntervalMinutes, 15);
      expect(settings.isDarkMode, false);
      expect(settings.hasSeenTutorial, false);
      expect(settings.sessionIntention, '');
    });

    test('creates with custom values', () {
      final settings = AppSettings(
        focusTags: ['work', 'study'],
        distractionTags: ['social media'],
        checkInIntervalMinutes: 30,
        themeMode: 'dark',
        hasSeenTutorial: true,
      );

      expect(settings.focusTags, ['work', 'study']);
      expect(settings.distractionTags, ['social media']);
      expect(settings.checkInIntervalMinutes, 30);
      expect(settings.isDarkMode, true);
      expect(settings.hasSeenTutorial, true);
    });

    test('defaultFocusTags contains expected values', () {
      expect(AppSettings.defaultFocusTags, contains('school'));
      expect(AppSettings.defaultFocusTags, contains('work'));
      expect(AppSettings.defaultFocusTags, contains('email'));
    });

    test('defaultDistractionTags contains expected values', () {
      expect(AppSettings.defaultDistractionTags, contains('social media'));
      expect(AppSettings.defaultDistractionTags, contains('websurfing'));
    });

    test('allTags combines focus and distraction tags', () {
      final settings = AppSettings(
        focusTags: ['work', 'study'],
        distractionTags: ['social media', 'gaming'],
      );

      expect(settings.allTags, ['work', 'study', 'social media', 'gaming']);
    });

    test('allTags returns empty when both lists are empty', () {
      final settings = AppSettings(
        focusTags: [],
        distractionTags: [],
      );

      expect(settings.allTags, isEmpty);
    });

    group('copyWith', () {
      test('copies with new focusTags', () {
        final original = AppSettings();
        final copied = original.copyWith(focusTags: ['new1', 'new2']);

        expect(copied.focusTags, ['new1', 'new2']);
        expect(copied.distractionTags, original.distractionTags);
        expect(copied.checkInIntervalMinutes, original.checkInIntervalMinutes);
        expect(copied.isDarkMode, original.isDarkMode);
      });

      test('copies with new distractionTags', () {
        final original = AppSettings();
        final copied = original.copyWith(distractionTags: ['d1']);

        expect(copied.focusTags, original.focusTags);
        expect(copied.distractionTags, ['d1']);
      });

      test('copies with new checkInIntervalMinutes', () {
        final original = AppSettings();
        final copied = original.copyWith(checkInIntervalMinutes: 60);

        expect(copied.focusTags, original.focusTags);
        expect(copied.checkInIntervalMinutes, 60);
        expect(copied.isDarkMode, original.isDarkMode);
      });

      test('copies with new themeMode', () {
        final original = AppSettings();
        final copied = original.copyWith(themeMode: 'dark');

        expect(copied.focusTags, original.focusTags);
        expect(copied.checkInIntervalMinutes, original.checkInIntervalMinutes);
        expect(copied.isDarkMode, true);
      });

      test('copies with new hasSeenTutorial', () {
        final original = AppSettings();
        final copied = original.copyWith(hasSeenTutorial: true);

        expect(copied.hasSeenTutorial, true);
      });

      test('copies with multiple changes', () {
        final original = AppSettings();
        final copied = original.copyWith(
          focusTags: ['a', 'b'],
          distractionTags: ['c'],
          checkInIntervalMinutes: 45,
          themeMode: 'dark',
          hasSeenTutorial: true,
        );

        expect(copied.focusTags, ['a', 'b']);
        expect(copied.distractionTags, ['c']);
        expect(copied.checkInIntervalMinutes, 45);
        expect(copied.isDarkMode, true);
        expect(copied.hasSeenTutorial, true);
      });

      test('returns equivalent object when no changes specified', () {
        final original = AppSettings(
          focusTags: ['test'],
          distractionTags: ['dist'],
          checkInIntervalMinutes: 20,
          themeMode: 'dark',
          hasSeenTutorial: true,
        );
        final copied = original.copyWith();

        expect(copied.focusTags, original.focusTags);
        expect(copied.distractionTags, original.distractionTags);
        expect(copied.checkInIntervalMinutes, original.checkInIntervalMinutes);
        expect(copied.isDarkMode, original.isDarkMode);
        expect(copied.hasSeenTutorial, original.hasSeenTutorial);
      });
    });

    group('JSON serialization', () {
      test('toJson serializes correctly', () {
        final settings = AppSettings(
          focusTags: ['tag1', 'tag2'],
          distractionTags: ['tag3'],
          checkInIntervalMinutes: 25,
          themeMode: 'dark',
          hasSeenTutorial: true,
        );

        final json = settings.toJson();

        expect(json['focusTags'], ['tag1', 'tag2']);
        expect(json['distractionTags'], ['tag3']);
        expect(json['checkInIntervalMinutes'], 25);
        expect(json['themeMode'], 'dark');
        expect(json['hasSeenTutorial'], true);
      });

      test('fromJson deserializes new format correctly', () {
        final json = {
          'focusTags': ['a', 'b'],
          'distractionTags': ['c'],
          'checkInIntervalMinutes': 10,
          'isDarkMode': false,
          'hasSeenTutorial': true,
        };

        final settings = AppSettings.fromJson(json);

        expect(settings.focusTags, ['a', 'b']);
        expect(settings.distractionTags, ['c']);
        expect(settings.checkInIntervalMinutes, 10);
        expect(settings.isDarkMode, false);
        expect(settings.hasSeenTutorial, true);
      });

      test('fromJson uses defaults for missing fields', () {
        final json = <String, dynamic>{};

        final settings = AppSettings.fromJson(json);

        expect(settings.focusTags, isEmpty);
        expect(settings.distractionTags, isEmpty);
        expect(settings.checkInIntervalMinutes, 15);
        expect(settings.isDarkMode, false);
        expect(settings.hasSeenTutorial, false);
      });

      test('round-trip serialization preserves data', () {
        final original = AppSettings(
          focusTags: ['work', 'study'],
          distractionTags: ['play'],
          checkInIntervalMinutes: 5,
          themeMode: 'dark',
          hasSeenTutorial: true,
        );

        final json = original.toJson();
        final restored = AppSettings.fromJson(json);

        expect(restored.focusTags, original.focusTags);
        expect(restored.distractionTags, original.distractionTags);
        expect(restored.checkInIntervalMinutes, original.checkInIntervalMinutes);
        expect(restored.isDarkMode, original.isDarkMode);
        expect(restored.hasSeenTutorial, original.hasSeenTutorial);
      });
    });

    group('Legacy migration', () {
      test('fromJson migrates actionTags to focusTags', () {
        final json = {
          'actionTags': ['school', 'work', 'social media'],
          'checkInIntervalMinutes': 20,
          'isDarkMode': true,
        };

        final settings = AppSettings.fromJson(json);

        expect(settings.focusTags, ['school', 'work', 'social media']);
        expect(settings.distractionTags, isEmpty);
        expect(settings.checkInIntervalMinutes, 20);
        expect(settings.isDarkMode, true);
        expect(settings.hasSeenTutorial, false);
      });

      test('fromJson prefers new format over legacy', () {
        final json = {
          'actionTags': ['old'],
          'focusTags': ['new'],
          'distractionTags': ['dist'],
        };

        final settings = AppSettings.fromJson(json);

        expect(settings.focusTags, ['new']);
        expect(settings.distractionTags, ['dist']);
      });

      test('fromJson handles empty actionTags', () {
        final json = {
          'actionTags': <String>[],
        };

        final settings = AppSettings.fromJson(json);

        expect(settings.focusTags, isEmpty);
        expect(settings.distractionTags, isEmpty);
      });
    });
  });
}
