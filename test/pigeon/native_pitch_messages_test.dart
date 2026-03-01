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

  test('tryDecode returns null for malformed payload', () {
    expect(NativePitchResultMessage.tryDecode(const <Object?>['A4']), isNull);
    expect(
      NativePitchResultMessage.tryDecode(const <Object?>['A4', null, 0.0, 69]),
      isNull,
    );
    expect(
      NativePitchResultMessage.tryDecode(
          const <Object?>['A4', '440.0', 0.0, 69]),
      isNull,
    );
  });
}
