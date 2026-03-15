import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import "package:flutter/semantics.dart";
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_selector/file_selector.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../providers/practice_log_provider.dart';
import '../repositories/recording_repository.dart';
import 'ai_practice_insights_screen.dart';
import '../utils/app_logger.dart';
import '../utils/practice_log_export.dart';
import '../utils/practice_log_utils.dart';
import '../utils/share_card_image.dart';
import '../widgets/shared/async_value_state_view.dart';

const _chartBarMaxHeight = 70.0;
const _chartBarMinHeight = 4.0;

DateTime _defaultNow() => DateTime.now();

// ── Screen ────────────────────────────────────────────────────────────────────

class PracticeLogScreen extends ConsumerStatefulWidget {
  const PracticeLogScreen({super.key, this.now = _defaultNow});

  final DateTime Function() now;

  @override
  ConsumerState<PracticeLogScreen> createState() => _PracticeLogScreenState();
}

class _PracticeLogScreenState extends ConsumerState<PracticeLogScreen>
    with SingleTickerProviderStateMixin {
  late DateTime _displayMonth;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final now = widget.now();
    _displayMonth = DateTime(now.year, now.month);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _addEntry(PracticeLogEntry entry) async {
    try {
      await ref.read(practiceLogProvider.notifier).addEntry(entry);
    } catch (e, st) {
      AppLogger.reportError('Failed to save practice log entry', error: e, stackTrace: st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save entry')),
      );
    }
  }

  // ── Add-entry dialog ──────────────────────────────────────────────────────

  Future<void> _showAddDialog() async {
    final result = await showDialog<PracticeLogEntry>(
      context: context,
      builder: (_) => const _AddEntryDialog(),
    );
    if (!mounted) return;
    if (result != null) {
      await _addEntry(result);
    }
  }

  Future<void> _exportCsv(List<PracticeLogEntry> entries) async {
    final now = DateTime.now();
    final location = await getSaveLocation(
      suggestedName:
          'practice-logs-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.csv',
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'CSV',
          extensions: ['csv'],
          mimeTypes: ['text/csv'],
        ),
      ],
    );
    if (!mounted || location == null) return;

    try {
      final csv = buildPracticeLogCsv(entries);
      final file = XFile.fromData(
        Uint8List.fromList(utf8.encode(csv)),
        mimeType: 'text/csv',
        name: 'practice-logs.csv',
      );
      await file.saveTo(location.path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV exported: ${location.path}')),
      );
    } catch (e, stackTrace) {
      AppLogger.reportError(
        'Failed to export practice logs CSV',
        error: e,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to export CSV')),
      );
    }
  }

  Future<void> _exportPdf(List<PracticeLogEntry> entries) async {
    final now = DateTime.now();
    final location = await getSaveLocation(
      suggestedName:
          'practice-logs-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.pdf',
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'PDF',
          extensions: ['pdf'],
          mimeTypes: ['application/pdf'],
        ),
      ],
    );
    if (!mounted || location == null) return;

    try {
      final file = XFile.fromData(
        buildPracticeLogPdf(entries),
        mimeType: 'application/pdf',
        name: 'practice-logs.pdf',
      );
      await file.saveTo(location.path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF exported: ${location.path}')),
      );
    } catch (e, stackTrace) {
      AppLogger.reportError(
        'Failed to export practice logs PDF',
        error: e,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to export PDF')),
      );
    }
  }

  // ── Calendar helpers ──────────────────────────────────────────────────────

  Set<int> _practiceDaysInMonth(List<PracticeLogEntry> entries, int year, int month) => entries
      .where((e) => e.date.year == year && e.date.month == month)
      .map((e) => e.date.day)
      .toSet();

  int _totalMinutesInMonth(List<PracticeLogEntry> entries, int year, int month) => entries
      .where((e) => e.date.year == year && e.date.month == month)
      .fold(0, (sum, e) => sum + e.durationMinutes);

  void _changeMonth(int delta) => setState(() {
        _displayMonth =
            DateTime(_displayMonth.year, _displayMonth.month + delta);
      });

  Future<void> _shareMonthlySummaryCard(List<PracticeLogEntry> entries) async {
    if (entries.isEmpty || !mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final practiceDays = _practiceDaysInMonth(
      entries,
      _displayMonth.year,
      _displayMonth.month,
    );
    final totalMinutes = _totalMinutesInMonth(
      entries,
      _displayMonth.year,
      _displayMonth.month,
    );
    final colorScheme = Theme.of(context).colorScheme;
    try {
      final shareCard = await generateShareCardImage(
        title: l10n.practiceLogTitle,
        lines: [
          l10n.yearMonth(_displayMonth.year, _displayMonth.month),
          '${l10n.practiceDays}: ${l10n.practiceDayCount(practiceDays.length)}',
          '${l10n.totalTime}: ${l10n.durationMinutes(totalMinutes)}',
        ],
        accentColor: colorScheme.primary,
        backgroundColor:
            Color.lerp(colorScheme.surface, colorScheme.primaryContainer, 0.08),
        surfaceColor:
            Color.lerp(colorScheme.surface, colorScheme.primaryContainer, 0.16),
        titleColor: colorScheme.onSurface,
        bodyColor: colorScheme.onSurfaceVariant,
        footerColor:
            Color.lerp(colorScheme.onSurfaceVariant, colorScheme.primary, 0.18),
      );
      await Share.shareXFiles(
        [shareCard],
        subject: l10n.practiceLogTitle,
        text: l10n.yearMonth(_displayMonth.year, _displayMonth.month),
      );
    } catch (e, stackTrace) {
      AppLogger.reportError(
        'PracticeLogScreen: failed to share practice summary card',
        error: e,
        stackTrace: stackTrace,
      );
      messenger?.showSnackBar(
        SnackBar(content: Text(l10n.recordingShareFailed)),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final practiceLogState = ref.watch(practiceLogProvider);
    final entries = practiceLogState.asData?.value ?? const <PracticeLogEntry>[];
    final isLoaded = practiceLogState.hasValue;
    final currentNow = widget.now();
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.practiceLogTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome_outlined),
            tooltip: AppLocalizations.of(context)!.aiPracticeInsightsTitle,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AiPracticeInsightsScreen(),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.share_outlined),
            tooltip: AppLocalizations.of(context)!.exportAndShare,
            onSelected: (value) {
              switch (value) {
                case 'csv':
                  _exportCsv(entries);
                  break;
                case 'pdf':
                  _exportPdf(entries);
                  break;
                case 'share':
                  _shareMonthlySummaryCard(entries);
                  break;
              }
            },
            itemBuilder: (context) {
              final l10n = AppLocalizations.of(context)!;
              return [
                PopupMenuItem<String>(
                  value: 'csv',
                  enabled: isLoaded,
                  child: Row(
                    children: [
                      const Icon(Icons.description_outlined),
                      const SizedBox(width: 12),
                      Text(l10n.exportCsv),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'pdf',
                  enabled: isLoaded,
                  child: Row(
                    children: [
                      const Icon(Icons.picture_as_pdf_outlined),
                      const SizedBox(width: 12),
                      Text(l10n.exportPdf),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'share',
                  enabled: isLoaded && entries.isNotEmpty,
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_outlined),
                      const SizedBox(width: 12),
                      Text(l10n.shareSummary),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: const Icon(Icons.calendar_month), text: AppLocalizations.of(context)!.calendarTab),
            Tab(icon: const Icon(Icons.list), text: AppLocalizations.of(context)!.recordListTab),
          ],
        ),
      ),
      body: AsyncValueStateView<List<PracticeLogEntry>>(
        value: practiceLogState,
        errorMessage: AppLocalizations.of(context)!.loadDataError,
        onRetry: () => ref.read(practiceLogProvider.notifier).reload(),
        data: (entries) => TabBarView(
          controller: _tabController,
          children: [
            _CalendarTab(
              displayMonth: _displayMonth,
              today: currentNow,
              practiceDays: _practiceDaysInMonth(
                entries,
                _displayMonth.year,
                _displayMonth.month,
              ),
              totalMinutes: _totalMinutesInMonth(
                entries,
                _displayMonth.year,
                _displayMonth.month,
              ),
              entries: entries,
              onPrev: () => _changeMonth(-1),
              onNext: () => _changeMonth(1),
            ),
            _ListTab(entries: entries),
          ],
        ),
      ),
      floatingActionButton: isLoaded
          ? FloatingActionButton(
              onPressed: _showAddDialog,
              tooltip: AppLocalizations.of(context)!.recordPractice,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

// ── Calendar tab ──────────────────────────────────────────────────────────────

class _CalendarTab extends StatelessWidget {
  const _CalendarTab({
    required this.displayMonth,
    required this.today,
    required this.practiceDays,
    required this.totalMinutes,
    required this.entries,
    required this.onPrev,
    required this.onNext,
  });

  final DateTime displayMonth;
  final DateTime today;
  final Set<int> practiceDays;
  final int totalMinutes;
  final List<PracticeLogEntry> entries;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final year = displayMonth.year;
    final month = displayMonth.month;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Month navigation header
          FocusTraversalGroup(
            policy: OrderedTraversalPolicy(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                FocusTraversalOrder(
                  order: const NumericFocusOrder(1),
                  child: Semantics(
                    sortKey: const OrdinalSortKey(1),
                    child: IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: onPrev,
                      tooltip: l10n.previousMonth,
                    ),
                  ),
                ),
                Semantics(
                  sortKey: const OrdinalSortKey(2),
                  header: true,
                  child: Text(
                    l10n.yearMonth(year, month),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                FocusTraversalOrder(
                  order: const NumericFocusOrder(3),
                  child: Semantics(
                    sortKey: const OrdinalSortKey(3),
                    child: IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: onNext,
                      tooltip: l10n.nextMonth,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _CalendarGrid(
            year: year,
            month: month,
            today: today,
            practiceDays: practiceDays,
          ),
          const SizedBox(height: 16),
          // Summary card
          Card(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _SummaryItem(
                    icon: Icons.event_available,
                    value: l10n.practiceDayCount(practiceDays.length),
                    label: l10n.practiceDays,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  _SummaryItem(
                    icon: Icons.timer,
                    value: l10n.durationMinutes(totalMinutes),
                    label: l10n.totalTime,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _AnalyticsSection(entries: entries, now: today),
        ],
      ),
    );
  }
}

class _AnalyticsSection extends StatelessWidget {
  const _AnalyticsSection({required this.entries, required this.now});

  final List<PracticeLogEntry> entries;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final weeklyTrend = buildWeeklyPracticeTrend(entries, now: now);
    final monthlyTrend = buildMonthlyPracticeTrend(entries, now: now);
    final instrumentMinutes = buildPracticeInstrumentMinutes(entries);
    final instrumentTotal = instrumentMinutes.values.fold<int>(0, (sum, value) => sum + value);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.analyticsTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _MiniBarChart(title: l10n.weeklyTrendTitle, points: weeklyTrend),
            const SizedBox(height: 16),
            _MiniBarChart(title: l10n.monthlyTrendTitle, points: monthlyTrend),
            const SizedBox(height: 16),
            Text(
              l10n.instrumentRatioTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            ...instrumentMinutes.entries.map((entry) {
              final ratio = instrumentTotal == 0 ? 0.0 : entry.value / instrumentTotal;
              final label = entry.key == otherInstrumentLabel
                  ? l10n.instrumentOtherLabel
                  : entry.key;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(label),
                        Text(l10n.durationMinutes(entry.value)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(value: ratio),
                  ],
                ),
              );
            }),
            if (instrumentMinutes.isEmpty)
              Text(
                l10n.noPracticeRecords,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (instrumentMinutes.containsKey(otherInstrumentLabel))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  l10n.instrumentRatioHint,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MiniBarChart extends StatefulWidget {
  const _MiniBarChart({
    required this.title,
    required this.points,
  });

  final String title;
  final List<PracticeTrendPoint> points;

  @override
  State<_MiniBarChart> createState() => _MiniBarChartState();
}

class _MiniBarChartState extends State<_MiniBarChart> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.points.isEmpty ? -1 : widget.points.length - 1;
  }

  @override
  void didUpdateWidget(covariant _MiniBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.points.isEmpty) {
      _selectedIndex = -1;
      return;
    }
    if (_selectedIndex < 0 || _selectedIndex >= widget.points.length) {
      _selectedIndex = widget.points.length - 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final points = widget.points;
    final maxMinutes = points.fold<int>(
      0,
      (max, point) => point.minutes > max ? point.minutes : max,
    );
    final base = maxMinutes == 0 ? 1 : maxMinutes;
    final selectedPoint =
        _selectedIndex >= 0 && _selectedIndex < points.length
            ? points[_selectedIndex]
            : null;
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: selectedPoint == null
              ? const SizedBox(height: 20)
              : Text(
                  '${selectedPoint.label} • ${l10n.durationMinutes(selectedPoint.minutes)}',
                  key: ValueKey<String>('practice-chart-selection-${selectedPoint.label}'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: points.asMap().entries.map((entry) {
              final index = entry.key;
              final point = entry.value;
              final ratio = point.minutes / base;
              final isSelected = index == _selectedIndex;
              final targetHeight = ratio == 0
                  ? 0.0
                  : ratio * _chartBarMaxHeight + _chartBarMinHeight;
              return Expanded(
                child: Semantics(
                  container: true,
                  button: true,
                  selected: isSelected,
                  label: '${point.label}, ${l10n.durationMinutes(point.minutes)}',
                  child: ExcludeSemantics(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: InkWell(
                        key: ValueKey<String>('practice-trend-bar-${point.label}'),
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => setState(() => _selectedIndex = index),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween<double>(
                                    begin: 0,
                                    end: targetHeight,
                                  ),
                                  duration: Duration(
                                    milliseconds: 320 + index * 50,
                                  ),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, animatedHeight, _) {
                                    return AnimatedContainer(
                                      duration: const Duration(milliseconds: 220),
                                      curve: Curves.easeOutCubic,
                                      width: isSelected ? 16 : 12,
                                      height: animatedHeight,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? cs.primary
                                            : cs.primary.withValues(alpha: 0.65),
                                        borderRadius: BorderRadius.circular(
                                          isSelected ? 6 : 4,
                                        ),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: cs.primary.withValues(alpha: 0.24),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ]
                                            : null,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              style:
                                  (Theme.of(context).textTheme.labelSmall ??
                                          const TextStyle(fontSize: 11))
                                      .copyWith(
                                        color: isSelected ? cs.primary : null,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                      ),
                              child: Text(
                                point.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.year,
    required this.month,
    required this.today,
    required this.practiceDays,
  });

  final int year;
  final int month;
  final DateTime today;
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
    final cs = Theme.of(context).colorScheme;
    final daysInMonth = DateUtils.getDaysInMonth(year, month);
    final firstWeekday = DateTime(year, month, 1).weekday % 7;
    final rowCount = ((firstWeekday + daysInMonth) / 7).ceil();

    return Column(
      children: [
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
                          ? cs.secondary
                          : isSaturday
                              ? cs.primary
                              : cs.onSurface,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        ...List.generate(rowCount, (row) {
          return Row(
            children: List.generate(7, (col) {
              final day = row * 7 + col - firstWeekday + 1;
              if (day < 1 || day > daysInMonth) {
                return const Expanded(child: SizedBox(height: 44));
              }
              final hasPractice = practiceDays.contains(day);
              final isToday = today.year == year &&
                  today.month == month &&
                  today.day == day;
              return Expanded(
                child: _DayCell(
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

class _DayCell extends StatelessWidget {
  const _DayCell({
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
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final textColor = isSunday
        ? cs.secondary
        : isSaturday
            ? cs.primary
            : cs.onSurface;

    final parts = <String>['$day'];
    if (isToday) parts.add(l10n.todayLabel);
    if (hasPractice) parts.add(l10n.practicedLabel);

    return Semantics(
      label: parts.join(', '),
      excludeSemantics: true,
      child: SizedBox(
        height: 44,
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (hasPractice && isToday)
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cs.primary,
                  ),
                )
              else if (hasPractice)
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cs.primaryContainer,
                  ),
                )
              else if (isToday)
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: cs.primary, width: 1.5),
                  ),
                ),
              Text(
                '$day',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      hasPractice ? FontWeight.w700 : FontWeight.normal,
                  color:
                      hasPractice && isToday ? cs.onPrimary : textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
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

// ── List tab ──────────────────────────────────────────────────────────────────

class _ListTab extends StatelessWidget {
  const _ListTab({required this.entries});

  final List<PracticeLogEntry> entries;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.music_note,
              size: 48,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.noPracticeRecords,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.addRecordHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final e = entries[i];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor:
                Theme.of(context).colorScheme.primaryContainer,
            child: Icon(
              Icons.music_note,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          title: Text(
            formatPracticeLogDate(e.date),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: e.memo.isNotEmpty ? Text(e.memo) : null,
          trailing: Text(
            l10n.durationMinutes(e.durationMinutes),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        );
      },
    );
  }
}

// ── Add entry dialog ──────────────────────────────────────────────────────────

class _AddEntryDialog extends StatefulWidget {
  const _AddEntryDialog();

  @override
  State<_AddEntryDialog> createState() => _AddEntryDialogState();
}

class _AddEntryDialogState extends State<_AddEntryDialog> {
  DateTime _date = DateTime.now();
  int _durationMinutes = 30;
  final _memoCtrl = TextEditingController();

  @override
  void dispose() {
    _memoCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.recordPractice),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date picker
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text(_formatDate(_date)),
              subtitle: Text(l10n.practiceDate),
              onTap: _pickDate,
              trailing: const Icon(Icons.edit, size: 16),
            ),
            const Divider(),
            // Duration selector
            Text(
              l10n.practiceDurationLabel(_durationMinutes),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            Slider(
              min: 5,
              max: 180,
              divisions: 35,
              label: l10n.durationMinutes(_durationMinutes),
              value: _durationMinutes.toDouble(),
              onChanged: (v) =>
                  setState(() => _durationMinutes = v.round()),
            ),
            const SizedBox(height: 4),
            // Optional note
            TextField(
              controller: _memoCtrl,
              decoration: InputDecoration(
                labelText: l10n.notesOptional,
                hintText: l10n.notesHint,
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            PracticeLogEntry(
              date: DateTime(_date.year, _date.month, _date.day),
              durationMinutes: _durationMinutes,
              memo: _memoCtrl.text.trim(),
            ),
          ),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
