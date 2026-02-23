import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'native_pitch_bridge.dart';
import 'screens/library_screen.dart';
import 'rhythm_screen.dart';
import 'screens/chord_analyser_screen.dart';

const String _appTitle = 'Music Life';
const String _privacyPolicyUrl =
    'https://str-y.github.io/music-life/privacy-policy';

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

/// A page route with a subtle slide-up + fade entrance animation.
PageRoute<T> _slideUpRoute<T>({required WidgetBuilder builder}) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, _) => builder(context),
    transitionsBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 320),
  );
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceCtrl;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

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
    final entranceCurve = CurvedAnimation(
      parent: _entranceCtrl,
      curve: Curves.easeOutCubic,
    );
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
      body: FadeTransition(
        opacity: CurvedAnimation(
          parent: _entranceCtrl,
          curve: Curves.easeOut,
        ),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(entranceCurve),
          child: ListView(
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
                    _slideUpRoute<void>(
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
                  leading: const Icon(Icons.library_music),
                  title: const Text('ライブラリ'),
                  subtitle: const Text('録音データの再生と練習ログ'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    _slideUpRoute<void>(
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
                  onTap: () => Navigator.of(context).push(
                    _slideUpRoute<void>(
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
                  onTap: () async {
                    final bridge = NativePitchBridge();
                    // Await the route so we can dispose the bridge only after
                    // the screen's own dispose() has already cancelled the
                    // subscription.
                    await Navigator.of(context).push(
                      _slideUpRoute<void>(
                        builder: (_) => ChordAnalyserScreen(
                          chordStream: bridge.chordStream,
                        ),
                      ),
                    );
                    bridge.dispose();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TunerScreen extends StatefulWidget {
  const TunerScreen({super.key});

  @override
  State<TunerScreen> createState() => _TunerScreenState();
}

class _TunerScreenState extends State<TunerScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
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
              ScaleTransition(
                scale: _pulseAnim,
                child: Icon(
                  Icons.tune,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
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
          const Divider(height: 32),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('プライバシーポリシー'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () async {
              final uri = Uri.parse(_privacyPolicyUrl);
              if (!await launchUrl(uri,
                  mode: LaunchMode.externalApplication)) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('プライバシーポリシーを開けませんでした')),
                  );
                }
              }
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
