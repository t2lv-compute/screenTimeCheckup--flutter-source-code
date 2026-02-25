import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class OnTrackBarChart extends StatelessWidget {
  final Map<int, double> data;
  final String Function(int) labelX;
  final int totalSlots;
  final double? averageY;
  final double barWidth;

  const OnTrackBarChart({
    super.key,
    required this.data,
    required this.labelX,
    required this.totalSlots,
    this.averageY,
    this.barWidth = 14.0,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (data.isEmpty) {
      return const SizedBox(
        height: 220,
        child: Center(
          child: Text(
            'No data for this period',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    final extraLines = <HorizontalLine>[];
    final additionalYLabels = <double>[];
    if (averageY != null) {
      extraLines.add(HorizontalLine(
        y: averageY!,
        color: colorScheme.primary.withValues(alpha: 0.7),
        strokeWidth: 1.5,
        dashArray: [6, 4],
        label: HorizontalLineLabel(
          show: true,
          alignment: Alignment.topRight,
          labelResolver: (_) =>
              '${(averageY! * 100).toStringAsFixed(0)}% avg',
          style: TextStyle(
            color: colorScheme.primary,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ));
      additionalYLabels.add(averageY!);
    }

    return SizedBox(
      height: 220,
      child: Padding(
        padding: const EdgeInsets.only(right: 16, top: 16),
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: 1.0,
            minY: 0.0,
            extraLinesData: ExtraLinesData(horizontalLines: extraLines),
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (group) =>
                    colorScheme.surfaceContainerHighest,
                tooltipPadding: const EdgeInsets.all(8),
                tooltipMargin: 8,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final percentage = (rod.toY * 100).toStringAsFixed(0);
                  return BarTooltipItem(
                    '${labelX(group.x)}\n$percentage% on track',
                    TextStyle(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    // For 24-slot charts show every 3; for ≤7 show all
                    if (totalSlots > 7 && value.toInt() % 3 != 0) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        labelX(value.toInt()),
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                    );
                  },
                  reservedSize: 28,
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final labelValues = {0.0, 0.5, 1.0, ...additionalYLabels};
                    if (labelValues.any((v) => (v - value).abs() < 0.01)) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          '${(value * 100).toInt()}%',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                  reservedSize: 36,
                ),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 0.25,
              getDrawingHorizontalLine: (value) => FlLine(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                strokeWidth: 1,
              ),
            ),
            barGroups: _buildBarGroups(colorScheme),
          ),
        ),
      ),
    );
  }

  List<BarChartGroupData> _buildBarGroups(ColorScheme colorScheme) {
    final groups = <BarChartGroupData>[];
    for (int slot = 0; slot < totalSlots; slot++) {
      final value = data[slot];
      if (value != null) {
        groups.add(
          BarChartGroupData(
            x: slot,
            barRods: [
              BarChartRodData(
                toY: value,
                color: _barColor(value),
                width: barWidth,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: 1.0,
                  color: colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        );
      }
    }
    return groups;
  }

  Color _barColor(double value) {
    if (value >= 0.7) return Colors.green;
    if (value >= 0.4) return Colors.orange;
    return Colors.red;
  }
}
