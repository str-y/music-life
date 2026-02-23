import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Data model ────────────────────────────────────────────────────────────────

class _LogEntry {
  const _LogEntry({
    required this.date,
    required this.durationMinutes,
    this.note = '',
  });

  final DateTime date;
  final int durationMinutes;
  final String note;

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'durationMinutes': durationMinutes,
        'note': note,
      };

  factory _LogEntry.fromJson(Map<String, dynamic> json) => _LogEntry(
        date: DateTime.parse(json['date'] as String),
        durationMinutes: json['durationMinutes'] as int,
        note: json['note'] as String? ?? '',
      );
}

// ── Screen ────────────────────────────────────────────────────────────────────

class PracticeLogScreen extends StatefulWidget {
  const PracticeLogScreen({super.key});

  @override
  State<PracticeLogScreen> createState() => _PracticeLogScreenState();
}

class _PracticeLogScreenState extends State<PracticeLogScreen>
    with SingleTickerProviderStateMixin {
  static const _kPrefKey = 'practice_log_entries';

  List<_LogEntry> _entries = [];
  bool _loading = true;
  late DateTime _displayMonth;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final now = DateTime.now();
    _displayMonth = DateTime(now.year, now.month);
    _loadEntries();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Persistence ───────────────────────────────────────────────────────────

  Future<void> _loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kPrefKey) ?? [];
    if (!mounted) return;
    setState(() {
      _entries = raw
          .map((s) => _LogEntry.fromJson(jsonDecode(s) as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      _loading = false;
    });
  }

  Future<void> _saveEntries() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kPrefKey,
      _entries.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  Future<void> _addEntry(_LogEntry entry) async {
    setState(() {
      _entries = [entry, ..._entries]
        ..sort((a, b) => b.date.compareTo(a.date));
    });
    await _saveEntries();
  }

  // ── Add-entry dialog ──────────────────────────────────────────────────────

  Future<void> _showAddDialog() async {
    final result = await showDialog<_LogEntry>(
      context: context,
      builder: (_) => const _AddEntryDialog(),
    );
    if (result != null) {
      await _addEntry(result);
    }
  }

  // ── Calendar helpers ──────────────────────────────────────────────────────

  Set<int> _practiceDaysInMonth(int year, int month) => _entries
      .where((e) => e.date.year == year && e.date.month == month)
      .map((e) => e.date.day)
      .toSet();

  int _totalMinutesInMonth(int year, int month) => _entries
      .where((e) => e.date.year == year && e.date.month == month)
      .fold(0, (sum, e) => sum + e.durationMinutes);

  void _changeMonth(int delta) => setState(() {
        _displayMonth =
            DateTime(_displayMonth.year, _displayMonth.month + delta);
      });

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('練習ログ'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.calendar_month), text: 'カレンダー'),
            Tab(icon: Icon(Icons.list), text: '記録一覧'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _CalendarTab(
                  displayMonth: _displayMonth,
                  practiceDays: _practiceDaysInMonth(
                      _displayMonth.year, _displayMonth.month),
                  totalMinutes: _totalMinutesInMonth(
                      _displayMonth.year, _displayMonth.month),
                  onPrev: () => _changeMonth(-1),
                  onNext: () => _changeMonth(1),
                ),
                _ListTab(entries: _entries),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        tooltip: '練習を記録',
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ── Calendar tab ──────────────────────────────────────────────────────────────

class _CalendarTab extends StatelessWidget {
  const _CalendarTab({
    required this.displayMonth,
    required this.practiceDays,
    required this.totalMinutes,
    required this.onPrev,
    required this.onNext,
  });

  final DateTime displayMonth;
  final Set<int> practiceDays;
  final int totalMinutes;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final year = displayMonth.year;
    final month = displayMonth.month;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Month navigation header
          Row(
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
          ),
          const SizedBox(height: 8),
          _CalendarGrid(
            year: year,
            month: month,
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
                    value: '${practiceDays.length}日',
                    label: '練習日数',
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  _SummaryItem(
                    icon: Icons.timer,
                    value: '${totalMinutes}分',
                    label: '合計時間',
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
    final cs = Theme.of(context).colorScheme;
    final daysInMonth = DateUtils.getDaysInMonth(year, month);
    final firstWeekday = DateTime(year, month, 1).weekday % 7;
    final rowCount = ((firstWeekday + daysInMonth) / 7).ceil();

    return Column(
      children: [
        Row(
          children: _weekLabels.map((label) {
            return Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: label == '日'
                          ? Colors.red.shade400
                          : label == '土'
                              ? Colors.blue.shade400
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
    final cs = Theme.of(context).colorScheme;

    final textColor = isSunday
        ? Colors.red.shade400
        : isSaturday
            ? Colors.blue.shade400
            : cs.onSurface;

    return SizedBox(
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

  final List<_LogEntry> entries;

  String _formatDate(DateTime dt) =>
      '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
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
              '練習記録がありません',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              '＋ボタンで記録を追加しましょう',
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
            _formatDate(e.date),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: e.note.isNotEmpty ? Text(e.note) : null,
          trailing: Text(
            '${e.durationMinutes}分',
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
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('練習を記録'),
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
              subtitle: const Text('練習日'),
              onTap: _pickDate,
              trailing: const Icon(Icons.edit, size: 16),
            ),
            const Divider(),
            // Duration selector
            Text(
              '練習時間: $_durationMinutes 分',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            Slider(
              min: 5,
              max: 180,
              divisions: 35,
              label: '$_durationMinutes 分',
              value: _durationMinutes.toDouble(),
              onChanged: (v) =>
                  setState(() => _durationMinutes = v.round()),
            ),
            const SizedBox(height: 4),
            // Optional note
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: 'メモ（任意）',
                hintText: '例: スケール練習、曲の練習',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            _LogEntry(
              date: DateTime(_date.year, _date.month, _date.day),
              durationMinutes: _durationMinutes,
              note: _noteCtrl.text.trim(),
            ),
          ),
          child: const Text('保存'),
        ),
      ],
    );
  }
}
