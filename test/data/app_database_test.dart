import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/data/app_database.dart';

void main() {
  group('AppDatabase migration planning', () {
    test('returns sequential versions between old and new schema', () {
      expect(
        AppDatabase.migrationPlanForTesting(oldVersion: 1, newVersion: 5),
        [2, 3, 4, 5],
      );
    });

    test('returns empty plan when no upgrade is needed', () {
      expect(
        AppDatabase.migrationPlanForTesting(oldVersion: 5, newVersion: 5),
        isEmpty,
      );
    });
  });
}
