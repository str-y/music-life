import 'dart:typed_data';

/// A FIFO ring buffer optimized for audio sample streaming.
class RingBuffer {
  RingBuffer({int initialCapacity = 1024})
      : assert(initialCapacity > 0),
        _buffer = List<double>.filled(initialCapacity, 0);

  List<double> _buffer;
  int _head = 0;
  int _length = 0;

  int get length => _length;

  void add(double value) {
    _ensureCapacity(_length + 1);
    _buffer[_tailIndex] = value;
    _length++;
  }

  void addAll(Iterable<double> values) {
    for (final value in values) {
      add(value);
    }
  }

  bool readInto(Float32List target) {
    if (_length < target.length) return false;
    for (int i = 0; i < target.length; i++) {
      target[i] = _buffer[(_head + i) % _buffer.length];
    }
    _head = (_head + target.length) % _buffer.length;
    _length -= target.length;
    return true;
  }

  int get _tailIndex => (_head + _length) % _buffer.length;

  void _ensureCapacity(int minCapacity) {
    if (_buffer.length >= minCapacity) return;
    int newCapacity = _buffer.length * 2;
    while (newCapacity < minCapacity) {
      newCapacity *= 2;
    }
    final newBuffer = List<double>.filled(newCapacity, 0);
    for (int i = 0; i < _length; i++) {
      newBuffer[i] = _buffer[(_head + i) % _buffer.length];
    }
    _buffer = newBuffer;
    _head = 0;
  }
}
