import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/theme/app_theme_seed.dart';

void main() {
  group('themeSeedColor', () {
    test('falls back to deep purple when note is empty', () {
      expect(themeSeedColor(null, 0.5), Colors.deepPurple);
      expect(themeSeedColor('', 0.5), Colors.deepPurple);
    });

    test('maps enharmonic keys to the same seed color', () {
      expect(themeSeedColor('C#4', 1.0), themeSeedColor('Db4', 1.0));
    });
  });
}
