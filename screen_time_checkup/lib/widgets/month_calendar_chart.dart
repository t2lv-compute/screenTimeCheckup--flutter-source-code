import 'package:flutter/material.dart';

class MonthCalendarChart extends StatelessWidget {
  final int year;
  final int month;
  final Map<int, double> data; // day-of-month → 0.0–1.0

  const MonthCalendarChart({
    super.key,
    required this.year,
    required this.month,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Day the 1st of this month falls on (1=Mon … 7=Sun, convert to 0-based Mon=0)
    final firstWeekday = DateTime(year, month, 1).weekday - 1; // 0=Mon
    // Total days in this month
    final daysInMonth = DateUtils.getDaysInMonth(year, month);

    const weekdayHeaders = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

    // Total cells = leading blanks + days
    final totalCells = firstWeekday + daysInMonth;
    // Round up to full weeks
    final rows = (totalCells / 7).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Weekday header row
        Row(
          children: weekdayHeaders
              .map((h) => Expanded(
                    child: Center(
                      child: Text(
                        h,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 4),
        // Calendar grid
        for (int row = 0; row < rows; row++)
          Row(
            children: List.generate(7, (col) {
              final cellIndex = row * 7 + col;
              final day = cellIndex - firstWeekday + 1;

              if (day < 1 || day > daysInMonth) {
                return const Expanded(child: SizedBox(height: 44));
              }

              final cellDate = DateTime(year, month, day);
              final isFuture = cellDate.isAfter(today);
              final value = data[day];
              final isToday = cellDate == today;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$day',
                        style: TextStyle(
                          fontSize: 10,
                          color: isToday
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                          fontWeight: isToday ? FontWeight.bold : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      _buildDayDot(
                          context, value, isFuture, isToday, colorScheme),
                    ],
                  ),
                ),
              );
            }),
          ),
      ],
    );
  }

  Widget _buildDayDot(
    BuildContext context,
    double? value,
    bool isFuture,
    bool isToday,
    ColorScheme colorScheme,
  ) {
    const minSize = 8.0;
    const maxSize = 30.0;

    if (isFuture || value == null) {
      // No data: tiny grey placeholder dot
      return Container(
        width: minSize,
        height: minSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isFuture
              ? Colors.transparent
              : colorScheme.surfaceContainerHighest,
        ),
      );
    }

    final size = minSize + (maxSize - minSize) * value;
    final color = value >= 0.7
        ? Colors.green
        : value >= 0.4
            ? Colors.orange
            : Colors.red;

    return Container(
      width: maxSize,
      height: maxSize,
      alignment: Alignment.center,
      decoration: isToday
          ? BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: colorScheme.primary,
                width: 1.5,
              ),
            )
          : null,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: value == 0.0 ? Colors.grey.shade400 : color,
        ),
      ),
    );
  }
}
