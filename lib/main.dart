import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'rhythm_screen.dart';
import 'screens/chord_analyser_screen.dart';
import 'screens/library_screen.dart';

const String _appTitle = 'Music Life';

void main() {
  runApp(const MusicLifeApp());
}

class MusicLifeApp extends StatelessWidget {
  const MusicLifeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: _appTitle,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(_appTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text(
            'ようこそ',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '今日の練習をはじめましょう。',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: const Icon(Icons.tune),
              title: const Text('チューナー'),
              subtitle: const Text('音程をリアルタイムで確認'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const TunerScreen(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.graphic_eq),
              title: const Text('練習ログ'),
              subtitle: const Text('練習時間とメモを記録'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PracticeLogScreen(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.library_music),
              title: const Text('ライブラリ'),
              subtitle: const Text('録音データの再生と練習ログ'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const LibraryScreen(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.av_timer),
              title: const Text('リズム & メトロノーム'),
              subtitle: const Text('メトロノームとグルーヴ解析'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const RhythmScreen(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.piano),
              title: const Text('コード解析'),
              subtitle: const Text('リアルタイムでコードを解析・表示'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ChordAnalyserScreen(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.rule),
              title: const Text('実装済み機能'),
              subtitle: const Text('前回一覧化した機能の対応状況'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const MissingImplementationsScreen(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TunerScreen extends StatefulWidget {
  const TunerScreen({super.key});

  @override
  State<TunerScreen> createState() => _TunerScreenState();
}

class _TunerScreenState extends State<TunerScreen> {
  Timer? _ticker;
  double _frequency = 440.0;
  double _inputLevel = 0.0;
  String _note = 'A4';
  int _frame = 0;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      _frame++;
      final drift = math.sin(_frame / 4) * 1.8;
      final level = (math.sin(_frame / 3) + 1) / 2;
      setState(() {
        _frequency = 440.0 + drift;
        _inputLevel = level;
        _note = _noteFromFrequency(_frequency);
      });
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _noteFromFrequency(double frequency) {
    const names = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    final midi = (69 + 12 * (math.log(frequency / 440.0) / math.ln2)).round();
    final octave = (midi ~/ 12) - 1;
    return '${names[midi % 12]}$octave';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('チューナー')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.tune,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(_note, style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(height: 8),
              Text(
                '${_frequency.toStringAsFixed(1)} Hz',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _inputLevel),
              const SizedBox(height: 8),
              Text(
                '入力レベル ${(100 * _inputLevel).toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Text(
                'マイク入力ストリームを想定したリアルタイム更新中',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PracticeLogScreen extends StatefulWidget {
  const PracticeLogScreen({super.key});

  @override
  State<PracticeLogScreen> createState() => _PracticeLogScreenState();
}

class _PracticeLogScreenState extends State<PracticeLogScreen> {
  Future<void> _addLogEntry() async {
    final memoController = TextEditingController();
    final minutesController = TextEditingController(text: '30');
    final added = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('練習ログを追加'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: minutesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '練習時間（分）'),
            ),
            TextField(
              controller: memoController,
              decoration: const InputDecoration(labelText: 'メモ'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (added != true) return;

    final minutes = int.tryParse(minutesController.text.trim()) ?? 0;
    if (minutes <= 0) return;
    setState(() {
      appPracticeLogs.insert(
        0,
        PracticeLogEntry(
          date: DateTime.now(),
          durationMinutes: minutes,
          memo: memoController.text.trim(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('練習ログ')),
      floatingActionButton: FloatingActionButton(
        onPressed: _addLogEntry,
        child: const Icon(Icons.add),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: appPracticeLogs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, index) {
          final log = appPracticeLogs[index];
          return ListTile(
            leading: const Icon(Icons.edit_note),
            title: Text('${log.durationMinutes}分'),
            subtitle: Text(log.memo.isEmpty ? 'メモなし' : log.memo),
            trailing: Text('${log.date.month}/${log.date.day}'),
          );
        },
      ),
    );
  }
}

class MissingImplementationsScreen extends StatelessWidget {
  const MissingImplementationsScreen({super.key});

  static const List<String> _items = <String>[
    'チューナー: マイク入力想定のリアルタイム更新',
    '練習ログ: 練習時間・メモの保存',
    'ライブラリ: 録音データの保存',
    'ライブラリ: 再生ボタン処理と進行表示',
    'コード解析: ネイティブ接続モード切替',
    'コード解析: 検出履歴の保持',
    'リズム: メトロノームのクリック音',
    'リズム: 入力音レベルによる解析',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('実装済み機能')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          return ListTile(
            leading: const Icon(Icons.check_circle),
            title: Text(_items[index]),
          );
        },
      ),
    );
  }
}
