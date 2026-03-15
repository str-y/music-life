import 'dart:typed_data';

/// Encodes a list of [double] amplitude values as a packed IEEE 754 BLOB.
Uint8List waveformToBlob(List<double> data) {
  final bytes = ByteData(data.length * Float64List.bytesPerElement);
  for (var i = 0; i < data.length; i++) {
    bytes.setFloat64(i * Float64List.bytesPerElement, data[i], Endian.little);
  }
  return bytes.buffer.asUint8List();
}

/// Decodes a packed IEEE 754 BLOB back to a list of [double] values.
List<double> blobToWaveform(Uint8List blob) {
  final sampleCount = blob.lengthInBytes ~/ Float64List.bytesPerElement;
  if (sampleCount == 0) {
    return const <double>[];
  }
  // Use a zero-copy typed view when the stored bytes already match the host
  // endianness and the buffer offset is aligned for Float64 reads.
  if (Endian.host == Endian.little &&
      blob.offsetInBytes % Float64List.bytesPerElement == 0) {
    return blob.buffer.asFloat64List(blob.offsetInBytes, sampleCount);
  }
  final bytes = ByteData.sublistView(blob);
  return List<double>.generate(
    sampleCount,
    (i) => bytes.getFloat64(i * Float64List.bytesPerElement, Endian.little),
    growable: false,
  );
}
