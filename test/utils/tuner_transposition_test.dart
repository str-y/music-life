import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/utils/tuner_transposition.dart';

void main() {
  group('transposedNoteNameFromMidi', () {
    test('keeps concert pitch when transposition is C', () {
      expect(
        transposedNoteNameFromMidi(
          midiNote: 69,
          transposition: TunerTransposition.c,
        ),
        'A4',
      );
    });

    test('converts concert Bb3 to written C4 for Bb instruments', () {
      expect(
        transposedNoteNameFromMidi(
          midiNote: 58,
          transposition: TunerTransposition.bb,
        ),
        'C4',
      );
    });

    test('converts concert Eb4 to written C5 for Eb instruments', () {
      expect(
        transposedNoteNameFromMidi(
          midiNote: 63,
          transposition: TunerTransposition.eb,
        ),
        'C5',
      );
    });

    test('converts concert F3 to written C4 for F instruments', () {
      expect(
        transposedNoteNameFromMidi(
          midiNote: 53,
          transposition: TunerTransposition.f,
        ),
        'C4',
      );
    });
  });
}
