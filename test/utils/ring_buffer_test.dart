import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/utils/ring_buffer.dart';

void main() {
  group('RingBuffer', () {
    test('readInto returns false when there are not enough samples', () {
      final buffer = RingBuffer();
      buffer.addAll([1.0, 2.0]);

      final frame = Float32List(3);
      expect(buffer.readInto(frame), isFalse);
      expect(buffer.length, 2);
    });

    test('reads samples in FIFO order and pops consumed values', () {
      final buffer = RingBuffer();
      buffer.addAll([1.0, 2.0, 3.0, 4.0]);

      final frame = Float32List(3);
      expect(buffer.readInto(frame), isTrue);
      expect(frame, orderedEquals([1.0, 2.0, 3.0]));
      expect(buffer.length, 1);
    });

    test('supports wrapped writes and reads', () {
      final buffer = RingBuffer(initialCapacity: 4);
      buffer.addAll([1.0, 2.0, 3.0, 4.0]);

      final first = Float32List(3);
      expect(buffer.readInto(first), isTrue);
      expect(first, orderedEquals([1.0, 2.0, 3.0]));

      buffer.addAll([5.0, 6.0, 7.0]);

      final second = Float32List(4);
      expect(buffer.readInto(second), isTrue);
      expect(second, orderedEquals([4.0, 5.0, 6.0, 7.0]));
    });

    test('can read a frame that crosses the internal wrap boundary', () {
      final buffer = RingBuffer(initialCapacity: 5);
      buffer.addAll([1.0, 2.0, 3.0, 4.0, 5.0]);

      final advance = Float32List(4);
      expect(buffer.readInto(advance), isTrue);

      buffer.addAll([6.0, 7.0, 8.0, 9.0]);

      final wrapped = Float32List(5);
      expect(buffer.readInto(wrapped), isTrue);
      expect(wrapped, orderedEquals([5.0, 6.0, 7.0, 8.0, 9.0]));
    });
  });
}
