import 'package:flutter/material.dart';

/// A centered loading indicator that keeps loading states visually consistent.
///
/// Use this for full-screen or section-level async loading states where a
/// single progress spinner is sufficient. Provide [semanticsLabel] when the
/// loading context should be announced to assistive technologies.
class LoadingStateWidget extends StatelessWidget {
  const LoadingStateWidget({super.key, this.semanticsLabel});

  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(semanticsLabel: semanticsLabel),
    );
  }
}
