import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/screens/composition_helper_screen.dart';

void main() {
  group('kMaxCompositions', () {
    test('is a positive integer', () {
      expect(kMaxCompositions, greaterThan(0));
    });

    test('is 50', () {
      expect(kMaxCompositions, equals(50));
    });
  });

  group('Composition', () {
    final comp = Composition(
      id: 'id1',
      title: 'My Song',
      chords: ['C', 'Am', 'F', 'G'],
    );

    test('toJson produces expected map', () {
      final json = comp.toJson();
      expect(json['id'], 'id1');
      expect(json['title'], 'My Song');
      expect(json['chords'], ['C', 'Am', 'F', 'G']);
    });

    test('fromJson round-trips through toJson', () {
      final restored = Composition.fromJson(comp.toJson());
      expect(restored.id, comp.id);
      expect(restored.title, comp.title);
      expect(restored.chords, comp.chords);
    });

    test('fromJson handles empty chord list', () {
      final empty = Composition(id: 'e', title: 'Empty', chords: []);
      final restored = Composition.fromJson(empty.toJson());
      expect(restored.chords, isEmpty);
    });
  });
}
