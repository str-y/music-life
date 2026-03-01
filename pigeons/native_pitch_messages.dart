import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/pigeon/native_pitch_messages.dart',
    dartPackageName: 'music_life',
  ),
)
class NativePitchResultMessage {
  NativePitchResultMessage({
    required this.noteName,
    required this.frequency,
    required this.centsOffset,
    required this.midiNote,
  });

  String noteName;
  double frequency;
  double centsOffset;
  int midiNote;
}
