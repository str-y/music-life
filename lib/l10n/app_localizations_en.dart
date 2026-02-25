// ignore_for_file: type=lint
import 'app_localizations.dart';

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Music Life';

  @override
  String get settingsTooltip => 'Settings';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get openSettings => 'Open Settings';

  @override
  String get micPermissionRequired => 'Microphone permission is required.';

  @override
  String get micPermissionDenied =>
      'Microphone access is denied. Please allow it in Settings.';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get privacyPolicyOpenError => 'Could not open the Privacy Policy.';

  @override
  String get themeSection => 'Theme';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get calibration => 'Calibration';

  @override
  String get referencePitchLabel => 'Reference Pitch A =';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get previousMonth => 'Previous month';

  @override
  String get nextMonth => 'Next month';

  @override
  String get practiceDays => 'Practice days';

  @override
  String get totalTime => 'Total time';

  @override
  String get retry => 'Retry';

  @override
  String get welcomeTitle => 'Welcome';

  @override
  String get welcomeSubtitle => "Let's start today's practice.";

  @override
  String get tunerTitle => 'Tuner';

  @override
  String get tunerSubtitle => 'Check pitch in real-time';

  @override
  String get playSound => 'Please play a sound.';

  @override
  String get tuningOk => 'Tuning OK';

  @override
  String get practiceLogTitle => 'Practice Log';

  @override
  String get practiceLogSubtitle => 'Record practice time and notes';

  @override
  String get calendarTab => 'Calendar';

  @override
  String get recordListTab => 'Records';

  @override
  String get recordPractice => 'Record Practice';

  @override
  String get noPracticeRecords => 'No practice records';

  @override
  String get addRecordHint => 'Add a record with the + button';

  @override
  String get practiceDate => 'Practice date';

  @override
  String get notesOptional => 'Notes (optional)';

  @override
  String get notesHint => 'e.g. Scales, song practice';

  @override
  String get libraryTitle => 'Library';

  @override
  String get librarySubtitle => 'Playback recordings and practice logs';

  @override
  String get recordingsTab => 'Recordings';

  @override
  String get logsTab => 'Logs';

  @override
  String get noRecordings => 'No recordings';

  @override
  String get play => 'Play';

  @override
  String get pause => 'Pause';

  @override
  String get rhythmTitle => 'Rhythm & Metronome';

  @override
  String get rhythmSubtitle => 'Metronome and groove analysis';

  @override
  String get grooveAnalysis => 'Groove Analysis';

  @override
  String get timing => 'Timing';

  @override
  String get score => 'Score';

  @override
  String get tapRhythmHint => 'Tap to keep the rhythm';

  @override
  String get chordAnalyserTitle => 'Chord Analyser';

  @override
  String get chordAnalyserSubtitle => 'Analyze and display chords in real-time';

  @override
  String get currentChord => 'Current Chord';

  @override
  String get chordHistory => 'Chord progression history';

  @override
  String get noChordHistory => 'No history yet';

  @override
  String get weekdaySun => 'Sun';

  @override
  String get weekdayMon => 'Mon';

  @override
  String get weekdayTue => 'Tue';

  @override
  String get weekdayWed => 'Wed';

  @override
  String get weekdayThu => 'Thu';

  @override
  String get weekdayFri => 'Fri';

  @override
  String get weekdaySat => 'Sat';

  @override
  String get loadingLibrary => 'Loading recordings and practice logs';

  @override
  String get waveformSemanticLabel =>
      'Visual waveform representation of the recording';

  @override
  String get grooveTargetSemanticLabel => 'Groove Target';

  @override
  String get grooveTargetTapHint => 'Tap to rhythm';

  @override
  String get bpmLabel => 'BPM';

  @override
  String get metronomePlayTooltip => 'Start metronome';

  @override
  String get metronomeStopTooltip => 'Stop metronome';

  @override
  String yearMonth(int year, int month) => '$year/$month';

  @override
  String practiceDayCount(int count) => '$count days';

  @override
  String durationMinutes(int minutes) => '$minutes min';

  @override
  String practiceDurationLabel(int minutes) => 'Practice time: $minutes min';
}
