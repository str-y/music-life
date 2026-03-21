// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'routes.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

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
  $videoPracticeRoute,
];

RouteBase get $homeRoute =>
    GoRouteData.$route(path: '/', factory: $HomeRoute._fromState);

mixin $HomeRoute on GoRouteData {
  static HomeRoute _fromState(GoRouterState state) => const HomeRoute();

  @override
  String get location => GoRouteData.$location('/');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $tunerRoute =>
    GoRouteData.$route(path: '/tuner', factory: $TunerRoute._fromState);

mixin $TunerRoute on GoRouteData {
  static TunerRoute _fromState(GoRouterState state) => const TunerRoute();

  @override
  String get location => GoRouteData.$location('/tuner');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $practiceLogRoute => GoRouteData.$route(
  path: '/practice-log',
  factory: $PracticeLogRoute._fromState,
);

mixin $PracticeLogRoute on GoRouteData {
  static PracticeLogRoute _fromState(GoRouterState state) =>
      const PracticeLogRoute();

  @override
  String get location => GoRouteData.$location('/practice-log');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $libraryRoute =>
    GoRouteData.$route(path: '/library', factory: $LibraryRoute._fromState);

mixin $LibraryRoute on GoRouteData {
  static LibraryRoute _fromState(GoRouterState state) => const LibraryRoute();

  @override
  String get location => GoRouteData.$location('/library');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $recordingsRoute => GoRouteData.$route(
  path: '/recordings',
  factory: $RecordingsRoute._fromState,
);

mixin $RecordingsRoute on GoRouteData {
  static RecordingsRoute _fromState(GoRouterState state) =>
      const RecordingsRoute();

  @override
  String get location => GoRouteData.$location('/recordings');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $libraryLogsRoute => GoRouteData.$route(
  path: '/library/logs',
  factory: $LibraryLogsRoute._fromState,
);

mixin $LibraryLogsRoute on GoRouteData {
  static LibraryLogsRoute _fromState(GoRouterState state) =>
      const LibraryLogsRoute();

  @override
  String get location => GoRouteData.$location('/library/logs');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $rhythmRoute =>
    GoRouteData.$route(path: '/rhythm', factory: $RhythmRoute._fromState);

mixin $RhythmRoute on GoRouteData {
  static RhythmRoute _fromState(GoRouterState state) => const RhythmRoute();

  @override
  String get location => GoRouteData.$location('/rhythm');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $chordAnalyserRoute => GoRouteData.$route(
  path: '/chord-analyser',
  factory: $ChordAnalyserRoute._fromState,
);

mixin $ChordAnalyserRoute on GoRouteData {
  static ChordAnalyserRoute _fromState(GoRouterState state) =>
      const ChordAnalyserRoute();

  @override
  String get location => GoRouteData.$location('/chord-analyser');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $compositionHelperRoute => GoRouteData.$route(
  path: '/composition-helper',
  factory: $CompositionHelperRoute._fromState,
);

mixin $CompositionHelperRoute on GoRouteData {
  static CompositionHelperRoute _fromState(GoRouterState state) =>
      const CompositionHelperRoute();

  @override
  String get location => GoRouteData.$location('/composition-helper');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $videoPracticeRoute => GoRouteData.$route(
  path: '/video-practice',
  factory: $VideoPracticeRoute._fromState,
);

mixin $VideoPracticeRoute on GoRouteData {
  static VideoPracticeRoute _fromState(GoRouterState state) =>
      const VideoPracticeRoute();

  @override
  String get location => GoRouteData.$location('/video-practice');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}
