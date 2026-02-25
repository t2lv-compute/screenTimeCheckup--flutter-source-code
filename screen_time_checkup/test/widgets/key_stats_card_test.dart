import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screen_time_checkup/widgets/key_stats_card.dart';

void main() {
  group('KeyStatsCard', () {
    testWidgets('displays total check-ins in metric card', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: KeyStatsCard(
                totalLogs: 42,
                onTrackCount: 30,
                missedCheckIns: 2,
                onTrackPercentage: 71.4,
                currentStreak: 3,
                longestStreak: 7,
                quickResponsePercentage: 80.0,
                notificationResponseCount: 10,
                tagGoalCount: {},
                tagOnTrackCount: {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Total check-ins'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('shows on-track percentage in donut centre', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: KeyStatsCard(
                totalLogs: 100,
                onTrackCount: 75,
                missedCheckIns: 5,
                onTrackPercentage: 75.0,
                currentStreak: 1,
                longestStreak: 5,
                quickResponsePercentage: 50.0,
                notificationResponseCount: 20,
                tagGoalCount: {},
                tagOnTrackCount: {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('75%'), findsOneWidget);
      expect(find.text('on track'), findsOneWidget);
    });

    testWidgets('shows streak metrics', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: KeyStatsCard(
                totalLogs: 50,
                onTrackCount: 40,
                missedCheckIns: 0,
                onTrackPercentage: 80.0,
                currentStreak: 5,
                longestStreak: 12,
                quickResponsePercentage: 60.0,
                notificationResponseCount: 15,
                tagGoalCount: {},
                tagOnTrackCount: {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Current streak'), findsOneWidget);
      expect(find.text('5 days'), findsOneWidget);
      expect(find.text('Longest streak'), findsOneWidget);
      expect(find.text('12 days'), findsOneWidget);
    });

    testWidgets('shows goal follow-through when tagGoalCount provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: KeyStatsCard(
                totalLogs: 30,
                onTrackCount: 20,
                missedCheckIns: 0,
                onTrackPercentage: 66.7,
                currentStreak: 2,
                longestStreak: 4,
                quickResponsePercentage: 70.0,
                notificationResponseCount: 10,
                tagGoalCount: {'work': 20, 'exercise': 10},
                tagOnTrackCount: {'work': 15, 'exercise': 5},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Goal Follow-Through'), findsOneWidget);
      expect(find.text('work'), findsOneWidget);
      expect(find.text('exercise'), findsOneWidget);
    });

    testWidgets('hides goal follow-through when tagGoalCount empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: KeyStatsCard(
                totalLogs: 10,
                onTrackCount: 8,
                missedCheckIns: 0,
                onTrackPercentage: 80.0,
                currentStreak: 1,
                longestStreak: 2,
                quickResponsePercentage: 90.0,
                notificationResponseCount: 5,
                tagGoalCount: {},
                tagOnTrackCount: {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Goal Follow-Through'), findsNothing);
    });
  });
}
