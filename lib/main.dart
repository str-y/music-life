import 'package:flutter/material.dart';

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
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('チューナー機能は準備中です')),
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
        ],
      ),
    );
  }
}
