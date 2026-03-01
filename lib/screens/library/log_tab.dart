import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/library_provider.dart';

// ---------------------------------------------------------------------------
// Log (Calendar) tab
// ---------------------------------------------------------------------------

class LogTab extends StatefulWidget {
  const LogTab({
    super.key,
    required this.monthlyLogStatsByMonth,
    this.onRecordPractice,
  });

  final Map<String, MonthlyPracticeStats> monthlyLogStatsByMonth;
  final VoidCallback? onRecordPractice;

  @override
  State<LogTab> createState() => _LogTabState();
}

class _LogTabState extends State<LogTab> {
  late DateTime _displayMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _displayMonth = DateTime(now.year, now.month);
  }

  void _changeMonth(int delta) {
    setState(() {
      _displayMonth =
          DateTime(_displayMonth.year, _displayMonth.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.monthlyLogStatsByMonth.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.insights_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.noPracticeRecords,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.addRecordHint,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: widget.onRecordPractice,
                icon: const Icon(Icons.edit_note),
                label: Text(l10n.recordPractice),
              ),
            ],
          ),
        ),
      );
    }

    final year = _displayMonth.year;
    final month = _displayMonth.month;
    final monthKey = '$year-${month.toString().padLeft(2, '0')}';
    final monthlyStats = widget.monthlyLogStatsByMonth[monthKey];
    final practiceDays = monthlyStats?.practiceDays ?? const <int>{};
    final totalMinutes = monthlyStats?.totalMinutes ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          MonthHeader(
            year: year,
            month: month,
            onPrev: () => _changeMonth(-1),
            onNext: () => _changeMonth(1),
          ),
          const SizedBox(height: 8),
          CalendarGrid(
            year: year,
            month: month,
            practiceDays: practiceDays,
          ),
          const SizedBox(height: 16),
          PracticeSummary(
            practiceDayCount: practiceDays.length,
            totalMinutes: totalMinutes,
          ),
        ],
      ),
    );
  }
}

class MonthHeader extends StatelessWidget {
  const MonthHeader({
    super.key,
    required this.year,
    required this.month,
    required this.onPrev,
    required this.onNext,
  });

  final int year;
  final int month;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: onPrev,
          tooltip: l10n.previousMonth,
        ),
        Text(
          l10n.yearMonth(year, month),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: onNext,
          tooltip: l10n.nextMonth,
        ),
      ],
    );
  }
}

class CalendarGrid extends StatelessWidget {
  const CalendarGrid({
    super.key,
    required this.year,
    required this.month,
    required this.practiceDays,
  });

  final int year;
  final int month;
  final Set<int> practiceDays;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final weekLabels = [
      l10n.weekdaySun,
      l10n.weekdayMon,
      l10n.weekdayTue,
      l10n.weekdayWed,
      l10n.weekdayThu,
      l10n.weekdayFri,
      l10n.weekdaySat,
    ];
    final colorScheme = Theme.of(context).colorScheme;
    final daysInMonth = DateUtils.getDaysInMonth(year, month);
    // Day-of-week index for the 1st (0 = Sunday)
    final firstWeekday = DateTime(year, month, 1).weekday % 7;

    final totalCells = firstWeekday + daysInMonth;
    final rowCount = (totalCells / 7).ceil();

    return Column(
      children: [
        // Weekday header row
        Row(
          children: weekLabels.asMap().entries.map((entry) {
            final index = entry.key;
            final label = entry.value;
            final isSunday = index == 0;
            final isSaturday = index == 6;
            return Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: isSunday
                          ? colorScheme.secondary
                          : isSaturday
                              ? colorScheme.primary
                              : colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        // Date rows
        ...List.generate(rowCount, (row) {
          return Row(
            children: List.generate(7, (col) {
              final cellIndex = row * 7 + col;
              final day = cellIndex - firstWeekday + 1;
              if (day < 1 || day > daysInMonth) {
                return const Expanded(child: SizedBox(height: 44));
              }
              final hasPractice = practiceDays.contains(day);
              final isToday = DateTime.now().year == year &&
                  DateTime.now().month == month &&
                  DateTime.now().day == day;
              return Expanded(
                child: DayCell(
                  day: day,
                  hasPractice: hasPractice,
                  isToday: isToday,
                  isSunday: col == 0,
                  isSaturday: col == 6,
                ),
              );
            }),
          );
        }),
      ],
    );
  }
}

class DayCell extends StatelessWidget {
  const DayCell({
    super.key,
    required this.day,
    required this.hasPractice,
    required this.isToday,
    required this.isSunday,
    required this.isSaturday,
  });

  final int day;
  final bool hasPractice;
  final bool isToday;
  final bool isSunday;
  final bool isSaturday;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Color textColor;
    if (isSunday) {
      textColor = colorScheme.secondary;
    } else if (isSaturday) {
      textColor = colorScheme.primary;
    } else {
      textColor = colorScheme.onSurface;
    }

    return SizedBox(
      height: 44,
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (isToday)
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: colorScheme.primary, width: 1.5),
                ),
              ),
            if (hasPractice && !isToday)
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.primaryContainer,
                ),
              ),
            if (hasPractice && isToday)
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.primary,
                ),
              ),
            Text(
              '$day',
              style: TextStyle(
                fontSize: 14,
                fontWeight:
                    hasPractice ? FontWeight.w700 : FontWeight.normal,
                color: hasPractice && isToday
                    ? colorScheme.onPrimary
                    : textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PracticeSummary extends StatelessWidget {
  const PracticeSummary({
    super.key,
    required this.practiceDayCount,
    required this.totalMinutes,
  });

  final int practiceDayCount;
  final int totalMinutes;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            SummaryItem(
              icon: Icons.event_available,
              value: l10n.practiceDayCount(practiceDayCount),
              label: l10n.practiceDays,
              color: colorScheme.primary,
            ),
            SummaryItem(
              icon: Icons.timer,
              value: l10n.durationMinutes(totalMinutes),
              label: l10n.totalTime,
              color: colorScheme.secondary,
            ),
          ],
        ),
      ),
    );
  }
}

class SummaryItem extends StatelessWidget {
  const SummaryItem({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}
