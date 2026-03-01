import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'data/app_database.dart';
import 'l10n/app_localizations.dart';
import 'providers/app_settings_provider.dart';
import 'providers/dependency_providers.dart';
import 'router/app_router.dart';
import 'utils/app_logger.dart';

const Map<String, Color> _keyThemeColors = <String, Color>{
  'C': Colors.red,
  'C#': Colors.deepOrange,
  'Db': Colors.deepOrange,
  'D': Colors.orange,
  'D#': Colors.amber,
  'Eb': Colors.amber,
  'E': Colors.yellow,
  'F': Colors.green,
  'F#': Colors.teal,
  'Gb': Colors.teal,
  'G': Colors.blue,
  'G#': Colors.indigo,
  'Ab': Colors.indigo,
  'A': Colors.purple,
  'A#': Colors.pink,
  'Bb': Colors.pink,
  'B': Colors.cyan,
};

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await MobileAds.instance.initialize();
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.stry.musiclife.audio',
      androidNotificationChannelName: 'Music Life Playback',
      androidNotificationOngoing: true,
    );
  } catch (e, stackTrace) {
    AppLogger.reportError(
      'Failed to initialize background audio',
      error: e,
      stackTrace: stackTrace,
    );
  }
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const MusicLifeApp(),
    ),
  );
}

class MusicLifeApp extends ConsumerStatefulWidget {
  const MusicLifeApp({super.key, this.initialLocation});

  final String? initialLocation;

  @override
  ConsumerState<MusicLifeApp> createState() => _MusicLifeAppState();
}

class _MusicLifeAppState extends ConsumerState<MusicLifeApp> {
  late final GoRouter _router;

  Color _themeSeedColor(String? noteName, double energy) {
    if (noteName == null || noteName.isEmpty) return Colors.deepPurple;
    final match = RegExp(r'^[A-G](?:#|b)?').firstMatch(noteName);
    final key = match?.group(0);
    final base = _keyThemeColors[key] ?? Colors.deepPurple;
    final clampedEnergy = energy.clamp(0.0, 1.0).toDouble();
    return Color.lerp(Colors.blueGrey, base, 0.4 + (clampedEnergy * 0.6)) ??
        base;
  }

  @override
  void initState() {
    super.initState();
    _router = buildAppRouter(initialLocation: widget.initialLocation);
  }

  @override
  void dispose() {
    _router.dispose();
    AppDatabase.instance.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final seedColor = _themeSeedColor(
      settings.dynamicThemeNote,
      settings.dynamicThemeEnergy,
    );
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seedColor),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: settings.darkMode ? ThemeMode.dark : ThemeMode.light,
      routerConfig: _router,
    );
  }
}
