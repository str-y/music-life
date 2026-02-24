import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import 'l10n/app_localizations.dart';
import 'native_pitch_bridge.dart';
import 'screens/library_screen.dart';
import 'screens/tuner_screen.dart';
import 'screens/practice_log_screen.dart';
import 'rhythm_screen.dart';
import 'screens/chord_analyser_screen.dart';
import 'screens/composition_helper_screen.dart';

const String _privacyPolicyUrl =
    'https://str-y.github.io/music-life/privacy-policy';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
    required super.child,
    required this.onChanged,
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

  static const _kDarkMode = 'darkMode';
  static const _kReferencePitch = 'referencePitch';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _settings = _AppSettings(
        darkMode: prefs.getBool(_kDarkMode) ?? false,
        referencePitch: prefs.getDouble(_kReferencePitch) ?? 440.0,
      );
    });
  }

  Future<void> _updateSettings(_AppSettings updated) async {
    setState(() => _settings = updated);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDarkMode, updated.darkMode);
    await prefs.setDouble(_kReferencePitch, updated.referencePitch);
  }

  @override
  Widget build(BuildContext context) {
    return _AppSettingsScope(
      settings: _settings,
      onChanged: _updateSettings,
      child: MaterialApp(
        onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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
    final l10n = AppLocalizations.of(context)!;
    final entranceCurve = CurvedAnimation(
      parent: _entranceCtrl,
      curve: Curves.easeOutCubic,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: l10n.settingsTooltip,
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
                l10n.welcomeTitle,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.welcomeSubtitle,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.tune),
                  title: Text(l10n.tunerTitle),
                  subtitle: Text(l10n.tunerSubtitle),
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
                  title: Text(l10n.practiceLogTitle),
                  subtitle: Text(l10n.practiceLogSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    _slideUpRoute<void>(
                      builder: (_) => const PracticeLogScreen(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.library_music),
                  title: Text(l10n.libraryTitle),
                  subtitle: Text(l10n.librarySubtitle),
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
                  title: Text(l10n.rhythmTitle),
                  subtitle: Text(l10n.rhythmSubtitle),
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
                  title: Text(l10n.chordAnalyserTitle),
                  subtitle: Text(l10n.chordAnalyserSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final status = await Permission.microphone.request();
                    if (!context.mounted) return;
                    if (status.isPermanentlyDenied) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.micPermissionDenied),
                          action: SnackBarAction(
                            label: l10n.openSettings,
                            onPressed: openAppSettings,
                          ),
                        ),
                      );
                      return;
                    }
                    if (!status.isGranted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.micPermissionRequired),
                        ),
                      );
                      return;
                    }
                    final bridge = NativePitchBridge();
                    final hasPermission = await bridge.startCapture();
                    if (!hasPermission) {
                      bridge.dispose();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.micPermissionRequired),
                          ),
                        );
                      }
                      return;
                    }
                    if (!context.mounted) {
                      bridge.dispose();
                      return;
                    }
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
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.piano_outlined),
                  title: Text(l10n.compositionHelperTitle),
                  subtitle: Text(l10n.compositionHelperSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    _slideUpRoute<void>(
                      builder: (_) => const CompositionHelperScreen(),
                    ),
                  ),
                ),
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
    final l10n = AppLocalizations.of(context)!;
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
          Text(l10n.settingsTitle, style: textTheme.titleLarge),
          const SizedBox(height: 24),
          Text(l10n.themeSection, style: textTheme.titleSmall),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.darkMode),
            value: _local.darkMode,
            onChanged: (v) => _emit(_local.copyWith(darkMode: v)),
          ),
          const Divider(height: 32),
          Text(l10n.calibration, style: textTheme.titleSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(l10n.referencePitchLabel),
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
            title: Text(l10n.privacyPolicy),
            trailing: const Icon(Icons.open_in_new),
            onTap: () async {
              final uri = Uri.parse(_privacyPolicyUrl);
              if (!await launchUrl(uri,
                  mode: LaunchMode.externalApplication)) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(l10n.privacyPolicyOpenError)),
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
