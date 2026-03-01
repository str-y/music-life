import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

class AppSettings {
  final bool darkMode;
  final bool useSystemTheme;
  final String? themeColorNote;
  final double referencePitch;
  final String tunerTransposition;
  final String? dynamicThemeNote;
  final double dynamicThemeEnergy;
  final DateTime? rewardedPremiumExpiresAt;

  const AppSettings({
    this.darkMode = false,
    this.useSystemTheme = true,
    this.themeColorNote,
    this.referencePitch = 440.0,
    this.tunerTransposition = 'C',
    this.dynamicThemeNote,
    this.dynamicThemeEnergy = 0.0,
    this.rewardedPremiumExpiresAt,
  });

  AppSettings copyWith({
    bool? darkMode,
    bool? useSystemTheme,
    String? themeColorNote,
    double? referencePitch,
    String? tunerTransposition,
    String? dynamicThemeNote,
    double? dynamicThemeEnergy,
    DateTime? rewardedPremiumExpiresAt,
    bool clearRewardedPremiumExpiresAt = false,
    bool clearThemeColorNote = false,
    bool clearDynamicThemeNote = false,
  }) {
    return AppSettings(
      darkMode: darkMode ?? this.darkMode,
      useSystemTheme: useSystemTheme ?? this.useSystemTheme,
      themeColorNote:
          clearThemeColorNote ? null : (themeColorNote ?? this.themeColorNote),
      referencePitch: referencePitch ?? this.referencePitch,
      tunerTransposition: tunerTransposition ?? this.tunerTransposition,
      dynamicThemeNote: clearDynamicThemeNote
          ? null
          : (dynamicThemeNote ?? this.dynamicThemeNote),
      dynamicThemeEnergy: dynamicThemeEnergy ?? this.dynamicThemeEnergy,
      rewardedPremiumExpiresAt: clearRewardedPremiumExpiresAt
          ? null
          : (rewardedPremiumExpiresAt ?? this.rewardedPremiumExpiresAt),
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
          themeColorNote == other.themeColorNote &&
          referencePitch == other.referencePitch &&
          tunerTransposition == other.tunerTransposition &&
          dynamicThemeNote == other.dynamicThemeNote &&
          dynamicThemeEnergy == other.dynamicThemeEnergy &&
          rewardedPremiumExpiresAt == other.rewardedPremiumExpiresAt;

  @override
  int get hashCode =>
      Object.hash(
          darkMode,
          useSystemTheme,
          themeColorNote,
          referencePitch,
          tunerTransposition,
          dynamicThemeNote,
          dynamicThemeEnergy,
          rewardedPremiumExpiresAt);
}

class SettingsRepository {
  const SettingsRepository(this._prefs, {AppConfig config = const AppConfig()})
      : _config = config;

  final SharedPreferences _prefs;
  final AppConfig _config;

  AppSettings load() {
    return AppSettings(
      darkMode:
          _prefs.getBool(_config.darkModeStorageKey) ?? _config.defaultDarkMode,
      useSystemTheme: _prefs.getBool(_config.useSystemThemeStorageKey) ??
          _config.defaultUseSystemTheme,
      themeColorNote: _prefs.getString(_config.themeColorNoteStorageKey),
      referencePitch: _prefs.getDouble(_config.referencePitchStorageKey) ??
          _config.defaultReferencePitch,
      tunerTransposition:
          _prefs.getString(_config.tunerTranspositionStorageKey) ??
              _config.defaultTunerTransposition,
      rewardedPremiumExpiresAt: _decodeDateTime(
        _prefs.getString(_config.rewardedPremiumExpiresAtStorageKey),
      ),
    );
  }

  Future<void> save(AppSettings settings) async {
    await _prefs.setBool(_config.darkModeStorageKey, settings.darkMode);
    await _prefs.setBool(
      _config.useSystemThemeStorageKey,
      settings.useSystemTheme,
    );
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
    if (settings.rewardedPremiumExpiresAt == null) {
      await _prefs.remove(_config.rewardedPremiumExpiresAtStorageKey);
    } else {
      await _prefs.setString(
        _config.rewardedPremiumExpiresAtStorageKey,
        settings.rewardedPremiumExpiresAt!.toIso8601String(),
      );
    }
  }

  DateTime? _decodeDateTime(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}
