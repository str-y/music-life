import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

class AppSettings {
  final bool darkMode;
  final double referencePitch;
  final String tunerTransposition;
  final String? dynamicThemeNote;
  final double dynamicThemeEnergy;

  const AppSettings({
    this.darkMode = false,
    this.referencePitch = 440.0,
    this.tunerTransposition = 'C',
    this.dynamicThemeNote,
    this.dynamicThemeEnergy = 0.0,
  });

  AppSettings copyWith({
    bool? darkMode,
    double? referencePitch,
    String? tunerTransposition,
    String? dynamicThemeNote,
    double? dynamicThemeEnergy,
    bool clearDynamicThemeNote = false,
  }) {
    return AppSettings(
      darkMode: darkMode ?? this.darkMode,
      referencePitch: referencePitch ?? this.referencePitch,
      tunerTransposition: tunerTransposition ?? this.tunerTransposition,
      dynamicThemeNote: clearDynamicThemeNote
          ? null
          : (dynamicThemeNote ?? this.dynamicThemeNote),
      dynamicThemeEnergy: dynamicThemeEnergy ?? this.dynamicThemeEnergy,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettings &&
          darkMode == other.darkMode &&
          referencePitch == other.referencePitch &&
          tunerTransposition == other.tunerTransposition &&
          dynamicThemeNote == other.dynamicThemeNote &&
          dynamicThemeEnergy == other.dynamicThemeEnergy;

  @override
  int get hashCode =>
      Object.hash(darkMode, referencePitch, tunerTransposition, dynamicThemeNote,
          dynamicThemeEnergy);
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
      referencePitch: _prefs.getDouble(_config.referencePitchStorageKey) ??
          _config.defaultReferencePitch,
      tunerTransposition:
          _prefs.getString(_config.tunerTranspositionStorageKey) ??
              _config.defaultTunerTransposition,
    );
  }

  Future<void> save(AppSettings settings) async {
    await _prefs.setBool(_config.darkModeStorageKey, settings.darkMode);
    await _prefs.setDouble(
      _config.referencePitchStorageKey,
      settings.referencePitch,
    );
    await _prefs.setString(
      _config.tunerTranspositionStorageKey,
      settings.tunerTransposition,
    );
  }
}
