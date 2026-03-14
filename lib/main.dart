import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'config/app_config.dart';
import 'data/app_database.dart';
import 'l10n/app_localizations.dart';
import 'providers/app_settings_provider.dart';
import 'providers/dependency_providers.dart';
import 'router/app_router.dart';
import 'theme/app_theme_seed.dart';
import 'utils/app_logger.dart';

const double _themeContrastLevel = 0.5;

void main() async {
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
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: brightness,
        contrastLevel: _themeContrastLevel,
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
      routerConfig: _router,
    );
  }
}
