import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja')
  ];

  /// The application title
  ///
  /// In en, this message translates to:
  /// **'Music Life'**
  String get appTitle;

  /// Tooltip for the settings icon button
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTooltip;

  /// Title of the settings modal
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Button label to open app settings
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get openSettings;

  /// Snackbar message when microphone permission is not granted
  ///
  /// In en, this message translates to:
  /// **'Microphone permission is required.'**
  String get micPermissionRequired;

  /// Snackbar message when microphone permission is permanently denied
  ///
  /// In en, this message translates to:
  /// **'Microphone access is denied. Please allow it in Settings.'**
  String get micPermissionDenied;

  /// Label for the privacy policy link
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// Snackbar message when the privacy policy URL fails to open
  ///
  /// In en, this message translates to:
  /// **'Could not open the Privacy Policy.'**
  String get privacyPolicyOpenError;

  /// Section header for theme settings
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeSection;

  /// Label for the dark mode toggle
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// Section header for calibration settings
  ///
  /// In en, this message translates to:
  /// **'Calibration'**
  String get calibration;

  /// Label for the reference pitch slider
  ///
  /// In en, this message translates to:
  /// **'Reference Pitch A ='**
  String get referencePitchLabel;

  /// Cancel button label
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Save button label
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Tooltip for the previous month navigation button
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get previousMonth;

  /// Tooltip for the next month navigation button
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get nextMonth;

  /// Label for the practice days count in the summary
  ///
  /// In en, this message translates to:
  /// **'Practice days'**
  String get practiceDays;

  /// Label for the total practice time in the summary
  ///
  /// In en, this message translates to:
  /// **'Total time'**
  String get totalTime;

  /// Retry button label
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Welcome headline on the main screen
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcomeTitle;

  /// Welcome sub-headline on the main screen
  ///
  /// In en, this message translates to:
  /// **'Let\'s start today\'s practice.'**
  String get welcomeSubtitle;

  /// Title of the Tuner screen
  ///
  /// In en, this message translates to:
  /// **'Tuner'**
  String get tunerTitle;

  /// Subtitle for the Tuner card on the main screen
  ///
  /// In en, this message translates to:
  /// **'Check pitch in real-time'**
  String get tunerSubtitle;

  /// Prompt shown in the tuner when waiting for audio input
  ///
  /// In en, this message translates to:
  /// **'Please play a sound.'**
  String get playSound;

  /// Message shown when the note is in tune
  ///
  /// In en, this message translates to:
  /// **'Tuning OK'**
  String get tuningOk;

  /// Accessibility label for the tuner cents arc meter
  ///
  /// In en, this message translates to:
  /// **'Cents meter'**
  String get centsMeterSemanticLabel;

  /// Title of the Practice Log screen
  ///
  /// In en, this message translates to:
  /// **'Practice Log'**
  String get practiceLogTitle;

  /// Subtitle for the Practice Log card on the main screen
  ///
  /// In en, this message translates to:
  /// **'Record practice time and notes'**
  String get practiceLogSubtitle;

  /// Label for the calendar tab
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendarTab;

  /// Label for the record list tab
  ///
  /// In en, this message translates to:
  /// **'Records'**
  String get recordListTab;

  /// FAB tooltip and dialog title for adding a practice log entry
  ///
  /// In en, this message translates to:
  /// **'Record Practice'**
  String get recordPractice;

  /// Empty state message in the practice log list
  ///
  /// In en, this message translates to:
  /// **'No practice records'**
  String get noPracticeRecords;

  /// Hint shown below the empty state message in the practice log list
  ///
  /// In en, this message translates to:
  /// **'Add a record with the + button'**
  String get addRecordHint;

  /// Subtitle for the date picker in the add practice dialog
  ///
  /// In en, this message translates to:
  /// **'Practice date'**
  String get practiceDate;

  /// Label for the optional notes field in the add practice dialog
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get notesOptional;

  /// Hint text for the notes field in the add practice dialog
  ///
  /// In en, this message translates to:
  /// **'e.g. Scales, song practice'**
  String get notesHint;

  /// Title of the Library screen
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get libraryTitle;

  /// Subtitle for the Library card on the main screen
  ///
  /// In en, this message translates to:
  /// **'Playback recordings and practice logs'**
  String get librarySubtitle;

  /// Label for the recordings tab in the Library screen
  ///
  /// In en, this message translates to:
  /// **'Recordings'**
  String get recordingsTab;

  /// Label for the logs tab in the Library screen
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get logsTab;

  /// Empty state message in the recordings list
  ///
  /// In en, this message translates to:
  /// **'No recordings'**
  String get noRecordings;

  /// Tooltip for the play button
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// Tooltip for the pause button
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// Title of the Rhythm & Metronome screen
  ///
  /// In en, this message translates to:
  /// **'Rhythm & Metronome'**
  String get rhythmTitle;

  /// Subtitle for the Rhythm card on the main screen
  ///
  /// In en, this message translates to:
  /// **'Metronome and groove analysis'**
  String get rhythmSubtitle;

  /// Section label for the groove analysis panel
  ///
  /// In en, this message translates to:
  /// **'Groove Analysis'**
  String get grooveAnalysis;

  /// Label for the timing readout in the groove analysis panel
  ///
  /// In en, this message translates to:
  /// **'Timing'**
  String get timing;

  /// Label for the score readout in the groove analysis panel
  ///
  /// In en, this message translates to:
  /// **'Score'**
  String get score;

  /// Hint shown while the metronome is playing
  ///
  /// In en, this message translates to:
  /// **'Tap to keep the rhythm'**
  String get tapRhythmHint;

  /// Title of the Chord Analyser screen
  ///
  /// In en, this message translates to:
  /// **'Chord Analyser'**
  String get chordAnalyserTitle;

  /// Subtitle for the Chord Analyser card on the main screen
  ///
  /// In en, this message translates to:
  /// **'Detect and display notes in real-time (monophonic)'**
  String get chordAnalyserSubtitle;

  /// Label above the currently detected note display
  ///
  /// In en, this message translates to:
  /// **'Detected Note'**
  String get currentChord;

  /// Section header for the detected note history timeline
  ///
  /// In en, this message translates to:
  /// **'Note history'**
  String get chordHistory;

  /// Empty state message in the chord history list
  ///
  /// In en, this message translates to:
  /// **'No history yet'**
  String get noChordHistory;

  /// Abbreviated Sunday label in the calendar
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get weekdaySun;

  /// Abbreviated Monday label in the calendar
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get weekdayMon;

  /// Abbreviated Tuesday label in the calendar
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get weekdayTue;

  /// Abbreviated Wednesday label in the calendar
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get weekdayWed;

  /// Abbreviated Thursday label in the calendar
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get weekdayThu;

  /// Abbreviated Friday label in the calendar
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get weekdayFri;

  /// Abbreviated Saturday label in the calendar
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get weekdaySat;

  /// Formatted year and month for the calendar header
  ///
  /// In en, this message translates to:
  /// **'{year}/{month}'**
  String yearMonth(int year, int month);

  /// Number of practice days in the summary card
  ///
  /// In en, this message translates to:
  /// **'{count} days'**
  String practiceDayCount(int count);

  /// Duration displayed as minutes
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String durationMinutes(int minutes);

  /// Label showing selected practice duration in the add-practice dialog
  ///
  /// In en, this message translates to:
  /// **'Practice time: {minutes} min'**
  String practiceDurationLabel(int minutes);

  /// Error message shown on the Library screen when data fails to load
  ///
  /// In en, this message translates to:
  /// **'Could not load data. Please try again.'**
  String get loadDataError;

  /// Semantics label for the loading indicator on the Library screen
  ///
  /// In en, this message translates to:
  /// **'Loading recordings and practice logs'**
  String get loadingLibrary;

  /// Accessibility label for the waveform visualisation widget
  ///
  /// In en, this message translates to:
  /// **'Visual waveform representation of the recording'**
  String get waveformSemanticLabel;

  /// Accessibility value for the waveform widget, describing the recording duration
  ///
  /// In en, this message translates to:
  /// **'Recording length: {duration}'**
  String waveformSemanticValue(String duration);

  /// Accessibility label for the groove target area in the Rhythm screen
  ///
  /// In en, this message translates to:
  /// **'Groove Target'**
  String get grooveTargetSemanticLabel;

  /// Accessibility tap hint for the groove target area in the Rhythm screen
  ///
  /// In en, this message translates to:
  /// **'Tap to rhythm'**
  String get grooveTargetTapHint;

  /// Title of the Composition Helper screen
  ///
  /// In en, this message translates to:
  /// **'Composition Helper'**
  String get compositionHelperTitle;

  /// Subtitle for the Composition Helper card on the main screen
  ///
  /// In en, this message translates to:
  /// **'Build and preview chord sequences'**
  String get compositionHelperSubtitle;

  /// Section header for the chord palette in the Composition Helper
  ///
  /// In en, this message translates to:
  /// **'Chord Palette'**
  String get compositionPalette;

  /// Section header for the chord sequence in the Composition Helper
  ///
  /// In en, this message translates to:
  /// **'Chord Sequence ({count})'**
  String compositionSequence(int count);

  /// Empty state message shown when the chord sequence is empty
  ///
  /// In en, this message translates to:
  /// **'Tap a chord above to add it to your sequence'**
  String get compositionEmpty;

  /// Label for the play button in the Composition Helper
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get compositionPlay;

  /// Label for the stop button in the Composition Helper
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get compositionStop;

  /// Tooltip and dialog title for saving a composition
  ///
  /// In en, this message translates to:
  /// **'Save Composition'**
  String get compositionSave;

  /// Tooltip and sheet title for loading a saved composition
  ///
  /// In en, this message translates to:
  /// **'Load Composition'**
  String get compositionLoad;

  /// Label for the name field in the save composition dialog
  ///
  /// In en, this message translates to:
  /// **'Composition Name'**
  String get compositionTitle;

  /// Snackbar message shown after a composition is saved successfully
  ///
  /// In en, this message translates to:
  /// **'Composition saved'**
  String get compositionSavedSuccess;

  /// Empty state message in the load composition sheet
  ///
  /// In en, this message translates to:
  /// **'No saved compositions'**
  String get compositionNoSaved;

  /// Label showing the current BPM value in the playback controls
  ///
  /// In en, this message translates to:
  /// **'BPM: {bpm}'**
  String compositionBpmLabel(int bpm);

  /// Tooltip for the remove-chord button in the sequence list
  ///
  /// In en, this message translates to:
  /// **'Remove chord'**
  String get compositionDelete;

  /// Label for the clear-sequence button
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get compositionClear;

  /// Tooltip for the delete button in the load composition sheet
  ///
  /// In en, this message translates to:
  /// **'Delete composition'**
  String get compositionDeleteProject;

  /// Snackbar message shown after a composition is loaded
  ///
  /// In en, this message translates to:
  /// **'Loaded: {title}'**
  String compositionLoadSuccess(String title);

  /// Prefix for the tooltip on palette chord chips
  ///
  /// In en, this message translates to:
  /// **'Add chord'**
  String get compositionAddChord;

  /// Subtitle in the load sheet showing how many chords a composition has
  ///
  /// In en, this message translates to:
  /// **'{count} chords'**
  String compositionChordCount(int count);

  /// Default name pre-filled in the save composition dialog
  ///
  /// In en, this message translates to:
  /// **'Composition {number}'**
  String compositionDefaultName(int number);

  /// Fallback title used when the user saves a composition with an empty name
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get compositionUntitled;

  /// Label displayed beneath the BPM number on the Rhythm screen
  ///
  /// In en, this message translates to:
  /// **'BPM'**
  String get bpmLabel;

  /// Tooltip for the play/start button on the Rhythm screen
  ///
  /// In en, this message translates to:
  /// **'Start metronome'**
  String get metronomePlayTooltip;

  /// Tooltip for the stop button on the Rhythm screen
  ///
  /// In en, this message translates to:
  /// **'Stop metronome'**
  String get metronomeStopTooltip;

  /// FAB tooltip and dialog title for adding a new recording entry
  ///
  /// In en, this message translates to:
  /// **'New Recording'**
  String get newRecording;

  /// Label for the title field in the add-recording dialog
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get recordingTitleLabel;

  /// Hint text for the title field in the add-recording dialog
  ///
  /// In en, this message translates to:
  /// **'e.g. Session 1'**
  String get recordingTitleHint;

  /// Label showing selected duration in the add-recording dialog
  ///
  /// In en, this message translates to:
  /// **'Duration: {seconds} sec'**
  String recordingDurationLabel(int seconds);

  /// SnackBar message shown after a recording is successfully saved
  ///
  /// In en, this message translates to:
  /// **'Recording saved to library'**
  String get recordingSavedSuccess;

  /// SnackBar message shown when the chord analyser bridge fails to start or encounters a runtime error
  ///
  /// In en, this message translates to:
  /// **'Could not start chord detection. Please try again.'**
  String get chordAnalyserError;

  /// SnackBar message shown when saving a composition fails
  ///
  /// In en, this message translates to:
  /// **'Could not save composition. Please try again.'**
  String get compositionSaveError;

  /// SnackBar message shown when loading saved compositions fails
  ///
  /// In en, this message translates to:
  /// **'Could not load compositions.'**
  String get compositionLoadError;

  /// SnackBar message shown when deleting a composition fails
  ///
  /// In en, this message translates to:
  /// **'Could not delete composition.'**
  String get compositionDeleteError;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
