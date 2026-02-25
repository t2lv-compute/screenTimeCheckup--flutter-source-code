import 'package:flutter/material.dart';
import '../providers/app_state.dart';
import 'on_track_bar_chart.dart';
import 'month_calendar_chart.dart';

class OnTrackTrendChart extends StatefulWidget {
  final AppState appState;

  const OnTrackTrendChart({super.key, required this.appState});

  @override
  State<OnTrackTrendChart> createState() => _OnTrackTrendChartState();
}

class _OnTrackTrendChartState extends State<OnTrackTrendChart> {
  String _period = 'day';
  DateTime _cursor = DateTime.now();

  bool get _isCurrentPeriod {
    final now = DateTime.now();
    if (_period == 'day') {
      return _cursor.year == now.year &&
          _cursor.month == now.month &&
          _cursor.day == now.day;
    }
    if (_period == 'week') {
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final cursorMonday =
          _cursor.subtract(Duration(days: _cursor.weekday - 1));
      return cursorMonday.year == monday.year &&
          cursorMonday.month == monday.month &&
          cursorMonday.day == monday.day;
    }
    // month
    return _cursor.year == now.year && _cursor.month == now.month;
  }

  void _goBack() {
    setState(() {
      if (_period == 'day') {
        _cursor = _cursor.subtract(const Duration(days: 1));
      } else if (_period == 'week') {
        _cursor = _cursor.subtract(const Duration(days: 7));
      } else {
        // month: subtract one month
        var m = _cursor.month - 1;
        var y = _cursor.year;
        if (m < 1) {
          m = 12;
          y--;
        }
        _cursor = DateTime(y, m, 1);
      }
    });
  }

  void _goForward() {
    setState(() {
      if (_period == 'day') {
        _cursor = _cursor.add(const Duration(days: 1));
      } else if (_period == 'week') {
        _cursor = _cursor.add(const Duration(days: 7));
      } else {
        var m = _cursor.month + 1;
        var y = _cursor.year;
        if (m > 12) {
          m = 1;
          y++;
        }
        _cursor = DateTime(y, m, 1);
      }
    });
  }

  String _periodLabel() {
    if (_period == 'day') {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final dow = days[_cursor.weekday - 1];
      final mon = months[_cursor.month - 1];
      return '$dow ${_cursor.day} $mon ${_cursor.year}';
    }
    if (_period == 'week') {
      final monday = _cursor.subtract(Duration(days: _cursor.weekday - 1));
      final sunday = monday.add(const Duration(days: 6));
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      if (monday.month == sunday.month) {
        return '${monday.day}–${sunday.day} ${months[monday.month - 1]} ${monday.year}';
      }
      return '${monday.day} ${months[monday.month - 1]} – ${sunday.day} ${months[sunday.month - 1]} ${sunday.year}';
    }
    // month
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[_cursor.month - 1]} ${_cursor.year}';
  }

  String _formatHour(int hour) {
    if (hour == 0) return '12a';
    if (hour == 12) return '12p';
    if (hour < 12) return '${hour}a';
    return '${hour - 12}p';
  }

  String _formatDayAbbr(int weekdayIndex) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    if (weekdayIndex < 0 || weekdayIndex >= days.length) return '';
    return days[weekdayIndex];
  }

  double? _average(Map<int, double> data) {
    if (data.isEmpty) return null;
    return data.values.reduce((a, b) => a + b) / data.values.length;
  }

  Widget _buildChartBody() {
    final appState = widget.appState;
    if (_period == 'day') {
      final data = appState.hourlyOnTracknessForDay(_cursor);
      return OnTrackBarChart(
        data: data,
        labelX: _formatHour,
        totalSlots: 24,
        averageY: _average(data),
      );
    }
    if (_period == 'week') {
      final data = appState.dailyOnTracknessForWeek(_cursor);
      return OnTrackBarChart(
        data: data,
        labelX: _formatDayAbbr,
        totalSlots: 7,
        averageY: _average(data),
        barWidth: 28,
      );
    }
    // month
    return MonthCalendarChart(
      year: _cursor.year,
      month: _cursor.month,
      data: appState.dailyOnTracknessForMonth(_cursor.year, _cursor.month),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Period selector
        Center(
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'day', label: Text('Day')),
              ButtonSegment(value: 'week', label: Text('Week')),
              ButtonSegment(value: 'month', label: Text('Month')),
            ],
            selected: {_period},
            onSelectionChanged: (selection) {
              setState(() {
                _period = selection.first;
                _cursor = DateTime.now();
              });
            },
          ),
        ),
        const SizedBox(height: 12),
        // Chart body
        _buildChartBody(),
        const SizedBox(height: 8),
        // Navigation row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: _goBack,
              tooltip: 'Previous',
            ),
            Expanded(
              child: Text(
                _periodLabel(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: _isCurrentPeriod ? null : _goForward,
              tooltip: 'Next',
            ),
          ],
        ),
      ],
    );
  }
}
