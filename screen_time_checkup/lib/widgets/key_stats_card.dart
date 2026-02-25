import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class KeyStatsCard extends StatelessWidget {
  final int totalLogs;
  final int onTrackCount;
  final int missedCheckIns;
  final double onTrackPercentage;
  final int currentStreak;
  final int longestStreak;
  final double quickResponsePercentage;
  final int notificationResponseCount;
  final Map<String, int> tagGoalCount;
  final Map<String, int> tagOnTrackCount;
  final String? mostCommonDistractionTag;
  final int? mostProductiveHour;
  final int? leastProductiveHour;

  const KeyStatsCard({
    super.key,
    required this.totalLogs,
    required this.onTrackCount,
    required this.missedCheckIns,
    required this.onTrackPercentage,
    required this.currentStreak,
    required this.longestStreak,
    required this.quickResponsePercentage,
    required this.notificationResponseCount,
    required this.tagGoalCount,
    required this.tagOnTrackCount,
    this.mostCommonDistractionTag,
    this.mostProductiveHour,
    this.leastProductiveHour,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDonutAndMetrics(context),
        if (tagGoalCount.isNotEmpty) ...[
          const Divider(height: 32),
          _buildGoalFollowThrough(context),
        ],
      ],
    );
  }

  Widget _buildDonutAndMetrics(BuildContext context) {
    final offTrackCount = totalLogs - onTrackCount - missedCheckIns;
    final safeOffTrack = offTrackCount.clamp(0, totalLogs);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Donut chart
        SizedBox(
          height: 180,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 50,
                  sections: _buildPieSections(safeOffTrack),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${onTrackPercentage.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'on track',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _legendDot(Colors.green, 'On-track', onTrackCount),
            const SizedBox(width: 16),
            _legendDot(Colors.orange, 'Off-track', safeOffTrack),
            const SizedBox(width: 16),
            _legendDot(
                Colors.grey.shade400, 'Missed', missedCheckIns),
          ],
        ),
        const SizedBox(height: 16),
        // Metric cards
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _metricCard(
              context,
              icon: Icons.receipt_long,
              value: totalLogs.toString(),
              label: 'Total check-ins',
            ),
            _metricCard(
              context,
              icon: Icons.local_fire_department,
              value: '$currentStreak day${currentStreak == 1 ? '' : 's'}',
              label: 'Current streak',
              iconColor: Colors.deepOrange,
            ),
            _metricCard(
              context,
              icon: Icons.emoji_events,
              value: '$longestStreak day${longestStreak == 1 ? '' : 's'}',
              label: 'Longest streak',
              iconColor: Colors.amber,
            ),
            _metricCard(
              context,
              icon: Icons.timer,
              value: '${quickResponsePercentage.toStringAsFixed(1)}%',
              label: 'Response rate',
              progress: quickResponsePercentage / 100,
            ),
            _metricCard(
              context,
              icon: Icons.warning_amber_rounded,
              value: mostCommonDistractionTag ?? '–',
              label: 'Top distraction',
              iconColor: Colors.orange,
              smallValue: mostCommonDistractionTag != null,
            ),
            _metricCard(
              context,
              icon: Icons.trending_up,
              value: mostProductiveHour != null
                  ? _formatHour(mostProductiveHour!)
                  : '–',
              label: 'Best hour',
              iconColor: Colors.green,
            ),
            _metricCard(
              context,
              icon: Icons.trending_down,
              value: leastProductiveHour != null
                  ? _formatHour(leastProductiveHour!)
                  : '–',
              label: 'Worst hour',
              iconColor: Colors.red,
            ),
          ],
        ),
      ],
    );
  }

  static String _formatHour(int hour) {
    if (hour == 0) return '12 AM';
    if (hour == 12) return '12 PM';
    return hour < 12 ? '$hour AM' : '${hour - 12} PM';
  }

  List<PieChartSectionData> _buildPieSections(int offTrackCount) {
    final total = totalLogs;
    if (total == 0) {
      return [
        PieChartSectionData(
          value: 1,
          color: Colors.grey.shade300,
          radius: 40,
          showTitle: false,
        ),
      ];
    }

    final sections = <PieChartSectionData>[];
    if (onTrackCount > 0) {
      sections.add(PieChartSectionData(
        value: onTrackCount.toDouble(),
        color: Colors.green,
        radius: 40,
        showTitle: false,
      ));
    }
    if (offTrackCount > 0) {
      sections.add(PieChartSectionData(
        value: offTrackCount.toDouble(),
        color: Colors.orange,
        radius: 40,
        showTitle: false,
      ));
    }
    if (missedCheckIns > 0) {
      sections.add(PieChartSectionData(
        value: missedCheckIns.toDouble(),
        color: Colors.grey.shade400,
        radius: 40,
        showTitle: false,
      ));
    }
    return sections;
  }

  Widget _legendDot(Color color, String label, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$label ($count)',
          style: const TextStyle(fontSize: 11),
        ),
      ],
    );
  }

  Widget _metricCard(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    Color? iconColor,
    double? progress,
    bool smallValue = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: iconColor ?? colorScheme.primary),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: smallValue ? 13 : 18,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (progress != null) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress >= 0.7
                      ? Colors.green
                      : progress >= 0.4
                          ? Colors.orange
                          : Colors.red,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGoalFollowThrough(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sorted = tagGoalCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Goal Follow-Through',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 12),
        ...sorted.map((entry) {
          final tag = entry.key;
          final total = entry.value;
          final onTrack = tagOnTrackCount[tag] ?? 0;
          final pct = total > 0 ? onTrack / total : 0.0;
          final color = pct >= 0.7
              ? Colors.green
              : pct >= 0.4
                  ? Colors.orange
                  : Colors.red;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        tag,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Text(
                      '$onTrack/$total',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 40,
                      child: Text(
                        '${(pct * 100).toStringAsFixed(0)}%',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: isDark
                        ? Colors.grey.shade700
                        : Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 12,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
