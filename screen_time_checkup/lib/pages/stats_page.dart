import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/log_entry.dart';
import '../providers/app_state.dart';
import '../widgets/title_text.dart';
import '../widgets/on_track_trend_chart.dart';
import '../widgets/key_stats_card.dart';
import '../widgets/page_customization_sheet.dart';

class StatsPage extends StatefulWidget {
  final String? initialScrollTarget;

  const StatsPage({super.key, this.initialScrollTarget});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  final ScrollController _scrollController = ScrollController();

  final GlobalKey _trendChartKey = GlobalKey();
  final GlobalKey _keyStatsKey = GlobalKey();
  final GlobalKey _historyKey = GlobalKey();

  // Hidden party mode trigger
  int _titleTapCount = 0;
  DateTime? _lastTapTime;

  static const List<SectionConfig> _allSections = [
    SectionConfig(id: 'trendChart', label: 'On-Track Trend'),
    SectionConfig(id: 'keyStats', label: 'Key Statistics'),
    SectionConfig(id: 'history', label: 'Check-in History'),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialScrollTarget != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleScrollTarget(widget.initialScrollTarget!);
      });
    }
  }

  @override
  void didUpdateWidget(covariant StatsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialScrollTarget != null &&
        widget.initialScrollTarget != oldWidget.initialScrollTarget) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleScrollTarget(widget.initialScrollTarget!);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScrollTarget(String target) {
    switch (target) {
      case 'overview':
      case 'trendChart':
        _scrollToSection(_trendChartKey);
      case 'tagBreakdown':
      case 'keyStats':
        _scrollToSection(_keyStatsKey);
      case 'history':
        _scrollToSection(_historyKey);
    }
  }

  void _onTitleTap(AppState appState) {
    final now = DateTime.now();
    if (_lastTapTime != null && now.difference(_lastTapTime!).inMilliseconds > 500) {
      _titleTapCount = 0;
    }
    _lastTapTime = now;
    _titleTapCount++;

    if (_titleTapCount >= 3) {
      _titleTapCount = 0;
      appState.togglePartyMode();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(appState.settings.partyMode
              ? 'Party Mode Activated!'
              : 'Party Mode Deactivated!'),
          backgroundColor: appState.settings.partyMode
              ? Colors.purple
              : Colors.grey,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _scrollToSection(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = key.currentContext;
      if (context != null) {
        final box = context.findRenderObject() as RenderBox?;
        if (box != null) {
          final position = box.localToGlobal(Offset.zero);
          final targetOffset = _scrollController.offset + position.dy - 15.0;
          _scrollController.animateTo(
            targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      }
    });
  }

  Widget? _buildSection(String id, AppState appState) {
    switch (id) {
      case 'trendChart':
        return _buildTrendChartSection(appState);
      case 'keyStats':
        return _buildKeyStatsSection(appState);
      case 'history':
        return _buildHistorySection(appState);
      default:
        return null;
    }
  }

  Widget _buildTrendChartSection(AppState appState) {
    return ExpansionTile(
      key: _trendChartKey,
      title: const Text(
        'On-Track Trend',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      initiallyExpanded: true,
      onExpansionChanged: (expanded) {
        if (expanded) _scrollToSection(_trendChartKey);
      },
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: OnTrackTrendChart(appState: appState),
        ),
      ],
    );
  }

  Widget _buildKeyStatsSection(AppState appState) {
    if (appState.totalLogs == 0) {
      return ExpansionTile(
        key: _keyStatsKey,
        title: const Text(
          'Key Statistics',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        initiallyExpanded: true,
        children: const [
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'No check-ins yet. Start logging to see your statistics!',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      );
    }

    return ExpansionTile(
      key: _keyStatsKey,
      title: const Text(
        'Key Statistics',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      initiallyExpanded: true,
      onExpansionChanged: (expanded) {
        if (expanded) _scrollToSection(_keyStatsKey);
      },
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: KeyStatsCard(
            totalLogs: appState.totalLogs,
            onTrackCount: appState.onTrackCount,
            missedCheckIns: appState.missedCheckInCount,
            onTrackPercentage: appState.onTrackPercentage,
            currentStreak: appState.currentStreak,
            longestStreak: appState.longestStreak,
            quickResponsePercentage: appState.quickResponsePercentage,
            notificationResponseCount: appState.notificationResponseCount,
            tagGoalCount: appState.tagGoalCount,
            tagOnTrackCount: appState.tagOnTrackCount,
            mostCommonDistractionTag: appState.mostCommonDistractionTag,
            mostProductiveHour: appState.mostProductiveHour,
            leastProductiveHour: appState.leastProductiveHour,
          ),
        ),
      ],
    );
  }

  Widget _buildHistorySection(AppState appState) {
    if (appState.totalLogs == 0) {
      return const SizedBox.shrink();
    }
    return ExpansionTile(
      key: _historyKey,
      title: Text('Check-in History (${appState.totalLogs})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      initiallyExpanded: true,
      onExpansionChanged: (expanded) {
        if (expanded) _scrollToSection(_historyKey);
      },
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              ...appState.displayedLogs.map((log) {
                if (log.isMissed) {
                  return _buildMissedEntry(log);
                }
                final isOnTrack = log.isOnTrack;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => _showLogDetail(log),
                    borderRadius: BorderRadius.circular(12),
                    child: ListTile(
                      leading: Icon(
                        isOnTrack ? Icons.check_circle : Icons.warning,
                        color: isOnTrack ? Colors.green : Colors.orange,
                      ),
                      title: Text('Doing: ${log.doingTag}'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Should: ${log.shouldDoTag}'),
                          if (log.notes != null && log.notes!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                log.notes!,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          Text(
                            _formatTimestamp(log.timestamp),
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (log.importance != null)
                            Text(
                              'Importance: ${log.importance}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          if (log.intentionAdherence != null)
                            Text(
                              'Adherence: ${log.intentionAdherence}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              if (appState.hasMoreLogs)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OutlinedButton.icon(
                    onPressed: () => appState.loadMoreLogs(),
                    icon: const Icon(Icons.expand_more),
                    label: Text(
                      'Load More (${appState.totalLogs - appState.displayedLogs.length} remaining)',
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _openCustomizationSheet(BuildContext context, AppState appState) {
    showPageCustomizationSheet(
      context: context,
      pageTitle: 'Stats Page',
      allSections: _allSections,
      currentOrder: appState.settings.statsPageSectionOrder,
      hiddenSections: appState.settings.statsPageHiddenSections,
      onChanged: (order, hidden) =>
          appState.updateStatsPageLayout(order, hidden),
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

    final settings = appState.settings;
    final visibleSections = settings.statsPageSectionOrder
        .where((id) => !settings.statsPageHiddenSections.contains(id))
        .map((id) => _buildSection(id, appState))
        .whereType<Widget>()
        .toList();

    final titleRow = Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _onTitleTap(appState),
            child: const TitleText(text: 'Statistics'),
          ),
        ),
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
        controller: _scrollController,
        padding: const EdgeInsets.all(16.0),
        children: [
          titleRow,
          const SizedBox(height: 16),
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
      controller: _scrollController,
      padding: const EdgeInsets.all(16.0),
      children: [
        titleRow,
        const SizedBox(height: 16),
        ...items,
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildMissedEntry(LogEntry log) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: ListTile(
        leading: Icon(Icons.notifications_off_outlined,
            color: colorScheme.onSurfaceVariant),
        title: Text(
          'Missed check-in',
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
        subtitle: Text(
          _formatTimestamp(log.timestamp),
          style: TextStyle(fontSize: 11, color: colorScheme.outline),
        ),
      ),
    );
  }

  void _showLogDetail(LogEntry log) {
    final isOnTrack = log.isOnTrack;
    final ts = log.timestamp;
    final dateStr = '${ts.year}-${ts.month.toString().padLeft(2, '0')}-${ts.day.toString().padLeft(2, '0')}';
    final hour = ts.hour == 0 ? 12 : (ts.hour > 12 ? ts.hour - 12 : ts.hour);
    final period = ts.hour >= 12 ? 'PM' : 'AM';
    final timeStr = '$hour:${ts.minute.toString().padLeft(2, '0')} $period';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isOnTrack ? Icons.check_circle : Icons.warning,
              color: isOnTrack ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isOnTrack ? 'On Track' : 'Off Track',
                style: TextStyle(
                  color: isOnTrack ? Colors.green : Colors.orange,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow('Doing', log.doingTag),
            const SizedBox(height: 8),
            _detailRow('Should be doing', log.shouldDoTag),
            if (log.importance != null) ...[
              const SizedBox(height: 8),
              _detailRow('Importance', '${log.importance}/10'),
            ],
            if (log.intentionAdherence != null) ...[
              const SizedBox(height: 8),
              _detailRow('Adherence', '${log.intentionAdherence}/10'),
            ],
            const SizedBox(height: 8),
            _detailRow('Date', dateStr),
            const SizedBox(height: 8),
            _detailRow('Time', timeStr),
            if (log.responseTimeSeconds != null) ...[
              const SizedBox(height: 8),
              _detailRow('Response time', '${log.responseTimeSeconds}s'),
            ],
            if (log.notes != null && log.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(
                log.notes!,
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
      ],
    );
  }

  String _formatTimestamp(DateTime ts) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(ts.year, ts.month, ts.day);

    final hour = ts.hour == 0 ? 12 : (ts.hour > 12 ? ts.hour - 12 : ts.hour);
    final minute = ts.minute.toString().padLeft(2, '0');
    final period = ts.hour >= 12 ? 'PM' : 'AM';
    final timeStr = '$hour:$minute $period';

    if (day == today) return 'Today at $timeStr';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday at $timeStr';

    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final monthStr = months[ts.month - 1];
    if (ts.year == now.year) return '$monthStr ${ts.day} at $timeStr';
    return '$monthStr ${ts.day}, ${ts.year} at $timeStr';
  }
}
