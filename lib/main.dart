import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:music_life/config/app_config.dart';
import 'package:music_life/data/app_database.dart';
import 'package:music_life/l10n/app_localizations.dart';
import 'package:music_life/providers/app_settings_provider.dart';
import 'package:music_life/providers/dependency_providers.dart';
import 'package:music_life/router/app_router.dart';
import 'package:music_life/theme/app_theme_seed.dart';
import 'package:music_life/utils/app_logger.dart';

const double _themeContrastLevel = 0.5;

Future<void> runMusicLifeApp(AppConfig config) async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.minimumLevel = config.effectiveLogLevel;
  try {
    await MobileAds.instance.initialize();
    await JustAudioBackground.init(
      androidNotificationChannelId: config.audioNotificationChannelId,
      androidNotificationChannelName: config.audioNotificationChannelName,
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
  AppDatabase.configureSharedPreferencesLoader(() async => prefs);
  await AppDatabase.instance.ensureHealthy();
  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const MusicLifeApp(),
    ),
  );
}

typedef AppErrorReporter =
    void Function(
      String message, {
      required Object error,
      required StackTrace stackTrace,
    });

Future<void> runWithAppErrorLogging(
  Future<void> Function() body, {
  AppErrorReporter errorReporter = AppLogger.reportError,
}) async {
  final result = runZonedGuarded<Future<void>>(
    body,
    (error, stackTrace) {
      errorReporter(
        'Unhandled asynchronous exception',
        error: error,
        stackTrace: stackTrace,
      );
    },
  );

  await (result ?? Future<void>.value());
}

Future<void> main() async {
  await runWithAppErrorLogging(() async {
    WidgetsFlutterBinding.ensureInitialized();
    const config = AppConfig();
    AppLogger.minimumLevel = config.effectiveLogLevel;
    try {
      await MobileAds.instance.initialize();
      await JustAudioBackground.init(
        androidNotificationChannelId: config.audioNotificationChannelId,
        androidNotificationChannelName: config.audioNotificationChannelName,
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
    AppDatabase.configureSharedPreferencesLoader(() async => prefs);
    await AppDatabase.instance.ensureHealthy();
    runApp(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MusicLifeApp(),
      ),
    );
  });
}

class MusicLifeApp extends ConsumerStatefulWidget {
  const MusicLifeApp({super.key, this.initialLocation});

  final String? initialLocation;

  @override
  ConsumerState<MusicLifeApp> createState() => _MusicLifeAppState();
}

class _MusicLifeAppState extends ConsumerState<MusicLifeApp> {
  late final GoRouter _router;

  ThemeData _buildTheme(Color seedColor, {required Brightness brightness}) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
      contrastLevel: _themeContrastLevel,
    );
    return ThemeData(
      colorScheme: colorScheme,
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surfaceTint,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        modalBackgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surfaceTint,
        dragHandleColor: colorScheme.outlineVariant,
      ),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(48),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
      useMaterial3: true,
    );
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
    final selectedThemeNote = settings.themeColorNote ?? settings.dynamicThemeNote;
    final seedColor = themeSeedColor(
      selectedThemeNote,
      settings.themeColorNote == null ? settings.dynamicThemeEnergy : 1.0,
      mode: settings.dynamicThemeMode,
      intensity: settings.themeColorNote == null
          ? settings.dynamicThemeIntensity
          : 1.0,
    );
    final locale = settings.localeCode == null
        ? null
        : Locale(settings.localeCode!);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      theme: _buildTheme(seedColor, brightness: Brightness.light),
      darkTheme: _buildTheme(seedColor, brightness: Brightness.dark),
      themeMode: settings.useSystemTheme
          ? ThemeMode.system
          : (settings.darkMode ? ThemeMode.dark : ThemeMode.light),
      themeAnimationDuration: const Duration(milliseconds: 250),
      themeAnimationCurve: Curves.easeOutCubic,
      routerConfig: _router,
    );
  }
}
