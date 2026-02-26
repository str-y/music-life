// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

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
  String get welcomeSubtitle => 'Let\'s start today\'s practice.';

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
  String get chordAnalyserSubtitle =>
      'Detect and display notes in real-time (monophonic)';

  @override
  String get currentChord => 'Detected Note';

  @override
  String get chordHistory => 'Note history';

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
  String yearMonth(int year, int month) {
    return '$year/$month';
  }

  @override
  String practiceDayCount(int count) {
    return '$count days';
  }

  @override
  String durationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String practiceDurationLabel(int minutes) {
    return 'Practice time: $minutes min';
  }

  @override
  String get loadDataError => 'Could not load data. Please try again.';

  @override
  String get loadingLibrary => 'Loading recordings and practice logs';

  @override
  String get waveformSemanticLabel =>
      'Visual waveform representation of the recording';

  @override
  String waveformSemanticValue(String duration) {
    return 'Recording length: $duration';
  }

  @override
  String get grooveTargetSemanticLabel => 'Groove Target';

  @override
  String get grooveTargetTapHint => 'Tap to rhythm';

  @override
  String get compositionHelperTitle => 'Composition Helper';

  @override
  String get compositionHelperSubtitle => 'Build and preview chord sequences';

  @override
  String get compositionPalette => 'Chord Palette';

  @override
  String compositionSequence(int count) {
    return 'Chord Sequence ($count)';
  }

  @override
  String get compositionEmpty => 'Tap a chord above to add it to your sequence';

  @override
  String get compositionPlay => 'Play';

  @override
  String get compositionStop => 'Stop';

  @override
  String get compositionSave => 'Save Composition';

  @override
  String get compositionLoad => 'Load Composition';

  @override
  String get compositionTitle => 'Composition Name';

  @override
  String get compositionSavedSuccess => 'Composition saved';

  @override
  String get compositionNoSaved => 'No saved compositions';

  @override
  String compositionBpmLabel(int bpm) {
    return 'BPM: $bpm';
  }

  @override
  String get compositionDelete => 'Remove chord';

  @override
  String get compositionClear => 'Clear';

  @override
  String get compositionDeleteProject => 'Delete composition';

  @override
  String compositionLoadSuccess(String title) {
    return 'Loaded: $title';
  }

  @override
  String get compositionAddChord => 'Add chord';

  @override
  String compositionChordCount(int count) {
    return '$count chords';
  }

  @override
  String compositionDefaultName(int number) {
    return 'Composition $number';
  }

  @override
  String get compositionUntitled => 'Untitled';

  @override
  String get bpmLabel => 'BPM';

  @override
  String get metronomePlayTooltip => 'Start metronome';

  @override
  String get metronomeStopTooltip => 'Stop metronome';

  @override
  String get newRecording => 'New Recording';

  @override
  String get recordingTitleLabel => 'Title';

  @override
  String get recordingTitleHint => 'e.g. Session 1';

  @override
  String recordingDurationLabel(int seconds) {
    return 'Duration: $seconds sec';
  }

  @override
  String get recordingSavedSuccess => 'Recording saved to library';
}
