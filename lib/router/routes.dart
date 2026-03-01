import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../rhythm_screen.dart';
import '../screens/chord_analyser_screen.dart';
import '../screens/composition_helper_screen.dart';
import '../screens/library_screen.dart';
import '../screens/main_screen.dart';
import '../screens/practice_log_screen.dart';
import '../screens/tuner_screen.dart';

part 'routes.g.dart';

@TypedGoRoute<HomeRoute>(path: '/')
class HomeRoute extends GoRouteData {
  const HomeRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const MainScreen();
}

@TypedGoRoute<TunerRoute>(path: '/tuner')
class TunerRoute extends GoRouteData {
  const TunerRoute();

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      slideUpPage(state: state, child: const TunerScreen());
}

@TypedGoRoute<PracticeLogRoute>(path: '/practice-log')
class PracticeLogRoute extends GoRouteData {
  const PracticeLogRoute();

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      slideUpPage(state: state, child: const PracticeLogScreen());
}

@TypedGoRoute<LibraryRoute>(path: '/library')
class LibraryRoute extends GoRouteData {
  const LibraryRoute();

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      slideUpPage(state: state, child: const LibraryScreen());
}

@TypedGoRoute<RecordingsRoute>(path: '/recordings')
class RecordingsRoute extends GoRouteData {
  const RecordingsRoute();

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      slideUpPage(state: state, child: const LibraryScreen(initialTabIndex: 0));
}

@TypedGoRoute<LibraryLogsRoute>(path: '/library/logs')
class LibraryLogsRoute extends GoRouteData {
  const LibraryLogsRoute();

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      slideUpPage(state: state, child: const LibraryScreen(initialTabIndex: 1));
}

@TypedGoRoute<RhythmRoute>(path: '/rhythm')
class RhythmRoute extends GoRouteData {
  const RhythmRoute();

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      slideUpPage(state: state, child: const RhythmScreen());
}

@TypedGoRoute<ChordAnalyserRoute>(path: '/chord-analyser')
class ChordAnalyserRoute extends GoRouteData {
  const ChordAnalyserRoute();

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      slideUpPage(state: state, child: const ChordAnalyserScreen());
}

@TypedGoRoute<CompositionHelperRoute>(path: '/composition-helper')
class CompositionHelperRoute extends GoRouteData {
  const CompositionHelperRoute();

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      slideUpPage(state: state, child: const CompositionHelperScreen());
}

/// A page with a subtle slide-up + fade entrance animation.
CustomTransitionPage<void> slideUpPage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 320),
  );
}
