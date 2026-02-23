// ignore_for_file: type=lint
import 'app_localizations.dart';

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'Music Life';

  @override
  String get settingsTooltip => '設定';

  @override
  String get settingsTitle => '設定';

  @override
  String get openSettings => '設定を開く';

  @override
  String get micPermissionRequired => 'マイクへのアクセス許可が必要です。';

  @override
  String get micPermissionDenied =>
      'マイクのアクセスが拒否されています。設定から許可してください。';

  @override
  String get privacyPolicy => 'プライバシーポリシー';

  @override
  String get privacyPolicyOpenError => 'プライバシーポリシーを開けませんでした';

  @override
  String get themeSection => 'テーマ';

  @override
  String get darkMode => 'ダークモード';

  @override
  String get calibration => 'キャリブレーション';

  @override
  String get referencePitchLabel => '基準ピッチ A =';

  @override
  String get cancel => 'キャンセル';

  @override
  String get save => '保存';

  @override
  String get previousMonth => '前の月';

  @override
  String get nextMonth => '次の月';

  @override
  String get practiceDays => '練習日数';

  @override
  String get totalTime => '合計時間';

  @override
  String get retry => '再試行';

  @override
  String get welcomeTitle => 'ようこそ';

  @override
  String get welcomeSubtitle => '今日の練習をはじめましょう。';

  @override
  String get tunerTitle => 'チューナー';

  @override
  String get tunerSubtitle => '音程をリアルタイムで確認';

  @override
  String get playSound => '音を鳴らしてください';

  @override
  String get tuningOk => 'チューニング OK';

  @override
  String get practiceLogTitle => '練習ログ';

  @override
  String get practiceLogSubtitle => '練習時間とメモを記録';

  @override
  String get calendarTab => 'カレンダー';

  @override
  String get recordListTab => '記録一覧';

  @override
  String get recordPractice => '練習を記録';

  @override
  String get noPracticeRecords => '練習記録がありません';

  @override
  String get addRecordHint => '＋ボタンで記録を追加しましょう';

  @override
  String get practiceDate => '練習日';

  @override
  String get notesOptional => 'メモ（任意）';

  @override
  String get notesHint => '例: スケール練習、曲の練習';

  @override
  String get libraryTitle => 'ライブラリ';

  @override
  String get librarySubtitle => '録音データの再生と練習ログ';

  @override
  String get recordingsTab => '録音';

  @override
  String get logsTab => 'ログ';

  @override
  String get noRecordings => '録音データがありません';

  @override
  String get play => '再生';

  @override
  String get pause => '一時停止';

  @override
  String get rhythmTitle => 'リズム & メトロノーム';

  @override
  String get rhythmSubtitle => 'メトロノームとグルーヴ解析';

  @override
  String get grooveAnalysis => 'グルーヴ解析';

  @override
  String get timing => 'タイミング';

  @override
  String get score => 'スコア';

  @override
  String get tapRhythmHint => 'タップしてリズムを刻もう';

  @override
  String get chordAnalyserTitle => 'コード解析';

  @override
  String get chordAnalyserSubtitle => 'リアルタイムでコードを解析・表示';

  @override
  String get currentChord => '現在のコード';

  @override
  String get chordHistory => 'コード進行の履歴';

  @override
  String get noChordHistory => 'まだ履歴がありません';

  @override
  String get weekdaySun => '日';

  @override
  String get weekdayMon => '月';

  @override
  String get weekdayTue => '火';

  @override
  String get weekdayWed => '水';

  @override
  String get weekdayThu => '木';

  @override
  String get weekdayFri => '金';

  @override
  String get weekdaySat => '土';

  @override
  String yearMonth(int year, int month) => '$year年$month月';

  @override
  String practiceDayCount(int count) => '$count日';

  @override
  String durationMinutes(int minutes) => '$minutes分';

  @override
  String practiceDurationLabel(int minutes) => '練習時間: $minutes 分';
}
