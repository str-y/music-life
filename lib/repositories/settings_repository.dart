import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../metronome_sound_library.dart';
import '../theme/dynamic_theme_mode.dart';

const Set<String> _supportedLocaleCodes = <String>{'en', 'ja'};

/// Immutable application settings persisted in local storage.
class AppSettings {
  final bool darkMode;
  final bool useSystemTheme;
  final String? localeCode;
  final String? themeColorNote;
  final double referencePitch;
  final String tunerTransposition;
  final DynamicThemeMode dynamicThemeMode;
  final double dynamicThemeIntensity;
  final String? dynamicThemeNote;
  final double dynamicThemeEnergy;
  final bool cloudSyncEnabled;
  final DateTime? lastCloudSyncAt;
  final DateTime? rewardedPremiumExpiresAt;
  final List<String> installedMetronomeSoundPackIds;
  final String selectedMetronomeSoundPackId;

  const AppSettings({
    this.darkMode = false,
    this.useSystemTheme = true,
    this.localeCode,
    this.themeColorNote,
    this.referencePitch = 440.0,
    this.tunerTransposition = 'C',
    this.dynamicThemeMode = DynamicThemeMode.chill,
    this.dynamicThemeIntensity = 0.7,
    this.dynamicThemeNote,
    this.dynamicThemeEnergy = 0.0,
    this.cloudSyncEnabled = false,
    this.lastCloudSyncAt,
    this.rewardedPremiumExpiresAt,
    this.installedMetronomeSoundPackIds = const <String>[
      defaultMetronomeSoundPackId,
    ],
    this.selectedMetronomeSoundPackId = defaultMetronomeSoundPackId,
  });

  AppSettings copyWith({
    bool? darkMode,
    bool? useSystemTheme,
    String? localeCode,
    String? themeColorNote,
    double? referencePitch,
    String? tunerTransposition,
    DynamicThemeMode? dynamicThemeMode,
    double? dynamicThemeIntensity,
    String? dynamicThemeNote,
    double? dynamicThemeEnergy,
    bool? cloudSyncEnabled,
    DateTime? lastCloudSyncAt,
    DateTime? rewardedPremiumExpiresAt,
    List<String>? installedMetronomeSoundPackIds,
    String? selectedMetronomeSoundPackId,
    bool clearLastCloudSyncAt = false,
    bool clearRewardedPremiumExpiresAt = false,
    bool clearLocaleCode = false,
    bool clearThemeColorNote = false,
    bool clearDynamicThemeNote = false,
  }) {
    return AppSettings(
      darkMode: darkMode ?? this.darkMode,
      useSystemTheme: useSystemTheme ?? this.useSystemTheme,
      localeCode: clearLocaleCode ? null : (localeCode ?? this.localeCode),
      themeColorNote:
          clearThemeColorNote ? null : (themeColorNote ?? this.themeColorNote),
      referencePitch: referencePitch ?? this.referencePitch,
      tunerTransposition: tunerTransposition ?? this.tunerTransposition,
      dynamicThemeMode: dynamicThemeMode ?? this.dynamicThemeMode,
      dynamicThemeIntensity: _clampDynamicThemeIntensity(
        dynamicThemeIntensity ?? this.dynamicThemeIntensity,
      ),
      dynamicThemeNote: clearDynamicThemeNote
          ? null
          : (dynamicThemeNote ?? this.dynamicThemeNote),
      dynamicThemeEnergy: dynamicThemeEnergy ?? this.dynamicThemeEnergy,
      cloudSyncEnabled: cloudSyncEnabled ?? this.cloudSyncEnabled,
      lastCloudSyncAt:
          clearLastCloudSyncAt ? null : (lastCloudSyncAt ?? this.lastCloudSyncAt),
      rewardedPremiumExpiresAt: clearRewardedPremiumExpiresAt
          ? null
          : (rewardedPremiumExpiresAt ?? this.rewardedPremiumExpiresAt),
      installedMetronomeSoundPackIds: normalizeInstalledMetronomeSoundPackIds(
        installedMetronomeSoundPackIds ?? this.installedMetronomeSoundPackIds,
      ),
      selectedMetronomeSoundPackId: normalizeSelectedMetronomeSoundPackId(
        selectedMetronomeSoundPackId ?? this.selectedMetronomeSoundPackId,
        normalizeInstalledMetronomeSoundPackIds(
          installedMetronomeSoundPackIds ?? this.installedMetronomeSoundPackIds,
        ),
      ),
    );
  }

  bool get hasRewardedPremiumAccess =>
      rewardedPremiumExpiresAt?.isAfter(DateTime.now()) ?? false;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettings &&
          darkMode == other.darkMode &&
          useSystemTheme == other.useSystemTheme &&
          localeCode == other.localeCode &&
          themeColorNote == other.themeColorNote &&
          referencePitch == other.referencePitch &&
          tunerTransposition == other.tunerTransposition &&
          dynamicThemeMode == other.dynamicThemeMode &&
          dynamicThemeIntensity == other.dynamicThemeIntensity &&
          dynamicThemeNote == other.dynamicThemeNote &&
           dynamicThemeEnergy == other.dynamicThemeEnergy &&
           cloudSyncEnabled == other.cloudSyncEnabled &&
           lastCloudSyncAt == other.lastCloudSyncAt &&
           rewardedPremiumExpiresAt == other.rewardedPremiumExpiresAt &&
           listEquals(
             installedMetronomeSoundPackIds,
             other.installedMetronomeSoundPackIds,
           ) &&
           selectedMetronomeSoundPackId == other.selectedMetronomeSoundPackId;

  @override
  int get hashCode =>
       Object.hash(
           darkMode,
           useSystemTheme,
           localeCode,
           themeColorNote,
           referencePitch,
           tunerTransposition,
           dynamicThemeMode,
           dynamicThemeIntensity,
           dynamicThemeNote,
            dynamicThemeEnergy,
            cloudSyncEnabled,
            lastCloudSyncAt,
            rewardedPremiumExpiresAt,
            Object.hashAll(installedMetronomeSoundPackIds),
            selectedMetronomeSoundPackId);

  static double _clampDynamicThemeIntensity(double intensity) {
    return intensity.clamp(0.0, 1.0).toDouble();
  }
}

/// Loads and saves [AppSettings] values via shared preferences.
class SettingsRepository {
  const SettingsRepository(this._prefs, {AppConfig config = const AppConfig()})
      : _config = config;

  final SharedPreferences _prefs;
  final AppConfig _config;

  /// Reads settings from storage, falling back to configured defaults.
  AppSettings load() {
    return AppSettings(
      darkMode:
          _prefs.getBool(_config.darkModeStorageKey) ?? _config.defaultDarkMode,
      useSystemTheme: _prefs.getBool(_config.useSystemThemeStorageKey) ??
          _config.defaultUseSystemTheme,
      localeCode: _decodeLocaleCode(
        _prefs.getString(_config.localeStorageKey),
      ),
      themeColorNote: _prefs.getString(_config.themeColorNoteStorageKey),
      referencePitch: _prefs.getDouble(_config.referencePitchStorageKey) ??
          _config.defaultReferencePitch,
      tunerTransposition:
          _prefs.getString(_config.tunerTranspositionStorageKey) ??
              _config.defaultTunerTransposition,
      dynamicThemeMode: DynamicThemeMode.fromStorage(
        _prefs.getString(_config.dynamicThemeModeStorageKey) ??
            _config.defaultDynamicThemeMode,
      ),
      dynamicThemeIntensity: AppSettings._clampDynamicThemeIntensity(
        _prefs.getDouble(_config.dynamicThemeIntensityStorageKey) ??
            _config.defaultDynamicThemeIntensity,
      ),
      cloudSyncEnabled:
          _prefs.getBool(_config.cloudSyncEnabledStorageKey) ?? false,
      lastCloudSyncAt: _decodeDateTime(
        _prefs.getString(_config.lastCloudSyncAtStorageKey),
      ),
      rewardedPremiumExpiresAt: _decodeDateTime(
        _prefs.getString(_config.rewardedPremiumExpiresAtStorageKey),
      ),
      installedMetronomeSoundPackIds: normalizeInstalledMetronomeSoundPackIds(
        _prefs.getStringList(_config.metronomeSoundPacksStorageKey),
      ),
      selectedMetronomeSoundPackId: normalizeSelectedMetronomeSoundPackId(
        _prefs.getString(_config.selectedMetronomeSoundPackStorageKey),
        normalizeInstalledMetronomeSoundPackIds(
          _prefs.getStringList(_config.metronomeSoundPacksStorageKey),
        ),
      ),
    );
  }

  /// Persists all supported settings values to storage.
  Future<void> save(AppSettings settings) async {
    await _prefs.setBool(_config.darkModeStorageKey, settings.darkMode);
    await _prefs.setBool(
      _config.useSystemThemeStorageKey,
      settings.useSystemTheme,
    );
    if (settings.localeCode == null || settings.localeCode!.isEmpty) {
      await _prefs.remove(_config.localeStorageKey);
    } else {
      await _prefs.setString(
        _config.localeStorageKey,
        settings.localeCode!,
      );
    }
    if (settings.themeColorNote == null || settings.themeColorNote!.isEmpty) {
      await _prefs.remove(_config.themeColorNoteStorageKey);
    } else {
      await _prefs.setString(
        _config.themeColorNoteStorageKey,
        settings.themeColorNote!,
      );
    }
    await _prefs.setDouble(
      _config.referencePitchStorageKey,
      settings.referencePitch,
    );
    await _prefs.setString(
      _config.tunerTranspositionStorageKey,
      settings.tunerTransposition,
    );
    await _prefs.setString(
      _config.dynamicThemeModeStorageKey,
      settings.dynamicThemeMode.storageValue,
    );
    await _prefs.setDouble(
      _config.dynamicThemeIntensityStorageKey,
      AppSettings._clampDynamicThemeIntensity(settings.dynamicThemeIntensity),
    );
    await _prefs.setBool(
      _config.cloudSyncEnabledStorageKey,
      settings.cloudSyncEnabled,
    );
    if (settings.lastCloudSyncAt == null) {
      await _prefs.remove(_config.lastCloudSyncAtStorageKey);
    } else {
      await _prefs.setString(
        _config.lastCloudSyncAtStorageKey,
        settings.lastCloudSyncAt!.toIso8601String(),
      );
    }
    if (settings.rewardedPremiumExpiresAt == null) {
      await _prefs.remove(_config.rewardedPremiumExpiresAtStorageKey);
    } else {
      await _prefs.setString(
        _config.rewardedPremiumExpiresAtStorageKey,
        settings.rewardedPremiumExpiresAt!.toIso8601String(),
      );
    }
    await _prefs.setStringList(
      _config.metronomeSoundPacksStorageKey,
      normalizeInstalledMetronomeSoundPackIds(
        settings.installedMetronomeSoundPackIds,
      ),
    );
    await _prefs.setString(
      _config.selectedMetronomeSoundPackStorageKey,
      normalizeSelectedMetronomeSoundPackId(
        settings.selectedMetronomeSoundPackId,
        normalizeInstalledMetronomeSoundPackIds(
          settings.installedMetronomeSoundPackIds,
        ),
      ),
    );
  }

  DateTime? _decodeDateTime(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  String? _decodeLocaleCode(String? value) {
    if (value == null || value.isEmpty) return null;
    return _supportedLocaleCodes.contains(value) ? value : null;
  }
}
