import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:screen_time_checkup/models/app_settings.dart';
import 'package:screen_time_checkup/models/log_entry.dart';
import 'package:screen_time_checkup/providers/app_state.dart';
import 'package:screen_time_checkup/services/notification_service_interface.dart';
import '../test/helpers/in_memory_storage.dart';

/// A no-op notification service for integration tests.
class TestNotificationService implements NotificationServiceInterface {
  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<void> scheduleCheckIn(int intervalMinutes) async {}

  @override
  Future<void> cancelCheckIn() async {}

  @override
  Future<void> showTestNotification() async {}

  @override
  void setOnNotificationTap(void Function() callback) {}

  @override
  Future<void> scheduleAtTimes(List<String> times) async {}

  @override
  Future<void> cancelScheduledTimes() async {}

  @override
  Future<void> snoozeCheckIn(Duration delay) async {}
  
  @override
  void setMessagePicker((String, String) Function() picker) {
    // TODO: implement setMessagePicker
  }
}

/// Build test app with injected storage.
Widget buildTestApp({
  required InMemoryStorageService storage,
  TestNotificationService? notifications,
}) {
  return ChangeNotifierProvider(
    create: (context) => AppState(
      storage: storage,
      notifications: notifications ?? TestNotificationService(),
    )..loadData(),
    child: Consumer<AppState>(
      builder: (context, appState, child) {
        return MaterialApp(
          title: 'Screen Time Checkup Test',
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color.fromARGB(255, 0, 50, 0),
              brightness: appState.settings.isDarkMode
                  ? Brightness.dark
                  : Brightness.light,
            ),
          ),
          home: const TestHomePage(),
        );
      },
    ),
  );
}

/// Simplified home page for testing core functionality.
class TestHomePage extends StatelessWidget {
  const TestHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    if (appState.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Test App'),
        actions: [
          Switch(
            key: const Key('dark_mode_switch'),
            value: appState.settings.isDarkMode,
            onChanged: (value) => appState.setThemeMode(value ? 'dark' : 'light'),
          ),
        ],
      ),
      body: ListView(
        children: [
          // Stats section
          Card(
            key: const Key('stats_card'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Logs: ${appState.totalLogs}'),
                  Text('On Track: ${appState.onTrackCount}'),
                  Text(
                      'On Track %: ${appState.onTrackPercentage.toStringAsFixed(1)}%'),
                ],
              ),
            ),
          ),
          // Log entry form
          Card(
            key: const Key('log_form_card'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _LogEntryForm(),
            ),
          ),
          // Logs list
          ...appState.displayedLogs.map((log) => ListTile(
                key: Key('log_${log.timestamp.toIso8601String()}'),
                title: Text(log.doingTag),
                subtitle: Text('Should: ${log.shouldDoTag}'),
                trailing: Icon(
                  log.isOnTrack ? Icons.check_circle : Icons.warning,
                  color: log.isOnTrack ? Colors.green : Colors.orange,
                ),
              )),
          if (appState.hasMoreLogs)
            TextButton(
              key: const Key('load_more_button'),
              onPressed: appState.loadMoreLogs,
              child: const Text('Load More'),
            ),
          // Export/Import/Clear buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                key: const Key('export_button'),
                onPressed: () {
                  final json = appState.exportLogsToJson();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Exported: ${json.length} chars')),
                  );
                },
                child: const Text('Export'),
              ),
              ElevatedButton(
                key: const Key('clear_button'),
                onPressed: () => appState.clearAllLogs(),
                child: const Text('Clear'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LogEntryForm extends StatefulWidget {
  @override
  State<_LogEntryForm> createState() => _LogEntryFormState();
}

class _LogEntryFormState extends State<_LogEntryForm> {
  final _doingController = TextEditingController();
  final _shouldDoController = TextEditingController();

  @override
  void dispose() {
    _doingController.dispose();
    _shouldDoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          key: const Key('doing_field'),
          controller: _doingController,
          decoration: const InputDecoration(labelText: 'What are you doing?'),
        ),
        TextField(
          key: const Key('should_do_field'),
          controller: _shouldDoController,
          decoration:
              const InputDecoration(labelText: 'What should you be doing?'),
        ),
        ElevatedButton(
          key: const Key('submit_button'),
          onPressed: () {
            if (_doingController.text.isNotEmpty &&
                _shouldDoController.text.isNotEmpty) {
              context.read<AppState>().addLogEntry(
                    _doingController.text,
                    _shouldDoController.text,
                  );
              _doingController.clear();
              _shouldDoController.clear();
            }
          },
          child: const Text('Log Entry'),
        ),
      ],
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Check-in Flow', () {
    testWidgets('can create a log entry and see it in the list',
        (tester) async {
      final storage = InMemoryStorageService();
      await tester.pumpWidget(buildTestApp(storage: storage));
      await tester.pumpAndSettle();

      // Verify initial state
      expect(find.text('Total Logs: 0'), findsOneWidget);

      // Fill in the form
      await tester.enterText(find.byKey(const Key('doing_field')), 'working');
      await tester.enterText(find.byKey(const Key('should_do_field')), 'working');

      // Submit the entry
      await tester.tap(find.byKey(const Key('submit_button')));
      await tester.pumpAndSettle();

      // Verify the entry appears
      expect(find.text('Total Logs: 1'), findsOneWidget);
      expect(find.text('working'), findsWidgets);
      expect(find.text('On Track: 1'), findsOneWidget);
    });

    testWidgets('stats update correctly when off-track', (tester) async {
      final storage = InMemoryStorageService();
      await tester.pumpWidget(buildTestApp(storage: storage));
      await tester.pumpAndSettle();

      // Create on-track entry
      await tester.enterText(find.byKey(const Key('doing_field')), 'work');
      await tester.enterText(find.byKey(const Key('should_do_field')), 'work');
      await tester.tap(find.byKey(const Key('submit_button')));
      await tester.pumpAndSettle();

      // Create off-track entry
      await tester.enterText(find.byKey(const Key('doing_field')), 'social media');
      await tester.enterText(find.byKey(const Key('should_do_field')), 'work');
      await tester.tap(find.byKey(const Key('submit_button')));
      await tester.pumpAndSettle();

      // Verify stats
      expect(find.text('Total Logs: 2'), findsOneWidget);
      expect(find.text('On Track: 1'), findsOneWidget);
      expect(find.text('On Track %: 50.0%'), findsOneWidget);
    });
  });

  group('Settings Persistence', () {
    testWidgets('dark mode toggle persists to storage', (tester) async {
      final storage = InMemoryStorageService();
      await tester.pumpWidget(buildTestApp(storage: storage));
      await tester.pumpAndSettle();

      // Verify initial state is light mode
      expect(storage.settings.isDarkMode, false);

      // Toggle dark mode
      await tester.tap(find.byKey(const Key('dark_mode_switch')));
      await tester.pumpAndSettle();

      // Verify it was saved
      expect(storage.settings.isDarkMode, true);
    });

    testWidgets('settings load from storage on startup', (tester) async {
      final storage = InMemoryStorageService();
      await storage.saveSettings(AppSettings(themeMode: 'dark'));

      await tester.pumpWidget(buildTestApp(storage: storage));
      await tester.pumpAndSettle();

      // Verify the switch reflects the stored setting
      final switchWidget =
          tester.widget<Switch>(find.byKey(const Key('dark_mode_switch')));
      expect(switchWidget.value, true);
    });
  });

  group('Export/Import', () {
    testWidgets('export creates valid JSON', (tester) async {
      final storage = InMemoryStorageService();
      await storage.addLog(LogEntry(
        timestamp: DateTime(2024, 1, 1),
        doingTag: 'test',
        shouldDoTag: 'work',
        importance: 5,
      ));

      await tester.pumpWidget(buildTestApp(storage: storage));
      await tester.pumpAndSettle();

      // Tap export
      await tester.tap(find.byKey(const Key('export_button')));
      await tester.pumpAndSettle();

      // Should show snackbar with export info
      expect(find.textContaining('Exported:'), findsOneWidget);
    });

    testWidgets('clear removes all logs', (tester) async {
      final storage = InMemoryStorageService();
      await storage.addLog(LogEntry(
        timestamp: DateTime(2024, 1, 1),
        doingTag: 'test',
        shouldDoTag: 'work',
        importance: 5,
      ));

      await tester.pumpWidget(buildTestApp(storage: storage));
      await tester.pumpAndSettle();

      expect(find.text('Total Logs: 1'), findsOneWidget);

      // Clear logs
      await tester.tap(find.byKey(const Key('clear_button')));
      await tester.pumpAndSettle();

      expect(find.text('Total Logs: 0'), findsOneWidget);
      expect(storage.logs, isEmpty);
    });
  });

  group('Pagination', () {
    testWidgets('load more shows additional logs', (tester) async {
      final storage = InMemoryStorageService();
      // Add 25 logs
      for (var i = 0; i < 25; i++) {
        await storage.addLog(LogEntry(
          timestamp: DateTime(2024, 1, 1, i),
          doingTag: 'log$i',
          shouldDoTag: 'work',
          importance: 5,
        ));
      }

      await tester.pumpWidget(buildTestApp(storage: storage));
      await tester.pumpAndSettle();

      // Should show 20 logs initially (default page size)
      expect(find.text('Total Logs: 25'), findsOneWidget);
      expect(find.byKey(const Key('load_more_button')), findsOneWidget);

      // Load more
      await tester.tap(find.byKey(const Key('load_more_button')));
      await tester.pumpAndSettle();

      // Load more button should be gone
      expect(find.byKey(const Key('load_more_button')), findsNothing);
    });
  });

  group('Data Flow', () {
    testWidgets('AppState with injected storage works correctly',
        (tester) async {
      final storage = InMemoryStorageService();

      // Pre-populate storage
      await storage.saveSettings(AppSettings(
        focusTags: ['custom'],
        themeMode: 'dark',
      ));
      await storage.addLog(LogEntry(
        timestamp: DateTime(2024, 1, 1),
        doingTag: 'existing',
        shouldDoTag: 'work',
        importance: 5,
      ));

      await tester.pumpWidget(buildTestApp(storage: storage));
      await tester.pumpAndSettle();

      // Verify pre-populated data is displayed
      expect(find.text('Total Logs: 1'), findsOneWidget);
      expect(find.text('existing'), findsWidgets);

      // Verify dark mode is on
      final switchWidget =
          tester.widget<Switch>(find.byKey(const Key('dark_mode_switch')));
      expect(switchWidget.value, true);
    });
  });
}
