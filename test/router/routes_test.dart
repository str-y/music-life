import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/router/routes.dart';

void main() {
  group('Typed routes', () {
    test('expose expected locations', () {
      expect(const HomeRoute().location, '/');
      expect(const TunerRoute().location, '/tuner');
      expect(const PracticeLogRoute().location, '/practice-log');
      expect(const LibraryRoute().location, '/library');
      expect(const RecordingsRoute().location, '/recordings');
      expect(const LibraryLogsRoute().location, '/library/logs');
      expect(const RhythmRoute().location, '/rhythm');
      expect(const ChordAnalyserRoute().location, '/chord-analyser');
      expect(const CompositionHelperRoute().location, '/composition-helper');
    });
  });
}
