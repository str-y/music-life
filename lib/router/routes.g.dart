// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'routes.dart';

List<RouteBase> get $appRoutes => [
      $homeRoute,
      $tunerRoute,
      $practiceLogRoute,
      $libraryRoute,
      $recordingsRoute,
      $libraryLogsRoute,
      $rhythmRoute,
      $chordAnalyserRoute,
      $compositionHelperRoute,
    ];

RouteBase get $homeRoute => GoRouteData.$route(
      path: '/',
      factory: $HomeRouteExtension._fromState,
    );

extension $HomeRouteExtension on HomeRoute {
  static HomeRoute _fromState(GoRouterState state) => const HomeRoute();

  String get location => GoRouteData.$location('/');

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $tunerRoute => GoRouteData.$route(
      path: '/tuner',
      factory: $TunerRouteExtension._fromState,
    );

extension $TunerRouteExtension on TunerRoute {
  static TunerRoute _fromState(GoRouterState state) => const TunerRoute();

  String get location => GoRouteData.$location('/tuner');

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $practiceLogRoute => GoRouteData.$route(
      path: '/practice-log',
      factory: $PracticeLogRouteExtension._fromState,
    );

extension $PracticeLogRouteExtension on PracticeLogRoute {
  static PracticeLogRoute _fromState(GoRouterState state) =>
      const PracticeLogRoute();

  String get location => GoRouteData.$location('/practice-log');

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $libraryRoute => GoRouteData.$route(
      path: '/library',
      factory: $LibraryRouteExtension._fromState,
    );

extension $LibraryRouteExtension on LibraryRoute {
  static LibraryRoute _fromState(GoRouterState state) => const LibraryRoute();

  String get location => GoRouteData.$location('/library');

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $recordingsRoute => GoRouteData.$route(
      path: '/recordings',
      factory: $RecordingsRouteExtension._fromState,
    );

extension $RecordingsRouteExtension on RecordingsRoute {
  static RecordingsRoute _fromState(GoRouterState state) =>
      const RecordingsRoute();

  String get location => GoRouteData.$location('/recordings');

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $libraryLogsRoute => GoRouteData.$route(
      path: '/library/logs',
      factory: $LibraryLogsRouteExtension._fromState,
    );

extension $LibraryLogsRouteExtension on LibraryLogsRoute {
  static LibraryLogsRoute _fromState(GoRouterState state) =>
      const LibraryLogsRoute();

  String get location => GoRouteData.$location('/library/logs');

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $rhythmRoute => GoRouteData.$route(
      path: '/rhythm',
      factory: $RhythmRouteExtension._fromState,
    );

extension $RhythmRouteExtension on RhythmRoute {
  static RhythmRoute _fromState(GoRouterState state) => const RhythmRoute();

  String get location => GoRouteData.$location('/rhythm');

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $chordAnalyserRoute => GoRouteData.$route(
      path: '/chord-analyser',
      factory: $ChordAnalyserRouteExtension._fromState,
    );

extension $ChordAnalyserRouteExtension on ChordAnalyserRoute {
  static ChordAnalyserRoute _fromState(GoRouterState state) =>
      const ChordAnalyserRoute();

  String get location => GoRouteData.$location('/chord-analyser');

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $compositionHelperRoute => GoRouteData.$route(
      path: '/composition-helper',
      factory: $CompositionHelperRouteExtension._fromState,
    );

extension $CompositionHelperRouteExtension on CompositionHelperRoute {
  static CompositionHelperRoute _fromState(GoRouterState state) =>
      const CompositionHelperRoute();

  String get location => GoRouteData.$location('/composition-helper');

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}
