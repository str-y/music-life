import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/theme/app_theme_seed.dart';
import 'package:music_life/theme/dynamic_theme_mode.dart';

void main() {
  group('themeSeedColor', () {
    test('falls back to deep purple when note is empty', () {
      expect(themeSeedColor(null, 0.5), Colors.deepPurple);
      expect(themeSeedColor('', 0.5), Colors.deepPurple);
    });

    test('maps enharmonic keys to the same seed color', () {
      expect(themeSeedColor('C#4', 1.0), themeSeedColor('Db4', 1.0));
    });

    test('uses different palettes for each dynamic mode', () {
      expect(
        themeSeedColor('A4', 1.0, mode: DynamicThemeMode.chill),
        isNot(themeSeedColor('A4', 1.0, mode: DynamicThemeMode.intense)),
      );
      expect(
        themeSeedColor('A4', 1.0, mode: DynamicThemeMode.classical),
        isNot(themeSeedColor('A4', 1.0, mode: DynamicThemeMode.intense)),
      );
    });

    test('tunes colors by octave range and intensity', () {
      final low = themeSeedColor('C2', 1.0);
      final high = themeSeedColor('C6', 1.0);
      final muted = themeSeedColor('C4', 1.0, intensity: 0.2);
      final vivid = themeSeedColor('C4', 1.0, intensity: 1.0);

      expect(low, isNot(high));
      expect(muted, isNot(vivid));
    });
  });
}
