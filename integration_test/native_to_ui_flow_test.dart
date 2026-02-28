import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:music_life/data/app_database.dart';
import 'package:music_life/main.dart';
import 'package:music_life/native_pitch_bridge.dart';
import 'package:music_life/screens/chord_analyser_screen.dart';
import 'package:music_life/screens/tuner_screen.dart';
import 'package:music_life/service_locator.dart';
import 'package:path/path.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

const _permissionChannel = MethodChannel('flutter.baseflow.com/permissions/methods');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger
        .setMockMethodCallHandler(_permissionChannel, (call) async {
      switch (call.method) {
        case 'checkPermissionStatus':
          return PermissionStatus.granted.value;
        case 'requestPermissions':
          final permission = (call.arguments as List).first as int;
          return <int, int>{permission: PermissionStatus.granted.value};
        case 'shouldShowRequestPermissionRationale':
          return false;
        case 'openAppSettings':
          return true;
      }
      return null;
    });
  });

  tearDownAll(() {
    TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger
        .setMockMethodCallHandler(_permissionChannel, null);
  });

  group('Native-to-UI integration flow', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      ServiceLocator.overrideForTesting(ServiceLocator.forTesting(
        prefs: prefs,
        pitchBridgeFactory: ({FfiErrorHandler? onError}) => _TestPitchBridge(),
      ));
      _TestPitchBridge.instances.clear();
    });

    tearDown(() {
      ServiceLocator.reset();
    });

    testWidgets('Tuner flow: bridge stream updates UI', (tester) async {
      await tester.pumpWidget(const ProviderScope(child: MusicLifeApp()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      expect(find.byType(TunerScreen), findsOneWidget);
      final bridge = _TestPitchBridge.instances.single;
      bridge.emitPitch(const PitchResult(
        noteName: 'A4',
        frequency: 440.0,
        centsOffset: 0.0,
        midiNote: 69,
      ));
      await tester.pumpAndSettle();

      expect(find.text('A4'), findsOneWidget);
      expect(find.text('440.0 Hz'), findsOneWidget);
    });

    testWidgets('Chord analyser flow: bridge stream updates UI history',
        (tester) async {
      await tester.pumpWidget(const ProviderScope(child: MusicLifeApp()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.piano));
      await tester.pumpAndSettle();

      expect(find.byType(ChordAnalyserScreen), findsOneWidget);
      final bridge = _TestPitchBridge.instances.single;
      bridge.emitChord('Cmaj7');
      await tester.pumpAndSettle();

      expect(find.text('Cmaj7'), findsWidgets);
    });

    testWidgets('Smoke: app starts and microphone request succeeds',
        (tester) async {
      await tester.pumpWidget(const ProviderScope(child: MusicLifeApp()));
      await tester.pumpAndSettle();

      final status = await Permission.microphone.request();
      expect(status.isGranted, isTrue);
      expect(find.byType(MainScreen), findsOneWidget);
    });
  });

  group('SQLite migration regression', () {
    setUp(() async {
      await AppDatabase.instance.close();
      final dbPath = join(await getDatabasesPath(), 'music_life.db');
      await deleteDatabase(dbPath);
    });

    tearDown(() async {
      await AppDatabase.instance.close();
      final dbPath = join(await getDatabasesPath(), 'music_life.db');
      await deleteDatabase(dbPath);
    });

    testWidgets('v1 TEXT waveform migrates to v2 BLOB', (tester) async {
      final dbPath = join(await getDatabasesPath(), 'music_life.db');
      final legacy = await openDatabase(
        dbPath,
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE recordings (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              recorded_at TEXT NOT NULL,
              duration_seconds INTEGER NOT NULL,
              waveform_data TEXT NOT NULL
            )
          ''');
        },
      );
      await legacy.insert('recordings', {
        'id': 'r1',
        'title': 'legacy',
        'recorded_at': DateTime(2024).toIso8601String(),
        'duration_seconds': 2,
        'waveform_data': jsonEncode([0.25, -0.5]),
      });
      await legacy.close();

      final migrated = await AppDatabase.instance.database;
      final rows = await migrated.query('recordings');

      expect(rows, hasLength(1));
      final blob = rows.single['waveform_data'] as Uint8List;
      final byteData = blob.buffer.asByteData(blob.offsetInBytes, blob.lengthInBytes);
      expect(byteData.getFloat64(0, Endian.little), closeTo(0.25, 1e-9));
      expect(byteData.getFloat64(8, Endian.little), closeTo(-0.5, 1e-9));
    });

    testWidgets('interrupted migration renames recordings_new to recordings',
        (tester) async {
      final dbPath = join(await getDatabasesPath(), 'music_life.db');
      final legacy = await openDatabase(
        dbPath,
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE recordings_new (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              recorded_at TEXT NOT NULL,
              duration_seconds INTEGER NOT NULL,
              waveform_data BLOB NOT NULL
            )
          ''');
        },
      );
      await legacy.insert('recordings_new', {
        'id': 'r2',
        'title': 'partial',
        'recorded_at': DateTime(2024).toIso8601String(),
        'duration_seconds': 1,
        'waveform_data': Uint8List.fromList(List<int>.filled(8, 0)),
      });
      await legacy.close();

      final migrated = await AppDatabase.instance.database;
      final rows = await migrated.query('recordings');

      expect(rows, hasLength(1));
      expect(rows.single['id'], 'r2');
    });
  });
}

class _TestPitchBridge extends Mock implements NativePitchBridge {
  _TestPitchBridge() {
    when(() => startCapture()).thenAnswer((_) async => true);
    when(() => dispose()).thenReturn(null);
    when(() => pitchStream).thenAnswer((_) => _pitchController.stream);
    when(() => chordStream).thenAnswer((_) => _chordController.stream);
    instances.add(this);
  }

  static final List<_TestPitchBridge> instances = <_TestPitchBridge>[];

  final StreamController<PitchResult> _pitchController =
      StreamController<PitchResult>.broadcast();
  final StreamController<String> _chordController =
      StreamController<String>.broadcast();

  void emitPitch(PitchResult result) => _pitchController.add(result);

  void emitChord(String chord) => _chordController.add(chord);
}
