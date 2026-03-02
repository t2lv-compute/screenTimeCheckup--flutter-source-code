import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../widgets/title_text.dart';
import '../widgets/page_customization_sheet.dart';

class HomePage extends StatefulWidget {
  final void Function(String? scrollTarget) onNavigateToSettings;
  final void Function(String? scrollTarget) onNavigateToStats;
  final VoidCallback onOpenCheckIn;

  const HomePage({
    super.key,
    required this.onNavigateToSettings,
    required this.onNavigateToStats,
    required this.onOpenCheckIn,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Timer? _countdownTimer;
  DateTime? _prevNextNotificationTime;
  DateTime? _prevScheduledAt;
  bool _intentionPromptShown = false;

  static const List<SectionConfig> _allSections = [
    SectionConfig(id: 'timer', label: 'Next Check-in'),
    SectionConfig(id: 'intention', label: 'Session Intention'),
    SectionConfig(id: 'streak', label: 'Streak'),
    SectionConfig(id: 'checkin', label: 'Check In Button'),
    SectionConfig(id: 'quickStats', label: "Today's Stats"),
  ];

  @override
  void initState() {
    super.initState();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final appState = context.read<AppState>();
      final nextTime = appState.nextNotificationTime;
      final scheduledAt = appState.scheduledAt;

      // If _scheduledAt changed (e.g. after a check-in reset), update baseline
      // and skip fire detection for this tick to avoid a false increment.
      if (scheduledAt != _prevScheduledAt) {
        _prevScheduledAt = scheduledAt;
        _prevNextNotificationTime = nextTime;
        setState(() {});
        return;
      }

      // Detect when a notification period elapses: nextNotificationTime jumps
      // forward by approximately one interval.
      if (_prevNextNotificationTime != null && nextTime != null) {
        final jumpSeconds =
            nextTime.difference(_prevNextNotificationTime!).inSeconds;
        final halfIntervalSeconds =
            appState.settings.checkInIntervalMinutes * 30;
        if (jumpSeconds >= halfIntervalSeconds) {
          appState.onNotificationFired();
        }
      }
      _prevNextNotificationTime = nextTime;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Widget? _buildSection(String id, AppState appState) {
    switch (id) {
      case 'timer':
        return _buildTimerSection(appState);
      case 'intention':
        return _buildIntentionBar(appState);
      case 'streak':
        return _buildStreakCard(appState);
      case 'checkin':
        return _buildCheckInButton();
      case 'quickStats':
        return _buildQuickStats(appState);
      default:
        return null;
    }
  }

  Widget _buildTimerSection(AppState appState) {
    final nextTime = appState.nextNotificationTime;
    final bool isActive = nextTime != null;

    double progress = 0.0;
    String timeText = '--:--';
    String label = 'No check-in scheduled';
    bool isOverdue = false;

    if (isActive) {
      final remaining = nextTime.difference(DateTime.now());
      final totalWindow = appState.notificationWindowDuration;

      if (remaining.isNegative) {
        // Count how long overdue (elapsed since notification fired)
        final elapsed = remaining.abs();
        final minutes = elapsed.inMinutes;
        final seconds = elapsed.inSeconds % 60;
        progress = 1.0;
        timeText = '-${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
        label = 'Check-in overdue!';
        isOverdue = true;
      } else {
        progress = 1.0 - (remaining.inSeconds / totalWindow.inSeconds).clamp(0.0, 1.0);
        final hours = remaining.inHours;
        final minutes = remaining.inMinutes % 60;
        final seconds = remaining.inSeconds % 60;
        timeText = '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
        label = 'until next check-in';
      }
    }

    final colorScheme = Theme.of(context).colorScheme;
    final timerColor = isOverdue ? colorScheme.error : colorScheme.primary;

    final semanticLabel = isOverdue
        ? 'Check-in overdue by $timeText'
        : isActive
            ? 'Next check-in in $timeText'
            : label;

    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: Center(
        child: Column(
          children: [
            SizedBox(
              width: 180,
              height: 180,
              child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 180,
                  height: 180,
                  child: CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 10,
                    color: colorScheme.surfaceContainerHighest,
                  ),
                ),
                SizedBox(
                  width: 180,
                  height: 180,
                  child: CircularProgressIndicator(
                    value: isActive ? progress : 0.0,
                    strokeWidth: 10,
                    color: isActive ? timerColor : colorScheme.outlineVariant,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Text(
                  timeText,
                  style: TextStyle(
                    fontSize: isOverdue ? 30 : 36,
                    fontWeight: FontWeight.bold,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: isOverdue
                        ? colorScheme.error
                        : isActive
                            ? colorScheme.onSurface
                            : colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
              color: isOverdue
                  ? colorScheme.error
                  : isActive
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.outline,
            ),
          ),
        ],
      ),
    ),
  );
  }

  Widget _buildIntentionBar(AppState appState) {
    final hasIntention = appState.settings.sessionIntention.isNotEmpty;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              Icons.flag,
              color: hasIntention
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Session Intention',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasIntention
                        ? appState.settings.sessionIntention
                        : 'No intention set',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: hasIntention ? FontWeight.bold : FontWeight.normal,
                      color: hasIntention
                          ? colorScheme.onSurface
                          : colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => widget.onNavigateToSettings('intention'),
              child: const Text('Edit'),
            ),
          ],
        ),
      ),
    );
  }

  String _streakMessage(int streak) {
    if (streak == 0) return 'Start your streak today!';
    if (streak == 1) return 'Great start — keep it going!';
    if (streak <= 3) return 'You\'re building momentum!';
    if (streak <= 6) return 'Solid focus this week!';
    if (streak == 7) return 'One full week — well done!';
    if (streak <= 13) return 'Over a week strong!';
    if (streak == 14) return 'Two weeks of focus!';
    if (streak <= 20) return 'You\'re on a roll!';
    if (streak == 21) return 'Three weeks — incredible!';
    if (streak <= 29) return 'Almost a month of focus!';
    if (streak == 30) return 'One month streak! Amazing!';
    return 'Unstoppable! $streak days and counting!';
  }

  Widget _buildStreakCard(AppState appState) {
    final current = appState.currentStreak;
    final colorScheme = Theme.of(context).colorScheme;
    final hasStreak = current > 0;

    final longest = appState.longestStreak;

    return Semantics(
      label: hasStreak
          ? '$current day streak. ${_streakMessage(current)}. Best: $longest days.'
          : 'No streak yet. ${_streakMessage(current)}',
      excludeSemantics: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Emoji
              Text(
                hasStreak ? '🔥' : '💤',
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(width: 8),
            // Number + "day / streak" label
            Text(
              '$current',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 4),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'day',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                    height: 1.2,
                  ),
                ),
                Text(
                  'streak',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                    height: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            // Encouraging message
            Expanded(
              child: Text(
                _streakMessage(current),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }

  Widget _buildCheckInButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: widget.onOpenCheckIn,
        icon: const Icon(Icons.edit_note),
        label: const Text('Check In Now'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildQuickStats(AppState appState) {
    final colorScheme = Theme.of(context).colorScheme;
    final lastLog = appState.lastCheckIn;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Today',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statItem(
                  '${appState.todayOnTrackPercentage.toStringAsFixed(0)}%',
                  'On Track',
                  colorScheme,
                ),
                _statItem(
                  '${appState.todayLogCount}',
                  'Check-ins',
                  colorScheme,
                ),
              ],
            ),
            if (lastLog != null) ...[
              const Divider(height: 24),
              Text(
                'Last check-in',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    lastLog.isOnTrack ? Icons.check_circle : Icons.warning,
                    color: lastLog.isOnTrack ? Colors.green : Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Doing: ${lastLog.doingTag}  |  Should: ${lastLog.shouldDoTag}',
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _formatTimestamp(lastLog.timestamp),
                style: TextStyle(fontSize: 11, color: colorScheme.outline),
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => widget.onNavigateToStats('history'),
                child: const Text('See more'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String value, String label, ColorScheme colorScheme) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  void _showIntentionPrompt(BuildContext context, AppState appState) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set your intention'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'What do you want to focus on this session?',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'e.g. Finish the project proposal',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  appState.updateSessionIntention(value.trim());
                }
                Navigator.of(ctx).pop();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Skip'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                appState.updateSessionIntention(value);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Set intention'),
          ),
        ],
      ),
    );
  }

  void _openCustomizationSheet(BuildContext context, AppState appState) {
    showPageCustomizationSheet(
      context: context,
      pageTitle: 'Home Page',
      allSections: _allSections,
      currentOrder: appState.settings.homePageSectionOrder,
      hiddenSections: appState.settings.homePageHiddenSections,
      onChanged: (order, hidden) =>
          appState.updateHomePageLayout(order, hidden),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final screenWidth = MediaQuery.of(context).size.width;
    final useTwoColumns = screenWidth >= 768;

    if (appState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_intentionPromptShown &&
        appState.settings.hasSeenTutorial &&
        appState.settings.sessionIntention.isEmpty) {
      _intentionPromptShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showIntentionPrompt(context, appState);
      });
    }

    final settings = appState.settings;
    final visibleSections = settings.homePageSectionOrder
        .where((id) => !settings.homePageHiddenSections.contains(id))
        .map((id) => _buildSection(id, appState))
        .whereType<Widget>()
        .toList();

    final titleRow = Row(
      children: [
        const Expanded(child: TitleText(text: 'Screen Time Checkup')),
        IconButton(
          icon: const Icon(Icons.tune),
          tooltip: 'Customize layout',
          onPressed: () => _openCustomizationSheet(context, appState),
        ),
      ],
    );

    if (useTwoColumns) {
      final half = (visibleSections.length / 2).ceil();
      final leftSections = visibleSections.take(half).toList();
      final rightSections = visibleSections.skip(half).toList();

      Widget buildColumn(List<Widget> sections) {
        final items = <Widget>[];
        for (var i = 0; i < sections.length; i++) {
          if (i > 0) items.add(const SizedBox(height: 16));
          items.add(sections[i]);
        }
        return Column(children: items);
      }

      return ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          titleRow,
          const SizedBox(height: 8),
          const Text(
            'Welcome to Screen Time Checkup. Our goal is to help you regain your focus by staying aware of what you are doing.',
            style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: buildColumn(leftSections)),
              const SizedBox(width: 16),
              Expanded(child: buildColumn(rightSections)),
            ],
          ),
          const SizedBox(height: 80),
        ],
      );
    }

    final items = <Widget>[];
    for (var i = 0; i < visibleSections.length; i++) {
      if (i > 0) items.add(const SizedBox(height: 16));
      items.add(visibleSections[i]);
    }

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        titleRow,
        const SizedBox(height: 8),
        const Text(
          'Welcome to Screen Time Checkup. Our goal is to help you regain your focus by staying aware of what you are doing.',
          style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 24),
        ...items,
        const SizedBox(height: 80),
      ],
    );
  }
}
