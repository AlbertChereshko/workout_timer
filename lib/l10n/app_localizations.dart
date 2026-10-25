import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_hr.dart';
import 'app_localizations_ru.dart';

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
    Locale('de'),
    Locale('en'),
    Locale('hr'),
    Locale('ru')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Workout Timer'**
  String get appTitle;

  /// No description provided for @workouts.
  ///
  /// In en, this message translates to:
  /// **'Workouts'**
  String get workouts;

  /// No description provided for @newWorkout.
  ///
  /// In en, this message translates to:
  /// **'New Workout'**
  String get newWorkout;

  /// No description provided for @emom.
  ///
  /// In en, this message translates to:
  /// **'EMOM'**
  String get emom;

  /// No description provided for @tabata.
  ///
  /// In en, this message translates to:
  /// **'TABATA'**
  String get tabata;

  /// No description provided for @work.
  ///
  /// In en, this message translates to:
  /// **'WORK'**
  String get work;

  /// No description provided for @rest.
  ///
  /// In en, this message translates to:
  /// **'REST'**
  String get rest;

  /// No description provided for @round.
  ///
  /// In en, this message translates to:
  /// **'Round'**
  String get round;

  /// No description provided for @outOf.
  ///
  /// In en, this message translates to:
  /// **'of'**
  String get outOf;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @sounds.
  ///
  /// In en, this message translates to:
  /// **'Sounds'**
  String get sounds;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @russian.
  ///
  /// In en, this message translates to:
  /// **'Русский'**
  String get russian;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @german.
  ///
  /// In en, this message translates to:
  /// **'Deutsch'**
  String get german;

  /// No description provided for @croatian.
  ///
  /// In en, this message translates to:
  /// **'Hrvatski'**
  String get croatian;

  /// No description provided for @rounds.
  ///
  /// In en, this message translates to:
  /// **'Rounds'**
  String get rounds;

  /// No description provided for @workTime.
  ///
  /// In en, this message translates to:
  /// **'Work Time'**
  String get workTime;

  /// No description provided for @restTime.
  ///
  /// In en, this message translates to:
  /// **'Rest Time'**
  String get restTime;

  /// No description provided for @cycles.
  ///
  /// In en, this message translates to:
  /// **'Cycles'**
  String get cycles;

  /// No description provided for @exercises.
  ///
  /// In en, this message translates to:
  /// **'Exercises'**
  String get exercises;

  /// No description provided for @addExercise.
  ///
  /// In en, this message translates to:
  /// **'Add Exercise'**
  String get addExercise;

  /// No description provided for @exerciseName.
  ///
  /// In en, this message translates to:
  /// **'Exercise Name'**
  String get exerciseName;

  /// No description provided for @reps.
  ///
  /// In en, this message translates to:
  /// **'Reps'**
  String get reps;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @ready.
  ///
  /// In en, this message translates to:
  /// **'GET READY!'**
  String get ready;

  /// No description provided for @go.
  ///
  /// In en, this message translates to:
  /// **'GO!'**
  String get go;

  /// No description provided for @finished.
  ///
  /// In en, this message translates to:
  /// **'FINISHED!'**
  String get finished;

  /// No description provided for @workoutCompleted.
  ///
  /// In en, this message translates to:
  /// **'Workout Completed'**
  String get workoutCompleted;

  /// No description provided for @completedRounds.
  ///
  /// In en, this message translates to:
  /// **'Completed Rounds'**
  String get completedRounds;

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// No description provided for @noWorkouts.
  ///
  /// In en, this message translates to:
  /// **'No workouts. Create your first!'**
  String get noWorkouts;

  /// No description provided for @noHistory.
  ///
  /// In en, this message translates to:
  /// **'History is empty. Start working out!'**
  String get noHistory;

  /// No description provided for @confirmStop.
  ///
  /// In en, this message translates to:
  /// **'Stop the workout?'**
  String get confirmStop;

  /// No description provided for @confirmDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete workout?'**
  String get confirmDelete;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @soundBeep.
  ///
  /// In en, this message translates to:
  /// **'Beep'**
  String get soundBeep;

  /// No description provided for @soundWhistle.
  ///
  /// In en, this message translates to:
  /// **'Whistle'**
  String get soundWhistle;

  /// No description provided for @soundGong.
  ///
  /// In en, this message translates to:
  /// **'Gong'**
  String get soundGong;

  /// No description provided for @soundBell.
  ///
  /// In en, this message translates to:
  /// **'Bell'**
  String get soundBell;

  /// No description provided for @soundClick.
  ///
  /// In en, this message translates to:
  /// **'Click'**
  String get soundClick;

  /// No description provided for @startSound.
  ///
  /// In en, this message translates to:
  /// **'Start Sound'**
  String get startSound;

  /// No description provided for @endSound.
  ///
  /// In en, this message translates to:
  /// **'End Round Sound'**
  String get endSound;

  /// No description provided for @restSound.
  ///
  /// In en, this message translates to:
  /// **'Rest Sound'**
  String get restSound;

  /// No description provided for @finishSound.
  ///
  /// In en, this message translates to:
  /// **'Finish Sound'**
  String get finishSound;

  /// No description provided for @countdownSound.
  ///
  /// In en, this message translates to:
  /// **'Countdown Sound'**
  String get countdownSound;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @accountAndCloud.
  ///
  /// In en, this message translates to:
  /// **'Account & Cloud Backup'**
  String get accountAndCloud;

  /// No description provided for @offlineMode.
  ///
  /// In en, this message translates to:
  /// **'Offline Mode'**
  String get offlineMode;

  /// No description provided for @signInToSync.
  ///
  /// In en, this message translates to:
  /// **'Sign in to sync your workouts'**
  String get signInToSync;

  /// No description provided for @signInWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get signInWithGoogle;

  /// No description provided for @signingIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in...'**
  String get signingIn;

  /// No description provided for @syncedWithCloud.
  ///
  /// In en, this message translates to:
  /// **'Synced with cloud'**
  String get syncedWithCloud;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @signOutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out of account?'**
  String get signOutConfirmTitle;

  /// No description provided for @signOutConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Local workouts will remain on this device.'**
  String get signOutConfirmMessage;

  /// No description provided for @colorScheme.
  ///
  /// In en, this message translates to:
  /// **'Color Scheme'**
  String get colorScheme;

  /// No description provided for @soundAccompaniment.
  ///
  /// In en, this message translates to:
  /// **'Sound Accompaniment'**
  String get soundAccompaniment;

  /// No description provided for @soundMode.
  ///
  /// In en, this message translates to:
  /// **'Sound Mode'**
  String get soundMode;

  /// No description provided for @soundModeBeep.
  ///
  /// In en, this message translates to:
  /// **'Beep / Whistle only'**
  String get soundModeBeep;

  /// No description provided for @soundModeVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice coach (TTS)'**
  String get soundModeVoice;

  /// No description provided for @soundModeVoiceAndBeep.
  ///
  /// In en, this message translates to:
  /// **'Voice + Beeps'**
  String get soundModeVoiceAndBeep;

  /// No description provided for @soundModeMute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get soundModeMute;

  /// No description provided for @individualSignals.
  ///
  /// In en, this message translates to:
  /// **'Individual Event Signals'**
  String get individualSignals;

  /// No description provided for @individualSignalsSub.
  ///
  /// In en, this message translates to:
  /// **'Tap to configure sounds or pick a custom file'**
  String get individualSignalsSub;

  /// No description provided for @signalCountdown.
  ///
  /// In en, this message translates to:
  /// **'Countdown (3, 2, 1)'**
  String get signalCountdown;

  /// No description provided for @signalRoundStart.
  ///
  /// In en, this message translates to:
  /// **'Round Start (WORK)'**
  String get signalRoundStart;

  /// No description provided for @signalRoundRest.
  ///
  /// In en, this message translates to:
  /// **'Round End (REST)'**
  String get signalRoundRest;

  /// No description provided for @signalFinish.
  ///
  /// In en, this message translates to:
  /// **'Workout Finish'**
  String get signalFinish;

  /// No description provided for @pickCustomFile.
  ///
  /// In en, this message translates to:
  /// **'Pick sound from device...'**
  String get pickCustomFile;

  /// No description provided for @vibrationTitle.
  ///
  /// In en, this message translates to:
  /// **'Vibration (O-Haptics)'**
  String get vibrationTitle;

  /// No description provided for @vibrationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tactile feedback on phase transitions & countdown'**
  String get vibrationSubtitle;

  /// No description provided for @appLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'App Language'**
  String get appLanguageTitle;

  /// No description provided for @appLanguageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'UI & Coach language'**
  String get appLanguageSubtitle;

  /// No description provided for @appFontTitle.
  ///
  /// In en, this message translates to:
  /// **'App Font'**
  String get appFontTitle;

  /// No description provided for @appFontSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Application typography'**
  String get appFontSubtitle;

  /// No description provided for @selectFont.
  ///
  /// In en, this message translates to:
  /// **'Select Font'**
  String get selectFont;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @selectSound.
  ///
  /// In en, this message translates to:
  /// **'Select Sound'**
  String get selectSound;

  /// No description provided for @filePrefix.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get filePrefix;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @allTags.
  ///
  /// In en, this message translates to:
  /// **'All tags'**
  String get allTags;

  /// No description provided for @noWorkoutsTag.
  ///
  /// In en, this message translates to:
  /// **'No workouts with tag'**
  String get noWorkoutsTag;

  /// No description provided for @createWorkoutPrompt.
  ///
  /// In en, this message translates to:
  /// **'No workouts\nTap \"+ Create\" to add one'**
  String get createWorkoutPrompt;

  /// No description provided for @listView.
  ///
  /// In en, this message translates to:
  /// **'List View'**
  String get listView;

  /// No description provided for @cardView.
  ///
  /// In en, this message translates to:
  /// **'Card View'**
  String get cardView;

  /// No description provided for @switchToListView.
  ///
  /// In en, this message translates to:
  /// **'Switch to List View'**
  String get switchToListView;

  /// No description provided for @switchToCardView.
  ///
  /// In en, this message translates to:
  /// **'Switch to Card View'**
  String get switchToCardView;

  /// No description provided for @createButton.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get createButton;

  /// No description provided for @editWorkoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Workout'**
  String get editWorkoutTitle;

  /// No description provided for @newWorkoutTitle.
  ///
  /// In en, this message translates to:
  /// **'New Workout'**
  String get newWorkoutTitle;

  /// No description provided for @workoutName.
  ///
  /// In en, this message translates to:
  /// **'Workout Name'**
  String get workoutName;

  /// No description provided for @workoutType.
  ///
  /// In en, this message translates to:
  /// **'Workout Type'**
  String get workoutType;

  /// No description provided for @tabataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'High-intensity intervals: work / rest'**
  String get tabataSubtitle;

  /// No description provided for @emomSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Every minute on the minute'**
  String get emomSubtitle;

  /// No description provided for @amrapSubtitle.
  ///
  /// In en, this message translates to:
  /// **'As many rounds as possible in time cap'**
  String get amrapSubtitle;

  /// No description provided for @timingAndRounds.
  ///
  /// In en, this message translates to:
  /// **'Timing & Rounds'**
  String get timingAndRounds;

  /// No description provided for @roundDuration.
  ///
  /// In en, this message translates to:
  /// **'Round Duration'**
  String get roundDuration;

  /// No description provided for @secondsShort.
  ///
  /// In en, this message translates to:
  /// **'s'**
  String get secondsShort;

  /// No description provided for @minutesShort.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get minutesShort;

  /// No description provided for @roundsCount.
  ///
  /// In en, this message translates to:
  /// **'Rounds'**
  String get roundsCount;

  /// No description provided for @circuitsCount.
  ///
  /// In en, this message translates to:
  /// **'Circuits'**
  String get circuitsCount;

  /// No description provided for @exercisesInWorkout.
  ///
  /// In en, this message translates to:
  /// **'Workout Exercises'**
  String get exercisesInWorkout;

  /// No description provided for @addExerciseTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Exercise'**
  String get addExerciseTitle;

  /// No description provided for @repsOrSeconds.
  ///
  /// In en, this message translates to:
  /// **'Reps or seconds'**
  String get repsOrSeconds;

  /// No description provided for @exerciseDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Description / technique (optional)'**
  String get exerciseDescriptionHint;

  /// No description provided for @tagsSection.
  ///
  /// In en, this message translates to:
  /// **'Tags & Categories'**
  String get tagsSection;

  /// No description provided for @totalDurationEst.
  ///
  /// In en, this message translates to:
  /// **'Est. Duration'**
  String get totalDurationEst;

  /// No description provided for @saveWorkoutButton.
  ///
  /// In en, this message translates to:
  /// **'Save Workout'**
  String get saveWorkoutButton;

  /// No description provided for @tagUpperBody.
  ///
  /// In en, this message translates to:
  /// **'Upper'**
  String get tagUpperBody;

  /// No description provided for @tagLowerBody.
  ///
  /// In en, this message translates to:
  /// **'Lower'**
  String get tagLowerBody;

  /// No description provided for @tagFullBodyHiit.
  ///
  /// In en, this message translates to:
  /// **'HIIT'**
  String get tagFullBodyHiit;

  /// No description provided for @tagIsometric.
  ///
  /// In en, this message translates to:
  /// **'Isometric'**
  String get tagIsometric;

  /// No description provided for @tagFullBody.
  ///
  /// In en, this message translates to:
  /// **'Full Body'**
  String get tagFullBody;

  /// No description provided for @tagKettlebell.
  ///
  /// In en, this message translates to:
  /// **'Kettlebell'**
  String get tagKettlebell;

  /// No description provided for @tagCalisthenics.
  ///
  /// In en, this message translates to:
  /// **'Calisthenics'**
  String get tagCalisthenics;

  /// No description provided for @nextExercisePrefix.
  ///
  /// In en, this message translates to:
  /// **'NEXT'**
  String get nextExercisePrefix;

  /// No description provided for @totalRemainingLabel.
  ///
  /// In en, this message translates to:
  /// **'REMAINING'**
  String get totalRemainingLabel;

  /// No description provided for @roundLabel.
  ///
  /// In en, this message translates to:
  /// **'ROUND'**
  String get roundLabel;

  /// No description provided for @circuitLabel.
  ///
  /// In en, this message translates to:
  /// **'CIRCUIT'**
  String get circuitLabel;

  /// No description provided for @finishWorkoutEarly.
  ///
  /// In en, this message translates to:
  /// **'Finish Workout Early?'**
  String get finishWorkoutEarly;

  /// No description provided for @finishWorkoutEarlyDesc.
  ///
  /// In en, this message translates to:
  /// **'Your progress so far will be saved.'**
  String get finishWorkoutEarlyDesc;

  /// No description provided for @saveSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Workout Summary'**
  String get saveSessionTitle;

  /// No description provided for @congratulations.
  ///
  /// In en, this message translates to:
  /// **'Awesome job! Workout completed.'**
  String get congratulations;

  /// No description provided for @totalTimeSpent.
  ///
  /// In en, this message translates to:
  /// **'Total Time'**
  String get totalTimeSpent;

  /// No description provided for @sessionSaved.
  ///
  /// In en, this message translates to:
  /// **'Workout saved to history!'**
  String get sessionSaved;

  /// No description provided for @toHome.
  ///
  /// In en, this message translates to:
  /// **'To Main Screen'**
  String get toHome;

  /// No description provided for @addCommentHint.
  ///
  /// In en, this message translates to:
  /// **'Notes on how it went...'**
  String get addCommentHint;

  /// No description provided for @monthJan.
  ///
  /// In en, this message translates to:
  /// **'January'**
  String get monthJan;

  /// No description provided for @monthFeb.
  ///
  /// In en, this message translates to:
  /// **'February'**
  String get monthFeb;

  /// No description provided for @monthMar.
  ///
  /// In en, this message translates to:
  /// **'March'**
  String get monthMar;

  /// No description provided for @monthApr.
  ///
  /// In en, this message translates to:
  /// **'April'**
  String get monthApr;

  /// No description provided for @monthMay.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get monthMay;

  /// No description provided for @monthJun.
  ///
  /// In en, this message translates to:
  /// **'June'**
  String get monthJun;

  /// No description provided for @monthJul.
  ///
  /// In en, this message translates to:
  /// **'July'**
  String get monthJul;

  /// No description provided for @monthAug.
  ///
  /// In en, this message translates to:
  /// **'August'**
  String get monthAug;

  /// No description provided for @monthSep.
  ///
  /// In en, this message translates to:
  /// **'September'**
  String get monthSep;

  /// No description provided for @monthOct.
  ///
  /// In en, this message translates to:
  /// **'October'**
  String get monthOct;

  /// No description provided for @monthNov.
  ///
  /// In en, this message translates to:
  /// **'November'**
  String get monthNov;

  /// No description provided for @monthDec.
  ///
  /// In en, this message translates to:
  /// **'December'**
  String get monthDec;

  /// No description provided for @noWorkoutsOnDay.
  ///
  /// In en, this message translates to:
  /// **'No workouts on this day'**
  String get noWorkoutsOnDay;

  /// No description provided for @completedSessionsCount.
  ///
  /// In en, this message translates to:
  /// **'Workouts completed'**
  String get completedSessionsCount;

  /// No description provided for @selectDate.
  ///
  /// In en, this message translates to:
  /// **'Select Date'**
  String get selectDate;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @finishEarly.
  ///
  /// In en, this message translates to:
  /// **'Finish early'**
  String get finishEarly;

  /// No description provided for @prevRoundTooltip.
  ///
  /// In en, this message translates to:
  /// **'Previous round / reset'**
  String get prevRoundTooltip;

  /// No description provided for @nextRoundTooltip.
  ///
  /// In en, this message translates to:
  /// **'Next round'**
  String get nextRoundTooltip;

  /// No description provided for @soundOnTooltip.
  ///
  /// In en, this message translates to:
  /// **'Turn sound on'**
  String get soundOnTooltip;

  /// No description provided for @soundOffTooltip.
  ///
  /// In en, this message translates to:
  /// **'Turn sound off'**
  String get soundOffTooltip;

  /// No description provided for @pausedLabel.
  ///
  /// In en, this message translates to:
  /// **'PAUSED'**
  String get pausedLabel;

  /// No description provided for @readyLabel.
  ///
  /// In en, this message translates to:
  /// **'GET READY'**
  String get readyLabel;

  /// No description provided for @workLabel.
  ///
  /// In en, this message translates to:
  /// **'WORK'**
  String get workLabel;

  /// No description provided for @restLabel.
  ///
  /// In en, this message translates to:
  /// **'REST'**
  String get restLabel;

  /// No description provided for @workoutFinishedTitle.
  ///
  /// In en, this message translates to:
  /// **'WORKOUT COMPLETED!'**
  String get workoutFinishedTitle;

  /// No description provided for @timeLabel.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get timeLabel;

  /// No description provided for @saveAndExit.
  ///
  /// In en, this message translates to:
  /// **'Save and Exit'**
  String get saveAndExit;

  /// No description provided for @repsShort.
  ///
  /// In en, this message translates to:
  /// **'reps'**
  String get repsShort;

  /// No description provided for @repsUpper.
  ///
  /// In en, this message translates to:
  /// **'REPETITIONS'**
  String get repsUpper;

  /// No description provided for @secShort.
  ///
  /// In en, this message translates to:
  /// **'s'**
  String get secShort;

  /// No description provided for @secUpper.
  ///
  /// In en, this message translates to:
  /// **'SEC'**
  String get secUpper;

  /// No description provided for @minShort.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get minShort;

  /// No description provided for @allDates.
  ///
  /// In en, this message translates to:
  /// **'All dates'**
  String get allDates;

  /// No description provided for @workoutsForDate.
  ///
  /// In en, this message translates to:
  /// **'Workouts on'**
  String get workoutsForDate;

  /// No description provided for @allRecentWorkouts.
  ///
  /// In en, this message translates to:
  /// **'All recent workouts'**
  String get allRecentWorkouts;

  /// No description provided for @noWorkoutsHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your history will appear here\nonce you finish your first workout'**
  String get noWorkoutsHistoryEmpty;

  /// No description provided for @selectDateTip.
  ///
  /// In en, this message translates to:
  /// **'Select a date marked with 🔥 to see details'**
  String get selectDateTip;

  /// No description provided for @bulkAddButton.
  ///
  /// In en, this message translates to:
  /// **'Bulk add'**
  String get bulkAddButton;

  /// No description provided for @bulkAddDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Add as list'**
  String get bulkAddDialogTitle;

  /// No description provided for @bulkAddPrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter names (each on a new line or separated by commas):'**
  String get bulkAddPrompt;

  /// No description provided for @bulkAddHint.
  ///
  /// In en, this message translates to:
  /// **'Push-ups\nSquats\nPlank\nLunges\nPull-ups'**
  String get bulkAddHint;

  /// No description provided for @workTimeForEach.
  ///
  /// In en, this message translates to:
  /// **'Work time for each:'**
  String get workTimeForEach;

  /// No description provided for @repsOptional.
  ///
  /// In en, this message translates to:
  /// **'Reps (optional):'**
  String get repsOptional;

  /// No description provided for @repsHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 12 (or leave empty)'**
  String get repsHint;

  /// No description provided for @addAll.
  ///
  /// In en, this message translates to:
  /// **'Add all'**
  String get addAll;

  /// No description provided for @editExerciseTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Exercise'**
  String get editExerciseTitle;

  /// No description provided for @exerciseNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name:'**
  String get exerciseNameLabel;

  /// No description provided for @executionTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Duration:'**
  String get executionTimeLabel;

  /// No description provided for @repsCountLabel.
  ///
  /// In en, this message translates to:
  /// **'Repetitions:'**
  String get repsCountLabel;

  /// No description provided for @quickAdjustTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick adjustment for ALL exercises:'**
  String get quickAdjustTitle;

  /// No description provided for @setTimeForAll.
  ///
  /// In en, this message translates to:
  /// **'Set time for all'**
  String get setTimeForAll;

  /// No description provided for @setRepsForAll.
  ///
  /// In en, this message translates to:
  /// **'Set reps for all'**
  String get setRepsForAll;

  /// No description provided for @setTimeForAllDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Set time for ALL'**
  String get setTimeForAllDialogTitle;

  /// No description provided for @setTimeForAllPrompt.
  ///
  /// In en, this message translates to:
  /// **'Choose new duration for all exercises in workout:'**
  String get setTimeForAllPrompt;

  /// No description provided for @setRepsForAllDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Set reps for ALL'**
  String get setRepsForAllDialogTitle;

  /// No description provided for @setRepsForAllPrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter repetitions count for each exercise:'**
  String get setRepsForAllPrompt;

  /// No description provided for @applyToAll.
  ///
  /// In en, this message translates to:
  /// **'Apply to all'**
  String get applyToAll;

  /// No description provided for @bulkAddExerciseHelp.
  ///
  /// In en, this message translates to:
  /// **'Add exercises one by one or tap «Bulk add» to enable Circuits mode with individual time and reps configuration.'**
  String get bulkAddExerciseHelp;

  /// No description provided for @circuitsCountLabel.
  ///
  /// In en, this message translates to:
  /// **'Number of circuits'**
  String get circuitsCountLabel;

  /// No description provided for @circuitsSummary.
  ///
  /// In en, this message translates to:
  /// **'circuits • Total in workout:'**
  String get circuitsSummary;

  /// No description provided for @baseWorkTime.
  ///
  /// In en, this message translates to:
  /// **'Base work time (sec)'**
  String get baseWorkTime;

  /// No description provided for @baseRestTime.
  ///
  /// In en, this message translates to:
  /// **'Rest time (sec)'**
  String get baseRestTime;

  /// No description provided for @baseRoundDuration.
  ///
  /// In en, this message translates to:
  /// **'Base round duration (sec)'**
  String get baseRoundDuration;

  /// No description provided for @roundDurationSec.
  ///
  /// In en, this message translates to:
  /// **'Round duration (sec)'**
  String get roundDurationSec;

  /// No description provided for @tagRequiredAlert.
  ///
  /// In en, this message translates to:
  /// **'Please select a tag: Upper, Lower, HIIT, Isometric or Full Body'**
  String get tagRequiredAlert;

  /// No description provided for @tagRequiredSub.
  ///
  /// In en, this message translates to:
  /// **'(required: select a tag)'**
  String get tagRequiredSub;

  /// No description provided for @addedSecAll.
  ///
  /// In en, this message translates to:
  /// **'Added +{sec}s to all exercises!'**
  String addedSecAll(Object sec);

  /// No description provided for @reducedSecAll.
  ///
  /// In en, this message translates to:
  /// **'Reduced by {sec}s in all exercises!'**
  String reducedSecAll(Object sec);

  /// No description provided for @exercisesLabel.
  ///
  /// In en, this message translates to:
  /// **'Exercises:'**
  String get exercisesLabel;

  /// No description provided for @roundsOf.
  ///
  /// In en, this message translates to:
  /// **'rounds of'**
  String get roundsOf;

  /// No description provided for @workShort.
  ///
  /// In en, this message translates to:
  /// **'work:'**
  String get workShort;

  /// No description provided for @restShort.
  ///
  /// In en, this message translates to:
  /// **'rest:'**
  String get restShort;

  /// No description provided for @completedComplex.
  ///
  /// In en, this message translates to:
  /// **'Completed complex:'**
  String get completedComplex;

  /// No description provided for @weekdayMon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get weekdayMon;

  /// No description provided for @weekdayTue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get weekdayTue;

  /// No description provided for @weekdayWed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get weekdayWed;

  /// No description provided for @weekdayThu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get weekdayThu;

  /// No description provided for @weekdayFri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get weekdayFri;

  /// No description provided for @weekdaySat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get weekdaySat;

  /// No description provided for @weekdaySun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get weekdaySun;

  /// No description provided for @timeCap.
  ///
  /// In en, this message translates to:
  /// **'Time Cap'**
  String get timeCap;

  /// No description provided for @countMode.
  ///
  /// In en, this message translates to:
  /// **'Count Mode'**
  String get countMode;

  /// No description provided for @byRounds.
  ///
  /// In en, this message translates to:
  /// **'By Rounds'**
  String get byRounds;

  /// No description provided for @byExercises.
  ///
  /// In en, this message translates to:
  /// **'By Exercises'**
  String get byExercises;

  /// No description provided for @duplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get duplicate;

  /// No description provided for @copySuffix.
  ///
  /// In en, this message translates to:
  /// **'(copy)'**
  String get copySuffix;

  /// No description provided for @addRound.
  ///
  /// In en, this message translates to:
  /// **'+1 Round'**
  String get addRound;

  /// No description provided for @nextExercise.
  ///
  /// In en, this message translates to:
  /// **'Next Exercise'**
  String get nextExercise;

  /// No description provided for @score.
  ///
  /// In en, this message translates to:
  /// **'Score'**
  String get score;

  /// No description provided for @workoutDuplicated.
  ///
  /// In en, this message translates to:
  /// **'Workout duplicated successfully'**
  String get workoutDuplicated;
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
      <String>['de', 'en', 'hr', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'hr':
      return AppLocalizationsHr();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
