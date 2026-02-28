import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/repositories/composition_repository.dart';

void main() {
  group('Composition', () {
    final composition = Composition(
      id: 'comp1',
      title: 'My Song',
      chords: ['C', 'Am', 'F', 'G'],
    );

    test('toJson produces expected map', () {
      final json = composition.toJson();
      expect(json['id'], 'comp1');
      expect(json['title'], 'My Song');
      expect(json['chords'], ['C', 'Am', 'F', 'G']);
    });

    test('fromJson round-trips through toJson', () {
      final restored = Composition.fromJson(composition.toJson());
      expect(restored.id, composition.id);
      expect(restored.title, composition.title);
      expect(restored.chords, composition.chords);
    });

    test('fromJson with empty chords list', () {
      final json = {
        'id': 'empty',
        'title': 'Empty',
        'chords': <dynamic>[],
      };
      final restored = Composition.fromJson(json);
      expect(restored.chords, isEmpty);
    });
  });
}
