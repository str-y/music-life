import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/pigeon/native_pitch_messages.dart';

void main() {
  test('NativePitchResultMessage encodes and decodes with stable types', () {
    final message = NativePitchResultMessage(
      noteName: 'C#4',
      frequency: 277.18,
      centsOffset: -3.5,
      midiNote: 61,
    );

    final decoded = NativePitchResultMessage.decode(message.encode());

    expect(decoded.noteName, 'C#4');
    expect(decoded.frequency, 277.18);
    expect(decoded.centsOffset, -3.5);
    expect(decoded.midiNote, 61);
  });
}
