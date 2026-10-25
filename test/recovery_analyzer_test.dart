import 'package:flutter_test/flutter_test.dart';
import 'package:workout_timer/data/models/workout.dart';
import 'package:workout_timer/data/models/workout_session.dart';
import 'package:workout_timer/services/recovery_analyzer.dart';

void main() {
  group('RecoveryAnalyzer Tests', () {
    test('returns full recovery and balance when no past sessions exist', () {
      final now = DateTime(2026, 10, 17, 12, 0);
      final workoutUpper = Workout()
        ..name = 'Верх тела'
        ..tags = ['Верх'];

      final report = RecoveryAnalyzer.analyze(
        recentSessions: [],
        availableWorkouts: [workoutUpper],
        now: now,
      );

      for (final s in report.statuses) {
        expect(s.recoveryPercent, 1.0);
        expect(s.isReady, isTrue);
      }
      expect(report.recommendedWorkout?.name, 'Верх тела');
    });

    test('fatigues upper body after recent upper body workout', () {
      final now = DateTime(2026, 10, 17, 12, 0);
      final sessionTime = now.subtract(const Duration(hours: 4)); // 4h ago

      final session = WorkoutSession()
        ..workoutId = 1
        ..workoutName = 'Отжимания и Брусья'
        ..workoutType = WorkoutType.tabata
        ..tags = ['Верх']
        ..startedAt = sessionTime.subtract(const Duration(minutes: 20))
        ..finishedAt = sessionTime;

      final workoutUpper = Workout()
        ..name = 'Верх'
        ..tags = ['Верх'];
      final workoutLower = Workout()
        ..name = 'Низ'
        ..tags = ['Низ'];

      final report = RecoveryAnalyzer.analyze(
        recentSessions: [session],
        availableWorkouts: [workoutUpper, workoutLower],
        now: now,
      );

      final upperStatus = report.statuses.firstWhere((s) => s.group == MuscleGroup.upperBody);
      final lowerStatus = report.statuses.firstWhere((s) => s.group == MuscleGroup.lowerBody);

      // Upper body recovery duration is 48h. Elapsed: 4h.
      // Expected recovery: 4 / 48 ≈ 0.08
      expect(upperStatus.recoveryPercent, lessThan(0.2));
      expect(lowerStatus.recoveryPercent, 1.0);
      expect(upperStatus.isFatigued, isTrue);
      expect(lowerStatus.isReady, isTrue);

      // System should recommend Lower body over Upper body!
      expect(report.recommendedGroup, MuscleGroup.lowerBody);
      expect(report.recommendedWorkout?.name, 'Низ');
    });

    test('muscle recovers progressively over time', () {
      final now = DateTime(2026, 10, 17, 12, 0);
      
      // Core recovery duration is 28h.
      // 14h ago -> recovery should be roughly 0.5
      final sessionCore = WorkoutSession()
        ..workoutId = 2
        ..workoutName = 'Пресс и Статика'
        ..workoutType = WorkoutType.emom
        ..tags = ['Статика']
        ..startedAt = now.subtract(const Duration(hours: 14, minutes: 10))
        ..finishedAt = now.subtract(const Duration(hours: 14));

      final report = RecoveryAnalyzer.analyze(
        recentSessions: [sessionCore],
        availableWorkouts: [],
        now: now,
      );

      final coreStatus = report.statuses.firstWhere((s) => s.group == MuscleGroup.coreStatic);
      expect(coreStatus.recoveryPercent, closeTo(0.5, 0.05));
    });
  });
}
