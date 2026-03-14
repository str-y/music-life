import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/metronome_sound_library.dart';

void main() {
  test('normalizeInstalledMetronomeSoundPackIds keeps default and drops unknown ids',
      () {
    expect(
      normalizeInstalledMetronomeSoundPackIds(
        <String>['acoustic_kit', 'missing', defaultMetronomeSoundPackId],
      ),
      <String>[defaultMetronomeSoundPackId, 'acoustic_kit'],
    );
  });

  test('recommendMetronomeSoundPack maps tempo bands to premium-ready packs', () {
    expect(recommendMetronomeSoundPack(60).id, 'signature_voice_count');
    expect(recommendMetronomeSoundPack(120).id, 'acoustic_kit');
    expect(recommendMetronomeSoundPack(180).id, 'percussion_clave');
  });

  test('resolveSelectedMetronomeSoundPack falls back when premium access expires',
      () {
    expect(
      resolveSelectedMetronomeSoundPack(
        selectedId: 'signature_voice_count',
        installedIds: <String>[
          defaultMetronomeSoundPackId,
          'signature_voice_count',
        ],
        hasPremiumAccess: false,
      ).id,
      defaultMetronomeSoundPackId,
    );
  });
}
