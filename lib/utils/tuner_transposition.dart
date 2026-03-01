/// Constants and helpers for supported tuner transposition presets.
class TunerTransposition {
  static const String c = 'C';
  static const String bb = 'Bb';
  static const String eb = 'Eb';
  static const String f = 'F';

  static const List<String> supported = [c, bb, eb, f];

  static int semitoneOffset(String transposition) {
    switch (transposition) {
      case bb:
        return 2;
      case eb:
        return 9;
      case f:
        return 7;
      case c:
      default:
        return 0;
    }
  }
}

/// Converts a concert-pitch MIDI note to a display note name for a transposition.
String transposedNoteNameFromMidi({
  required int midiNote,
  required String transposition,
}) {
  const noteNames = <String>[
    'C',
    'C#',
    'D',
    'D#',
    'E',
    'F',
    'F#',
    'G',
    'G#',
    'A',
    'A#',
    'B',
  ];
  final shifted = midiNote + TunerTransposition.semitoneOffset(transposition);
  final normalizedPitchClass = ((shifted % 12) + 12) % 12;
  final octave = (shifted ~/ 12) - 1;
  return '${noteNames[normalizedPitchClass]}$octave';
}
