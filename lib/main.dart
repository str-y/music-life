import 'package:flutter/material.dart';

const String _appTitle = 'Music Life';

void main() {
  runApp(const MusicLifeApp());
}

class _AppSettings {
  final bool darkMode;
  final double referencePitch;

  const _AppSettings({
    this.darkMode = false,
    this.referencePitch = 440.0,
  });

  _AppSettings copyWith({bool? darkMode, double? referencePitch}) {
    return _AppSettings(
      darkMode: darkMode ?? this.darkMode,
      referencePitch: referencePitch ?? this.referencePitch,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _AppSettings &&
          darkMode == other.darkMode &&
          referencePitch == other.referencePitch;

  @override
  int get hashCode => Object.hash(darkMode, referencePitch);
}

class _AppSettingsScope extends InheritedWidget {
  final _AppSettings settings;
  final ValueChanged<_AppSettings> onChanged;

  const _AppSettingsScope({
    required this.settings,
    required this.onChanged,
    required super.child,
  });

  static _AppSettingsScope of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_AppSettingsScope>()!;
  }

  @override
  bool updateShouldNotify(_AppSettingsScope old) => settings != old.settings;
}

class MusicLifeApp extends StatefulWidget {
  const MusicLifeApp({super.key});

  @override
  State<MusicLifeApp> createState() => _MusicLifeAppState();
}

class _MusicLifeAppState extends State<MusicLifeApp> {
  _AppSettings _settings = const _AppSettings();

  void _updateSettings(_AppSettings updated) {
    setState(() => _settings = updated);
  }

  @override
  Widget build(BuildContext context) {
    return _AppSettingsScope(
      settings: _settings,
      onChanged: _updateSettings,
      child: MaterialApp(
        title: _appTitle,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        themeMode: _settings.darkMode ? ThemeMode.dark : ThemeMode.light,
        home: const MainScreen(),
      ),
    );
  }
}

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  void _openSettings(BuildContext context) {
    final scope = _AppSettingsScope.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _SettingsModal(
        settings: scope.settings,
        onChanged: scope.onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(_appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '設定',
            onPressed: () => _openSettings(context),
          ),
        ],
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
        ],
      ),
    );
  }
}

class _SettingsModal extends StatefulWidget {
  final _AppSettings settings;
  final ValueChanged<_AppSettings> onChanged;

  const _SettingsModal({required this.settings, required this.onChanged});

  @override
  State<_SettingsModal> createState() => _SettingsModalState();
}

class _SettingsModalState extends State<_SettingsModal> {
  late _AppSettings _local;

  @override
  void initState() {
    super.initState();
    _local = widget.settings;
  }

  void _emit(_AppSettings updated) {
    setState(() => _local = updated);
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(
        top: 24,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text('設定', style: textTheme.titleLarge),
          const SizedBox(height: 24),
          Text('テーマ', style: textTheme.titleSmall),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('ダークモード'),
            value: _local.darkMode,
            onChanged: (v) => _emit(_local.copyWith(darkMode: v)),
          ),
          const Divider(height: 32),
          Text('キャリブレーション', style: textTheme.titleSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('基準ピッチ A ='),
              const SizedBox(width: 8),
              Text(
                '${_local.referencePitch.round()} Hz',
                style: textTheme.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Slider(
            min: 430,
            max: 450,
            divisions: 20,
            label: '${_local.referencePitch.round()} Hz',
            value: _local.referencePitch,
            onChanged: (v) => _emit(_local.copyWith(referencePitch: v)),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
