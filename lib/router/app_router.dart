import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../rhythm_screen.dart';
import '../screens/chord_analyser_screen.dart';
import '../screens/composition_helper_screen.dart';
import '../screens/library_screen.dart';
import '../screens/main_screen.dart';
import '../screens/practice_log_screen.dart';
import '../screens/tuner_screen.dart';

GoRouter buildAppRouter({String? initialLocation}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const MainScreen(),
      ),
      GoRoute(
        path: '/tuner',
        pageBuilder: (context, state) =>
            _slideUpPage(state: state, child: const TunerScreen()),
      ),
      GoRoute(
        path: '/practice-log',
        pageBuilder: (context, state) =>
            _slideUpPage(state: state, child: const PracticeLogScreen()),
      ),
      GoRoute(
        path: '/library',
        pageBuilder: (context, state) =>
            _slideUpPage(state: state, child: const LibraryScreen()),
      ),
      GoRoute(
        path: '/recordings',
        pageBuilder: (context, state) => _slideUpPage(
          state: state,
          child: const LibraryScreen(initialTabIndex: 0),
        ),
      ),
      GoRoute(
        path: '/library/logs',
        pageBuilder: (context, state) => _slideUpPage(
          state: state,
          child: const LibraryScreen(initialTabIndex: 1),
        ),
      ),
      GoRoute(
        path: '/rhythm',
        pageBuilder: (context, state) =>
            _slideUpPage(state: state, child: const RhythmScreen()),
      ),
      GoRoute(
        path: '/chord-analyser',
        pageBuilder: (context, state) =>
            _slideUpPage(state: state, child: const ChordAnalyserScreen()),
      ),
      GoRoute(
        path: '/composition-helper',
        pageBuilder: (context, state) => _slideUpPage(
          state: state,
          child: const CompositionHelperScreen(),
        ),
      ),
    ],
  );
}

/// A page with a subtle slide-up + fade entrance animation.
CustomTransitionPage<void> _slideUpPage({
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
