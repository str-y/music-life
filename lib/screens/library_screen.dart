import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../utils/app_logger.dart';

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

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'recordedAt': recordedAt.toIso8601String(),
        'durationSeconds': durationSeconds,
        'waveformData': waveformData,
      };

  factory RecordingEntry.fromJson(Map<String, dynamic> json) {
    return RecordingEntry(
      id: json['id'] as String,
      title: json['title'] as String,
      recordedAt: DateTime.parse(json['recordedAt'] as String),
      durationSeconds: json['durationSeconds'] as int,
      waveformData: (json['waveformData'] as List)
          .map((e) => (e as num).toDouble())
          .toList(),
    );
  }
}

class PracticeLogEntry {
  const PracticeLogEntry({
    required this.date,
    required this.durationMinutes,
    this.memo = '',
  });

  final DateTime date;
  final int durationMinutes;
  final String memo;

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'durationMinutes': durationMinutes,
        'memo': memo,
      };

  factory PracticeLogEntry.fromJson(Map<String, dynamic> json) {
    return PracticeLogEntry(
      date: DateTime.parse(json['date'] as String),
      durationMinutes: json['durationMinutes'] as int,
      memo: json['memo'] as String? ?? '',
    );
  }
}

// ---------------------------------------------------------------------------
// Repository – persists recording metadata and practice logs via
// SharedPreferences using JSON encoding.
// ---------------------------------------------------------------------------

class RecordingRepository {
  static const _recordingsKey = 'recordings_v1';
  static const _logsKey = 'practice_logs_v1';

  Future<List<RecordingEntry>> loadRecordings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_recordingsKey);
    if (jsonStr == null) return [];
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list
          .map((e) => RecordingEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stackTrace) {
      AppLogger.reportError(
        'Failed to load recordings from storage',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> saveRecordings(List<RecordingEntry> recordings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _recordingsKey,
      jsonEncode(recordings.map((e) => e.toJson()).toList()),
    );
  }

  Future<List<PracticeLogEntry>> loadPracticeLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_logsKey);
    if (jsonStr == null) return [];
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list
          .map((e) => PracticeLogEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stackTrace) {
      AppLogger.reportError(
        'Failed to load practice logs from storage',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> savePracticeLogs(List<PracticeLogEntry> logs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _logsKey,
      jsonEncode(logs.map((e) => e.toJson()).toList()),
    );
  }
}

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
  final _repository = RecordingRepository();

  List<RecordingEntry> _recordings = [];
  List<PracticeLogEntry> _logs = [];
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final recordings = await _repository.loadRecordings();
      final logs = await _repository.loadPracticeLogs();
      if (!mounted) return;
      setState(() {
        _recordings = recordings;
        _logs = logs;
      });
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
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
        title: Text(AppLocalizations.of(context)!.libraryTitle),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: const Icon(Icons.mic), text: AppLocalizations.of(context)!.recordingsTab),
            Tab(icon: const Icon(Icons.calendar_month), text: AppLocalizations.of(context)!.logsTab),
          ],
        ),
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                semanticsLabel: AppLocalizations.of(context)!.loadingLibrary,
              ),
            )
          : _hasError
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text(
                        AppLocalizations.of(context)!.loadDataError,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _loading = true;
                            _hasError = false;
                          });
                          _loadData();
                        },
                        icon: const Icon(Icons.refresh),
                        label: Text(AppLocalizations.of(context)!.retry),
                      ),
                    ],
                  ),
                )
              : TabBarView(
              controller: _tabController,
              children: [
                _RecordingsTab(recordings: _recordings),
                _LogTab(logs: _logs),
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
  double _positionRatio = 0;
  DateTime? _playbackStart;
  Duration _playbackDuration = Duration.zero;
  Timer? _progressTicker;

  late List<RecordingEntry> _sorted;

  @override
  void initState() {
    super.initState();
    _sorted = [...widget.recordings]
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
  }

  @override
  void didUpdateWidget(_RecordingsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.recordings != oldWidget.recordings) {
      _sorted = [...widget.recordings]
        ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    }
  }

  void _startProgressTicker() {
    _progressTicker?.cancel();
    _progressTicker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted || _playingId == null || _playbackStart == null) return;
      final elapsed = DateTime.now().difference(_playbackStart!);
      final nextRatio = _playbackDuration.inMilliseconds <= 0
          ? 0.0
          : (elapsed.inMilliseconds / _playbackDuration.inMilliseconds).clamp(0.0, 1.0);
      if (nextRatio >= 1) {
        setState(() {
          _playingId = null;
          _positionRatio = 0;
          _playbackStart = null;
        });
        _progressTicker?.cancel();
        return;
      }
      setState(() {
        _positionRatio = nextRatio;
      });
    });
  }

  void _togglePlayback(String id) {
    final selected = widget.recordings.firstWhere((entry) => entry.id == id);
    setState(() {
      if (_playingId == id) {
        _playingId = null;
        _positionRatio = 0;
        _playbackStart = null;
        _progressTicker?.cancel();
        return;
      }
      _playingId = id;
      _positionRatio = 0;
      _playbackStart = DateTime.now();
      _playbackDuration = Duration(seconds: selected.durationSeconds);
    });
    _startProgressTicker();
    SystemSound.play(SystemSoundType.click);
  }

  @override
  void dispose() {
    _progressTicker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_sorted.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context)!.noRecordings,
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _sorted.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final entry = _sorted[index];
        final isPlaying = _playingId == entry.id;
        return _RecordingTile(
          entry: entry,
          isPlaying: isPlaying,
          progress: isPlaying ? _positionRatio : 0,
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
    required this.progress,
    required this.onPlayPause,
  });

  final RecordingEntry entry;
  final bool isPlaying;
  final double progress;
  final VoidCallback onPlayPause;

  String _formatDate(DateTime dt) {
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: IconButton(
            icon: Icon(isPlaying ? Icons.pause_circle : Icons.play_circle),
            iconSize: 40,
            color: colorScheme.primary,
            onPressed: onPlayPause,
            tooltip: isPlaying ? l10n.pause : l10n.play,
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _WaveformView(
                data: entry.waveformData,
                isPlaying: isPlaying,
                color: isPlaying ? colorScheme.primary : colorScheme.outlineVariant,
              ),
              if (isPlaying) ...[
                const SizedBox(height: 6),
                LinearProgressIndicator(value: progress),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Waveform painter
// ---------------------------------------------------------------------------

class _WaveformView extends StatefulWidget {
  const _WaveformView({
    required this.data,
    required this.isPlaying,
    required this.color,
  });

  final List<double> data;
  final bool isPlaying;
  final Color color;

  @override
  State<_WaveformView> createState() => _WaveformViewState();
}

class _WaveformViewState extends State<_WaveformView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathCtrl;

  /// Persistent painter instance – its internal geometry cache survives
  /// across animation frames and is only invalidated when [data] or the
  /// canvas size changes.
  late _WaveformPainter _painter;

  @override
  void initState() {
    super.initState();
    _breathCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _painter = _WaveformPainter(
      data: widget.data,
      color: widget.color,
      breathAnimation: _breathCtrl,
    );
    if (widget.isPlaying) _breathCtrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_WaveformView old) {
    super.didUpdateWidget(old);
    if (widget.isPlaying != old.isPlaying) {
      if (widget.isPlaying) {
        _breathCtrl.repeat(reverse: true);
      } else {
        _breathCtrl.stop();
        _breathCtrl.value = 0;
      }
    }
    // Recreate the painter only when static properties change so that the
    // geometry cache built up during previous frames is kept alive as long
    // as the waveform data and colour stay the same.
    if (!identical(widget.data, old.data) || widget.color != old.color) {
      _painter = _WaveformPainter(
        data: widget.data,
        color: widget.color,
        breathAnimation: _breathCtrl,
      );
    }
  }

  @override
  void dispose() {
    _breathCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppLocalizations.of(context)!.waveformSemanticLabel,
      excludeSemantics: true,
      child: SizedBox(
        height: 48,
        // No AnimatedBuilder needed – the painter re-draws itself via the
        // repaint notifier (breathAnimation) passed to CustomPainter.
        child: CustomPaint(
          painter: _painter,
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.data,
    required this.color,
    required Animation<double> breathAnimation,
  })  : _breathAnimation = breathAnimation,
        super(repaint: breathAnimation);

  final List<double> data;
  final Color color;
  final Animation<double> _breathAnimation;

  // ── Geometry cache ──────────────────────────────────────────────────────
  // Recomputed only when [data] or the canvas [Size] changes; untouched by
  // the per-frame breath animation.
  List<double>? _cachedXPositions;
  List<double>? _cachedBaseHeights;
  double? _cachedCenterY;
  Size? _cachedSize;
  List<double>? _cachedData;

  void _rebuildGeometry(Size size) {
    final barCount = data.length;
    final barWidth = size.width / (barCount * 1.6);
    final gap = barWidth * 0.6;
    final step = barWidth + gap;
    final centerY = size.height / 2;
    _cachedXPositions =
        List.generate(barCount, (i) => i * step + barWidth / 2);
    _cachedBaseHeights =
        List.generate(barCount, (i) => data[i] * centerY);
    _cachedCenterY = centerY;
    _cachedSize = size;
    _cachedData = data;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    // Rebuild the layout cache only when the waveform data or canvas size
    // has changed; the breathing animation alone does not trigger this.
    if (!identical(_cachedData, data) || _cachedSize != size) {
      _rebuildGeometry(size);
    }

    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.5;

    final centerY = _cachedCenterY!;
    final breathScale = 1.0 + _breathAnimation.value * 0.22;
    final xs = _cachedXPositions!;
    final baseHeights = _cachedBaseHeights!;
    final barCount = data.length;

    for (var i = 0; i < barCount; i++) {
      final halfHeight = (baseHeights[i] * breathScale).clamp(2.0, centerY);
      canvas.drawLine(
        Offset(xs[i], centerY - halfHeight),
        Offset(xs[i], centerY + halfHeight),
        paint,
      );
    }
  }

  @override
  // [data] is treated as an immutable list: callers must pass a new list
  // reference rather than mutating in place to trigger a cache rebuild.
  bool shouldRepaint(_WaveformPainter old) =>
      old.color != color || !identical(old.data, data);
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

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
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
    final l10n = AppLocalizations.of(context)!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _SummaryItem(
              icon: Icons.event_available,
              value: l10n.practiceDayCount(practiceDayCount),
              label: l10n.practiceDays,
              color: colorScheme.primary,
            ),
            _SummaryItem(
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
