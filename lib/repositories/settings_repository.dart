import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

class AppSettings {
  final bool darkMode;
  final double referencePitch;

  const AppSettings({
    this.darkMode = false,
    this.referencePitch = 440.0,
  });

  AppSettings copyWith({bool? darkMode, double? referencePitch}) {
    return AppSettings(
      darkMode: darkMode ?? this.darkMode,
      referencePitch: referencePitch ?? this.referencePitch,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettings &&
          darkMode == other.darkMode &&
          referencePitch == other.referencePitch;

  @override
  int get hashCode => Object.hash(darkMode, referencePitch);
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
    );
  }

  Future<void> save(AppSettings settings) async {
    await _prefs.setBool(_config.darkModeStorageKey, settings.darkMode);
    await _prefs.setDouble(
      _config.referencePitchStorageKey,
      settings.referencePitch,
    );
  }
}
