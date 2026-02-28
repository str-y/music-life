/// Returns the duration of one beat at the given [bpm].
Duration beatDurationFor(int bpm) =>
    Duration(microseconds: 60 * 1000 * 1000 ~/ bpm);

/// Maps [elapsedMs] (time since the last beat) into a signed offset within
/// the range `[-beatMs/2, +beatMs/2]`.
///
/// A negative result means the tap was early; positive means late.
double computeGrooveTapOffset({
  required double elapsedMs,
  required double beatMs,
}) {
  double offset = elapsedMs;
  if (offset > beatMs / 2) offset -= beatMs;
  return offset;
}

/// Returns the score penalty (0–20 points) for a tap that was [offsetMs]
/// milliseconds away from the ideal beat in a bar of duration [beatMs].
double computeScorePenalty({
  required double offsetMs,
  required double beatMs,
}) {
  return (offsetMs.abs() / (beatMs / 2)) * 20;
}
