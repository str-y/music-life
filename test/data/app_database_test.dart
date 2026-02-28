import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/data/app_database.dart';

void main() {
  group('AppDatabase migration planning', () {
    test('returns sequential versions between old and new schema', () {
      expect(
        AppDatabase.migrationPlanForTesting(oldVersion: 1, newVersion: 3),
        [2, 3],
      );
    });

    test('returns empty plan when no upgrade is needed', () {
      expect(
        AppDatabase.migrationPlanForTesting(oldVersion: 3, newVersion: 3),
        isEmpty,
      );
    });
  });
}
