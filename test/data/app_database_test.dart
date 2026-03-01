import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/data/app_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AppDatabase migration planning', () {
    test('includes all migrations when upgrading from unversioned database', () {
      expect(
        AppDatabase.migrationPlanForTesting(oldVersion: 0, newVersion: 6),
        [1, 2, 3, 4, 5, 6],
      );
    });

    test('returns sequential versions between old and new schema', () {
      expect(
        AppDatabase.migrationPlanForTesting(oldVersion: 1, newVersion: 6),
        [2, 3, 4, 5, 6],
      );
    });

    test('returns empty plan when no upgrade is needed', () {
      expect(
        AppDatabase.migrationPlanForTesting(oldVersion: 6, newVersion: 6),
        isEmpty,
      );
    });
  });

  group('AppDatabase database password', () {
    test('generates and persists a password when missing', () async {
      final password = await AppDatabase.databasePasswordForTesting();
      final prefs = await SharedPreferences.getInstance();

      expect(password, isNotEmpty);
      expect(prefs.getString('database_password'), password);
    });

    test('reuses an existing persisted password', () async {
      SharedPreferences.setMockInitialValues({
        'database_password': 'existing-password',
      });

      final password = await AppDatabase.databasePasswordForTesting();

      expect(password, 'existing-password');
    });
  });

  group('AppDatabase integrity check helpers', () {
    test('accepts case-insensitive ok integrity check result', () {
      expect(AppDatabase.integrityCheckResultIsOkForTesting('ok'), isTrue);
      expect(AppDatabase.integrityCheckResultIsOkForTesting('OK'), isTrue);
    });

    test('rejects non-ok integrity check result', () {
      expect(
        AppDatabase.integrityCheckResultIsOkForTesting('*** in database main ***'),
        isFalse,
      );
    });

    test('detects corruption-shaped database errors', () {
      expect(
        AppDatabase.isCorruptionErrorForTesting(
          StateError('database disk image is malformed'),
        ),
        isTrue,
      );
      expect(
        AppDatabase.isCorruptionErrorForTesting(
          ArgumentError('file is not a database'),
        ),
        isTrue,
      );
      expect(
        AppDatabase.isCorruptionErrorForTesting(
          Exception('database corruption detected'),
        ),
        isTrue,
      );
      expect(
        AppDatabase.isCorruptionErrorForTesting(Exception('permission denied')),
        isFalse,
      );
    });
  });
}
