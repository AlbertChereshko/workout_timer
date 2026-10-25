import os

files = {
    "l10n.yaml": """arb-dir: lib/l10n
template-arb-file: app_ru.arb
output-localization-file: app_localizations.dart
""",
    "lib/l10n/app_ru.arb": """{
  "@@locale": "ru",
  "appTitle": "Workout Timer",
  "workouts": "Тренировки",
  "newWorkout": "Новая тренировка",
  "emom": "EMOM",
  "tabata": "TABATA",
  "work": "РАБОТА",
  "rest": "ОТДЫХ",
  "round": "Раунд",
  "of": "из",
  "pause": "Пауза",
  "resume": "Продолжить",
  "stop": "Стоп",
  "history": "История",
  "settings": "Настройки",
  "sounds": "Звуки",
  "language": "Язык",
  "russian": "Русский",
  "english": "English",
  "rounds": "Раундов",
  "workTime": "Время работы",
  "restTime": "Время отдыха",
  "cycles": "Циклов",
  "exercises": "Упражнения",
  "addExercise": "Добавить упражнение",
  "exerciseName": "Название упражнения",
  "reps": "Повторения",
  "save": "Сохранить",
  "delete": "Удалить",
  "edit": "Редактировать",
  "start": "Старт",
  "ready": "ГОТОВЬСЯ!",
  "go": "ВПЕРЁД!",
  "finished": "ГОТОВО!",
  "workoutCompleted": "Тренировка завершена",
  "completedRounds": "Завершено раундов",
  "duration": "Длительность",
  "noWorkouts": "Нет тренировок. Создай первую!",
  "noHistory": "История пуста. Начни тренироваться!",
  "confirmStop": "Прервать тренировку?",
  "confirmDelete": "Удалить тренировку?",
  "cancel": "Отмена",
  "confirm": "Подтвердить",
  "soundBeep": "Бип",
  "soundWhistle": "Свисток",
  "soundGong": "Гонг",
  "soundBell": "Колокол",
  "soundClick": "Клик",
  "startSound": "Звук старта",
  "endSound": "Звук конца раунда",
  "restSound": "Звук отдыха",
  "finishSound": "Звук финиша",
  "countdownSound": "Звук обратного отсчёта",
  "preview": "Прослушать"
}""",
    "lib/l10n/app_en.arb": """{
  "@@locale": "en",
  "appTitle": "Workout Timer",
  "workouts": "Workouts",
  "newWorkout": "New Workout",
  "emom": "EMOM",
  "tabata": "TABATA",
  "work": "WORK",
  "rest": "REST",
  "round": "Round",
  "of": "of",
  "pause": "Pause",
  "resume": "Resume",
  "stop": "Stop",
  "history": "History",
  "settings": "Settings",
  "sounds": "Sounds",
  "language": "Language",
  "russian": "Русский",
  "english": "English",
  "rounds": "Rounds",
  "workTime": "Work Time",
  "restTime": "Rest Time",
  "cycles": "Cycles",
  "exercises": "Exercises",
  "addExercise": "Add Exercise",
  "exerciseName": "Exercise Name",
  "reps": "Reps",
  "save": "Save",
  "delete": "Delete",
  "edit": "Edit",
  "start": "Start",
  "ready": "GET READY!",
  "go": "GO!",
  "finished": "FINISHED!",
  "workoutCompleted": "Workout Completed",
  "completedRounds": "Completed Rounds",
  "duration": "Duration",
  "noWorkouts": "No workouts. Create your first!",
  "noHistory": "History is empty. Start working out!",
  "confirmStop": "Stop the workout?",
  "confirmDelete": "Delete workout?",
  "cancel": "Cancel",
  "confirm": "Confirm",
  "soundBeep": "Beep",
  "soundWhistle": "Whistle",
  "soundGong": "Gong",
  "soundBell": "Bell",
  "soundClick": "Click",
  "startSound": "Start Sound",
  "endSound": "End Round Sound",
  "restSound": "Rest Sound",
  "finishSound": "Finish Sound",
  "countdownSound": "Countdown Sound",
  "preview": "Preview"
}""",
    "lib/core/theme.dart": """import 'package:flutter/material.dart';

class AppTheme {
  static const Color background = Color(0xFF0D0D0D);
  static const Color surface = Color(0xFF1A1A1A);
  static const Color accent = Color(0xFFFF6B00);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9E9E9E);
  
  static const Color workPhase = Color(0xFFFF4500);
  static const Color restPhase = Color(0xFF00C853);
  static const Color countdownPhase = Color(0xFF9E9E9E);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: accent,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        surface: surface,
        background: background,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardTheme(
        color: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
      ),
      useMaterial3: true,
    );
  }
}
""",
    "lib/main.dart": """import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  
  // Register adapters here later
  
  runApp(const ProviderScope(child: WorkoutTimerApp()));
}
""",
    "lib/app.dart": """import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
// import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'core/theme.dart';

class WorkoutTimerApp extends StatelessWidget {
  const WorkoutTimerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Workout Timer',
      theme: AppTheme.darkTheme,
      // localizationsDelegates: AppLocalizations.localizationsDelegates,
      // supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(
        body: Center(
          child: Text('EMOM + Tabata Timer', style: TextStyle(color: Colors.white)),
        ),
      ),
    );
  }
}
"""
}

for path, content in files.items():
    os.makedirs(os.path.dirname(path) if os.path.dirname(path) else '.', exist_ok=True)
    with open(path, 'w') as f:
        f.write(content)

print("Scaffold created!")
