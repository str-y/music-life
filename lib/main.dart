import 'package:flutter/material.dart';

import 'rhythm_screen.dart';
import 'screens/chord_analyser_screen.dart';

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
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('練習ログ機能は準備中です')),
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
        ],
      ),
    );
  }
}

class TunerScreen extends StatelessWidget {
  const TunerScreen({super.key});

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
              Text('A4', style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(height: 8),
              Text('440.0 Hz', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 24),
              Text(
                'マイク入力によるリアルタイム検出は今後対応予定です。',
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
