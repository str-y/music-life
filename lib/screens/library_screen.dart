import 'dart:math' as math;

import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------

class RecordingEntry {
  const RecordingEntry({
    required this.id,
    required this.title,
    required this.recordedAt,
    required this.durationSeconds,
    required this.waveformData,
  });

  final String id;
  final String title;
  final DateTime recordedAt;
  final int durationSeconds;

  /// Normalised amplitude values in [0.0, 1.0] used for waveform preview.
  final List<double> waveformData;

  String get formattedDuration {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

class PracticeLogEntry {
  const PracticeLogEntry({
    required this.date,
    required this.durationMinutes,
  });

  final DateTime date;
  final int durationMinutes;
}

// ---------------------------------------------------------------------------
// Sample data (placeholder until real persistence is wired up)
// ---------------------------------------------------------------------------

List<double> _fakeWaveform(int seed, int count) {
  final rng = math.Random(seed);
  return List.generate(count, (_) => 0.15 + rng.nextDouble() * 0.85);
}

final _sampleRecordings = <RecordingEntry>[
  RecordingEntry(
    id: '1',
    title: '練習セッション',
    recordedAt: DateTime(2026, 2, 23, 19, 30),
    durationSeconds: 183,
    waveformData: _fakeWaveform(1, 40),
  ),
  RecordingEntry(
    id: '2',
    title: '練習セッション',
    recordedAt: DateTime(2026, 2, 22, 18, 15),
    durationSeconds: 245,
    waveformData: _fakeWaveform(2, 40),
  ),
  RecordingEntry(
    id: '3',
    title: '練習セッション',
    recordedAt: DateTime(2026, 2, 20, 20, 0),
    durationSeconds: 97,
    waveformData: _fakeWaveform(3, 40),
  ),
  RecordingEntry(
    id: '4',
    title: '練習セッション',
    recordedAt: DateTime(2026, 2, 18, 17, 45),
    durationSeconds: 312,
    waveformData: _fakeWaveform(4, 40),
  ),
  RecordingEntry(
    id: '5',
    title: '練習セッション',
    recordedAt: DateTime(2026, 2, 15, 21, 0),
    durationSeconds: 540,
    waveformData: _fakeWaveform(5, 40),
  ),
];

final _sampleLogs = <PracticeLogEntry>[
  PracticeLogEntry(date: DateTime(2026, 2, 23), durationMinutes: 45),
  PracticeLogEntry(date: DateTime(2026, 2, 22), durationMinutes: 60),
  PracticeLogEntry(date: DateTime(2026, 2, 20), durationMinutes: 30),
  PracticeLogEntry(date: DateTime(2026, 2, 18), durationMinutes: 75),
  PracticeLogEntry(date: DateTime(2026, 2, 15), durationMinutes: 90),
  PracticeLogEntry(date: DateTime(2026, 2, 12), durationMinutes: 40),
  PracticeLogEntry(date: DateTime(2026, 2, 10), durationMinutes: 55),
  PracticeLogEntry(date: DateTime(2026, 2, 8), durationMinutes: 30),
  PracticeLogEntry(date: DateTime(2026, 2, 5), durationMinutes: 20),
  PracticeLogEntry(date: DateTime(2026, 2, 3), durationMinutes: 60),
  PracticeLogEntry(date: DateTime(2026, 2, 1), durationMinutes: 45),
];

// ---------------------------------------------------------------------------
// LibraryScreen
// ---------------------------------------------------------------------------

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ライブラリ'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.mic), text: '録音'),
            Tab(icon: Icon(Icons.calendar_month), text: 'ログ'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _RecordingsTab(recordings: _sampleRecordings),
          _LogTab(logs: _sampleLogs),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recordings tab
// ---------------------------------------------------------------------------

class _RecordingsTab extends StatefulWidget {
  const _RecordingsTab({required this.recordings});

  final List<RecordingEntry> recordings;

  @override
  State<_RecordingsTab> createState() => _RecordingsTabState();
}

class _RecordingsTabState extends State<_RecordingsTab> {
  String? _playingId;

  void _togglePlayback(String id) {
    setState(() {
      _playingId = (_playingId == id) ? null : id;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...widget.recordings]
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

    if (sorted.isEmpty) {
      return const Center(
        child: Text(
          '録音データがありません',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: sorted.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final entry = sorted[index];
        final isPlaying = _playingId == entry.id;
        return _RecordingTile(
          entry: entry,
          isPlaying: isPlaying,
          onPlayPause: () => _togglePlayback(entry.id),
        );
      },
    );
  }
}

class _RecordingTile extends StatelessWidget {
  const _RecordingTile({
    required this.entry,
    required this.isPlaying,
    required this.onPlayPause,
  });

  final RecordingEntry entry;
  final bool isPlaying;
  final VoidCallback onPlayPause;

  String _formatDate(DateTime dt) {
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: IconButton(
            icon: Icon(isPlaying ? Icons.pause_circle : Icons.play_circle),
            iconSize: 40,
            color: colorScheme.primary,
            onPressed: onPlayPause,
            tooltip: isPlaying ? '一時停止' : '再生',
          ),
          title: Text(
            entry.title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            _formatDate(entry.recordedAt),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          trailing: Text(
            entry.formattedDuration,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          onTap: onPlayPause,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(72, 0, 16, 12),
          child: _WaveformView(
            data: entry.waveformData,
            isPlaying: isPlaying,
            color: isPlaying ? colorScheme.primary : colorScheme.outlineVariant,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Waveform painter
// ---------------------------------------------------------------------------

class _WaveformView extends StatelessWidget {
  const _WaveformView({
    required this.data,
    required this.isPlaying,
    required this.color,
  });

  final List<double> data;
  final bool isPlaying;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: CustomPaint(
        painter: _WaveformPainter(data: data, color: color),
        size: Size.infinite,
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({required this.data, required this.color});

  final List<double> data;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.5;

    final barCount = data.length;
    final totalSpacing = size.width;
    final barWidth = totalSpacing / (barCount * 1.6);
    final gap = barWidth * 0.6;
    final step = barWidth + gap;
    final centerY = size.height / 2;

    for (var i = 0; i < barCount; i++) {
      final x = i * step + barWidth / 2;
      final halfHeight = (data[i] * centerY).clamp(2.0, centerY);
      canvas.drawLine(
        Offset(x, centerY - halfHeight),
        Offset(x, centerY + halfHeight),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.data != data;
}

// ---------------------------------------------------------------------------
// Log (Calendar) tab
// ---------------------------------------------------------------------------

class _LogTab extends StatefulWidget {
  const _LogTab({required this.logs});

  final List<PracticeLogEntry> logs;

  @override
  State<_LogTab> createState() => _LogTabState();
}

class _LogTabState extends State<_LogTab> {
  late DateTime _displayMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _displayMonth = DateTime(now.year, now.month);
  }

  Set<int> _practiceDaysInMonth(int year, int month) {
    return widget.logs
        .where((e) => e.date.year == year && e.date.month == month)
        .map((e) => e.date.day)
        .toSet();
  }

  int _totalMinutesInMonth(int year, int month) {
    return widget.logs
        .where((e) => e.date.year == year && e.date.month == month)
        .fold(0, (sum, e) => sum + e.durationMinutes);
  }

  void _changeMonth(int delta) {
    setState(() {
      _displayMonth =
          DateTime(_displayMonth.year, _displayMonth.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    final year = _displayMonth.year;
    final month = _displayMonth.month;
    final practiceDays = _practiceDaysInMonth(year, month);
    final totalMinutes = _totalMinutesInMonth(year, month);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _MonthHeader(
            year: year,
            month: month,
            onPrev: () => _changeMonth(-1),
            onNext: () => _changeMonth(1),
          ),
          const SizedBox(height: 8),
          _CalendarGrid(
            year: year,
            month: month,
            practiceDays: practiceDays,
          ),
          const SizedBox(height: 16),
          _PracticeSummary(
            practiceDayCount: practiceDays.length,
            totalMinutes: totalMinutes,
          ),
        ],
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: onPrev,
          tooltip: '前の月',
        ),
        Text(
          '$year年$month月',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: onNext,
          tooltip: '次の月',
        ),
      ],
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.year,
    required this.month,
    required this.practiceDays,
  });

  final int year;
  final int month;
  final Set<int> practiceDays;

  static const _weekLabels = ['日', '月', '火', '水', '木', '金', '土'];

  @override
  Widget build(BuildContext context) {
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
          children: _weekLabels.map((label) {
            final isSunday = label == '日';
            final isSaturday = label == '土';
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
                          ? Colors.red.shade400
                          : isSaturday
                              ? Colors.blue.shade400
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
    final colorScheme = Theme.of(context).colorScheme;

    Color textColor;
    if (isSunday) {
      textColor = Colors.red.shade400;
    } else if (isSaturday) {
      textColor = Colors.blue.shade400;
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

class _PracticeSummary extends StatelessWidget {
  const _PracticeSummary({
    required this.practiceDayCount,
    required this.totalMinutes,
  });

  final int practiceDayCount;
  final int totalMinutes;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _SummaryItem(
              icon: Icons.event_available,
              value: '$practiceDayCount日',
              label: '練習日数',
              color: colorScheme.primary,
            ),
            _SummaryItem(
              icon: Icons.timer,
              value: '${totalMinutes}分',
              label: '合計時間',
              color: colorScheme.secondary,
            ),
          ],
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
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Colors.grey),
        ),
      ],
    );
  }
}
