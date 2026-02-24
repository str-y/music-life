// ignore_for_file: type=lint
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';

/// Callers can look up localized strings with an instance of [AppLocalizations]
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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// The locales that this app supports.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
  ];

  // ── Simple getters ──────────────────────────────────────────────────────────

  String get appTitle;
  String get settingsTooltip;
  String get settingsTitle;
  String get openSettings;
  String get micPermissionRequired;
  String get micPermissionDenied;
  String get privacyPolicy;
  String get privacyPolicyOpenError;
  String get themeSection;
  String get darkMode;
  String get calibration;
  String get referencePitchLabel;
  String get cancel;
  String get save;
  String get previousMonth;
  String get nextMonth;
  String get practiceDays;
  String get totalTime;
  String get retry;
  String get welcomeTitle;
  String get welcomeSubtitle;
  String get tunerTitle;
  String get tunerSubtitle;
  String get playSound;
  String get tuningOk;
  String get practiceLogTitle;
  String get practiceLogSubtitle;
  String get calendarTab;
  String get recordListTab;
  String get recordPractice;
  String get noPracticeRecords;
  String get addRecordHint;
  String get practiceDate;
  String get notesOptional;
  String get notesHint;
  String get libraryTitle;
  String get librarySubtitle;
  String get recordingsTab;
  String get logsTab;
  String get noRecordings;
  String get play;
  String get pause;
  String get rhythmTitle;
  String get rhythmSubtitle;
  String get grooveAnalysis;
  String get timing;
  String get score;
  String get tapRhythmHint;
  String get chordAnalyserTitle;
  String get chordAnalyserSubtitle;
  String get currentChord;
  String get chordHistory;
  String get noChordHistory;
  String get weekdaySun;
  String get weekdayMon;
  String get weekdayTue;
  String get weekdayWed;
  String get weekdayThu;
  String get weekdayFri;
  String get weekdaySat;

  // ── Accessibility / semantics ────────────────────────────────────────────────

  String get loadingLibrary;
  String get waveformSemanticLabel;
  String get grooveTargetSemanticLabel;
  String get grooveTargetTapHint;

  // ── Composition Helper ───────────────────────────────────────────────────────

  String get compositionHelperTitle;
  String get compositionHelperSubtitle;
  String get compositionPalette;
  String get compositionEmpty;
  String get compositionPlay;
  String get compositionStop;
  String get compositionSave;
  String get compositionLoad;
  String get compositionTitle;
  String get compositionSavedSuccess;
  String get compositionNoSaved;
  String get compositionDelete;
  String get compositionClear;
  String get compositionDeleteProject;
  String get compositionAddChord;
  String get compositionUntitled;

  // ── Parameterized methods ───────────────────────────────────────────────────

  String yearMonth(int year, int month);
  String practiceDayCount(int count);
  String durationMinutes(int minutes);
  String practiceDurationLabel(int minutes);
  String compositionSequence(int count);
  String compositionBpmLabel(int bpm);
  String compositionLoadSuccess(String title);
  String compositionChordCount(int count);
  String compositionDefaultName(int number);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(
        lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
  }
  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale".');
}
