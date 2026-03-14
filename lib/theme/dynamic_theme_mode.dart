enum DynamicThemeMode {
  chill,
  intense,
  classical;

  String get storageValue => name;

  static DynamicThemeMode fromStorage(String? value) {
    return DynamicThemeMode.values.firstWhere(
      (mode) => mode.storageValue == value,
      orElse: () => DynamicThemeMode.chill,
    );
  }
}
