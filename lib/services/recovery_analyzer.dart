import '../data/models/workout.dart';
import '../data/models/workout_session.dart';

enum MuscleGroup {
  upperBody, // Верх (грудь, спина, руки, плечи)
  lowerBody, // Низ (ноги, ягодицы)
  coreStatic, // Статика / Кор (пресс, стабилизаторы)
  metabolicFullBody, // ВИТ / Full Body (кардио, всё тело)
}

enum MuscleSubgroup {
  // Upper Body
  chest('Грудь', MuscleGroup.upperBody),
  back('Спина', MuscleGroup.upperBody),
  shoulders('Плечи', MuscleGroup.upperBody),
  arms('Руки', MuscleGroup.upperBody),
  traps('Трапеции', MuscleGroup.upperBody),

  // Lower Body
  quads('Квадрицепсы', MuscleGroup.lowerBody),
  hamstrings('Бицепсы бедра', MuscleGroup.lowerBody),
  calves('Икроножные мышцы', MuscleGroup.lowerBody),
  glutes('Ягодицы', MuscleGroup.lowerBody),

  // Core
  abs('Пресс', MuscleGroup.coreStatic),
  obliques('Косые мышцы', MuscleGroup.coreStatic),
  lowerBack('Поясница', MuscleGroup.coreStatic),

  // Full Body
  fullBody('Всё тело (ВИТ)', MuscleGroup.metabolicFullBody);

  final String displayName;
  final MuscleGroup parentGroup;
  const MuscleSubgroup(this.displayName, this.parentGroup);

  static List<MuscleSubgroup> forParent(MuscleGroup parent) =>
      values.where((s) => s.parentGroup == parent).toList();
}

extension MuscleGroupExtension on MuscleGroup {
  String get displayName {
    switch (this) {
      case MuscleGroup.upperBody:
        return 'Верх тела';
      case MuscleGroup.lowerBody:
        return 'Низ тела';
      case MuscleGroup.coreStatic:
        return 'Кор';
      case MuscleGroup.metabolicFullBody:
        return 'ВИТ / Full Body';
    }
  }

  String get shortTag {
    switch (this) {
      case MuscleGroup.upperBody:
        return 'Верх';
      case MuscleGroup.lowerBody:
        return 'Низ';
      case MuscleGroup.coreStatic:
        return 'Кор';
      case MuscleGroup.metabolicFullBody:
        return 'ВИТ';
    }
  }

  /// Base hours required for full muscle supercompensation/recovery
  double get fullRecoveryHours {
    switch (this) {
      case MuscleGroup.upperBody:
        return 48.0;
      case MuscleGroup.lowerBody:
        return 60.0;
      case MuscleGroup.coreStatic:
        return 28.0;
      case MuscleGroup.metabolicFullBody:
        return 40.0;
    }
  }
}

class MuscleRecoveryStatus {
  final MuscleGroup group;
  final double recoveryPercent; // 0.0 to 1.0 (1.0 = 100% recovered)
  final Duration timeSinceLastTrained;
  final bool hasTrainedRecently;

  const MuscleRecoveryStatus({
    required this.group,
    required this.recoveryPercent,
    required this.timeSinceLastTrained,
    required this.hasTrainedRecently,
  });

  bool get isReady => recoveryPercent >= 0.85;
  bool get isRecovering => recoveryPercent >= 0.50 && recoveryPercent < 0.85;
  bool get isFatigued => recoveryPercent < 0.50;

  String get statusText {
    if (isReady) return 'Готовы к тренировке';
    if (isRecovering) return 'Восстанавливаются';
    return 'Утомлены, нужен отдых';
  }
}

class RecoveryReport {
  final List<MuscleRecoveryStatus> statuses;
  final MuscleGroup recommendedGroup;
  final Workout? recommendedWorkout;
  final String recommendationReason;

  const RecoveryReport({
    required this.statuses,
    required this.recommendedGroup,
    this.recommendedWorkout,
    required this.recommendationReason,
  });
}

class RecoveryAnalyzer {
  /// Analyzes recent workout sessions and calculates recovery states
  static RecoveryReport analyze({
    required List<WorkoutSession> recentSessions,
    required List<Workout> availableWorkouts,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    const lookbackWindow = Duration(hours: 72);

    final sessionsInWindow = recentSessions.where((s) {
      final sessionTime = s.finishedAt ?? s.startedAt;
      return currentTime.difference(sessionTime) <= lookbackWindow;
    }).toList();

    // Map each muscle group to its recovery status
    final List<MuscleRecoveryStatus> statuses = [];

    for (final group in MuscleGroup.values) {
      DateTime? lastTrainedTime;

      for (final session in sessionsInWindow) {
        final sessionTime = session.finishedAt ?? session.startedAt;
        
        // Collect tags from session, with fallback to workout in availableWorkouts
        final matchedWorkout = availableWorkouts.where((w) {
          final workoutKey = (w.key is int) ? (w.key as int) : null;
          return workoutKey == session.workoutId ||
              w.name.trim().toLowerCase() == session.workoutName.trim().toLowerCase();
        }).firstOrNull;

        final Set<String> effectiveTags = Set<String>.from(session.tags);
        if (matchedWorkout != null) {
          effectiveTags.addAll(matchedWorkout.tags);
        }

        // Also check exercise names / snapshots for static exercises (e.g. планка, стульчик)
        final List<String> exerciseNames = [];
        if (session.exerciseSnapshots.isNotEmpty) {
          exerciseNames.addAll(session.exerciseSnapshots.map((e) => e.toLowerCase()));
        } else if (matchedWorkout != null) {
          exerciseNames.addAll(matchedWorkout.exercises.map((e) => e.name.toLowerCase()));
        }
        final workoutNameLower = session.workoutName.toLowerCase();

        final hasStaticKeywords = exerciseNames.any((e) =>
                e.contains('планк') ||
                e.contains('статик') ||
                e.contains('стульчик') ||
                e.contains('вис') ||
                e.contains('уголок') ||
                e.contains('лодочк')) ||
            workoutNameLower.contains('статик') ||
            workoutNameLower.contains('планк');

        final hasUpperKeywords = exerciseNames.any((e) =>
            e.contains('отжиман') ||
            e.contains('подтягиван') ||
            e.contains('брусь') ||
            e.contains('жим') ||
            e.contains('бицепс') ||
            e.contains('плеч'));

        final hasLowerKeywords = exerciseNames.any((e) =>
            e.contains('присед') ||
            e.contains('выпад') ||
            e.contains('прыж') ||
            e.contains('икр') ||
            e.contains('ягодиц'));

        bool affectsGroup = false;
        switch (group) {
          case MuscleGroup.upperBody:
            affectsGroup = effectiveTags.contains('Верх') ||
                effectiveTags.contains('Верх тела') ||
                effectiveTags.contains('Full Body') ||
                hasUpperKeywords;
            break;
          case MuscleGroup.lowerBody:
            affectsGroup = effectiveTags.contains('Низ') ||
                effectiveTags.contains('Низ тела') ||
                effectiveTags.contains('Full Body') ||
                hasLowerKeywords;
            break;
          case MuscleGroup.coreStatic:
            affectsGroup = effectiveTags.contains('Статика') || hasStaticKeywords;
            break;
          case MuscleGroup.metabolicFullBody:
            affectsGroup = effectiveTags.contains('ВИТ') ||
                effectiveTags.contains('ВИТ на всё тело') ||
                effectiveTags.contains('Full Body');
            break;
        }

        if (affectsGroup) {
          if (lastTrainedTime == null || sessionTime.isAfter(lastTrainedTime)) {
            lastTrainedTime = sessionTime;
          }
        }
      }

      if (lastTrainedTime == null) {
        statuses.add(MuscleRecoveryStatus(
          group: group,
          recoveryPercent: 1.0,
          timeSinceLastTrained: const Duration(days: 30),
          hasTrainedRecently: false,
        ));
      } else {
        final elapsedHours = currentTime.difference(lastTrainedTime).inMinutes / 60.0;
        final recoveryRatio = (elapsedHours / group.fullRecoveryHours).clamp(0.0, 1.0);

        statuses.add(MuscleRecoveryStatus(
          group: group,
          recoveryPercent: recoveryRatio,
          timeSinceLastTrained: currentTime.difference(lastTrainedTime),
          hasTrainedRecently: true,
        ));
      }
    }

    // Sort to find the most recovered group
    final sorted = List<MuscleRecoveryStatus>.from(statuses)
      ..sort((a, b) => b.recoveryPercent.compareTo(a.recoveryPercent));

    final recommendedGroup = sorted.first.group;

    // Find the best workout in user's library matching this group
    Workout? bestWorkout;
    final matchingWorkouts = availableWorkouts.where((w) {
      switch (recommendedGroup) {
        case MuscleGroup.upperBody:
          return w.tags.contains('Верх') || w.tags.contains('Верх тела');
        case MuscleGroup.lowerBody:
          return w.tags.contains('Низ') || w.tags.contains('Низ тела');
        case MuscleGroup.coreStatic:
          return w.tags.contains('Статика') || w.tags.contains('Кор');
        case MuscleGroup.metabolicFullBody:
          return w.tags.contains('ВИТ') || w.tags.contains('Full Body');
      }
    }).toList();

    if (matchingWorkouts.isNotEmpty) {
      bestWorkout = matchingWorkouts.first;
    } else if (availableWorkouts.isNotEmpty) {
      // Fallback: pick any workout that doesn't target the most fatigued group
      final mostFatigued = sorted.last;
      bestWorkout = availableWorkouts.firstWhere(
        (w) => !w.tags.contains(mostFatigued.group.shortTag),
        orElse: () => availableWorkouts.first,
      );
    }

    // Generate human-friendly reasoning
    String reason;
    final mostFatigued = sorted.last;
    if (mostFatigued.hasTrainedRecently && mostFatigued.recoveryPercent < 0.70) {
      final hoursAgo = mostFatigued.timeSinceLastTrained.inHours;
      final timeStr = hoursAgo < 24 ? '$hoursAgo ч назад' : '${(hoursAgo / 24).round()} дн назад';
      reason = '${mostFatigued.group.displayName} еще восстанавливается (тренировка была $timeStr). '
          'Сегодня идеально нагрузить ${recommendedGroup.displayName}!';
    } else {
      reason = 'Все мышечные группы хорошо отдохнули. Рекомендуем начать с ${recommendedGroup.displayName}.';
    }

    return RecoveryReport(
      statuses: statuses,
      recommendedGroup: recommendedGroup,
      recommendedWorkout: bestWorkout,
      recommendationReason: reason,
    );
  }
}
