import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import '../data/models/workout.dart';
import '../data/models/workout_session.dart';

class WidgetSyncService {
  static const String streakWidgetProvider = 'StreakWidgetProvider';
  static const String quickLauncherWidgetProvider = 'QuickLauncherWidgetProvider';

  /// Sync both Streak & Quick Launcher widget states
  static Future<void> syncAll({
    required List<WorkoutSession> sessions,
    required List<Workout> workouts,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return;

    try {
      await _syncStreakData(sessions);
      await _syncQuickLauncherData(workouts);

      // Trigger update on Android Home Screen
      await HomeWidget.updateWidget(
        name: streakWidgetProvider,
        androidName: streakWidgetProvider,
      );
      await HomeWidget.updateWidget(
        name: quickLauncherWidgetProvider,
        androidName: quickLauncherWidgetProvider,
      );
    } catch (e) {
      debugPrint('[WidgetSyncService] Failed to sync widgets: $e');
    }
  }

  /// Calculates and saves streak data & current week day marks
  static Future<void> _syncStreakData(List<WorkoutSession> sessions) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Calculate unique training days sorted descending
    final trainingDays = sessions
        .map((s) => DateTime(s.startedAt.year, s.startedAt.month, s.startedAt.day))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    int streak = 0;
    if (trainingDays.isNotEmpty) {
      // If trained today or yesterday, streak is currently active
      final hasToday = trainingDays.contains(today);
      final yesterday = today.subtract(const Duration(days: 1));
      final hasYesterday = trainingDays.contains(yesterday);

      if (hasToday || hasYesterday) {
        var checkDay = hasToday ? today : yesterday;
        while (trainingDays.contains(checkDay)) {
          streak++;
          checkDay = checkDay.subtract(const Duration(days: 1));
        }
      }
    }

    // Current week progress (Mon=1, Tue=2, ..., Sun=7)
    final currentWeekday = now.weekday; // 1 (Mon) to 7 (Sun)
    final monday = today.subtract(Duration(days: currentWeekday - 1));
    final sunday = monday.add(const Duration(days: 6));

    final weekSessions = sessions.where((s) {
      final sDate = DateTime(s.startedAt.year, s.startedAt.month, s.startedAt.day);
      return !sDate.isBefore(monday) && !sDate.isAfter(sunday);
    }).toList();

    final activeDaysNumbers = weekSessions
        .map((s) => s.startedAt.weekday.toString())
        .toSet()
        .join(',');

    final totalMinutesThisWeek = weekSessions.fold<int>(
      0,
      (sum, s) => sum + (s.finishedAt?.difference(s.startedAt).inMinutes ?? 0),
    );

    final String statusText;
    final hasToday = trainingDays.contains(today);
    if (hasToday) {
      statusText = 'Отличная работа! Сегодня выполнено 🔥';
    } else if (streak > 0) {
      statusText = 'Продолжи серию: $streak ${streak == 1 ? "день" : "дня"} подряд!';
    } else {
      statusText = 'Время для новой тренировки!';
    }

    final String statsText = '${weekSessions.length} ${_pluralWorkouts(weekSessions.length)} • $totalMinutesThisWeek мин';

    await HomeWidget.saveWidgetData<int>('streak_count', streak);
    await HomeWidget.saveWidgetData<String>('streak_status', statusText);
    await HomeWidget.saveWidgetData<String>('streak_stats', statsText);
    await HomeWidget.saveWidgetData<String>('week_active_days', activeDaysNumbers);
  }

  /// Saves top 2 workouts for the quick launcher slots
  static Future<void> _syncQuickLauncherData(List<Workout> workouts) async {
    if (workouts.isNotEmpty) {
      final w1 = workouts.first;
      await HomeWidget.saveWidgetData<int>('workout_1_id', w1.key as int? ?? 0);
      await HomeWidget.saveWidgetData<String>('workout_1_name', w1.name.toUpperCase());
      await HomeWidget.saveWidgetData<String>('workout_1_info', '▶ ${w1.type.name.toUpperCase()}');
    }

    if (workouts.length > 1) {
      final w2 = workouts[1];
      await HomeWidget.saveWidgetData<int>('workout_2_id', w2.key as int? ?? 1);
      await HomeWidget.saveWidgetData<String>('workout_2_name', w2.name.toUpperCase());
      await HomeWidget.saveWidgetData<String>('workout_2_info', '▶ ${w2.type.name.toUpperCase()}');
    }
  }

  static String _pluralWorkouts(int count) {
    if (count % 10 == 1 && count % 100 != 11) {
      return 'тренировка';
    } else if (count % 10 >= 2 && count % 10 <= 4 && (count % 100 < 10 || count % 100 >= 20)) {
      return 'тренировки';
    } else {
      return 'тренировок';
    }
  }
}
