import 'package:flutter_test/flutter_test.dart';
import 'package:workout_timer/data/models/athlete_profile.dart';
import 'package:workout_timer/data/models/exercise_library.dart';
import 'package:workout_timer/data/models/workout.dart';
import 'package:workout_timer/services/gemini_coach_service.dart';
import 'package:workout_timer/services/recovery_analyzer.dart';

void main() {
  group('AI Workout Generator offline fallback tests', () {
    final coach = GeminiCoachService(null); // No API key -> tests local deterministic generator
    const profile = AthleteProfile();
    final report = RecoveryAnalyzer.analyze(recentSessions: [], availableWorkouts: []);

    test('generates Tabata workout with correct work/rest and static handling', () async {
      final workout = await coach.generateWorkout(
        targetType: WorkoutType.tabata,
        targetDurationMinutes: 8,
        targetMuscleGroup: MuscleGroup.coreStatic,
        equipment: ExerciseEquipment.bodyweight,
        recoveryReport: report,
        profile: profile,
      );

      expect(workout.type, WorkoutType.tabata);
      expect(workout.tabataWorkSeconds, 20);
      expect(workout.tabataRestSeconds, 10);
      expect(workout.exercises.isNotEmpty, true);
      expect(workout.tags.contains('Статика') || workout.tags.contains('Кор'), true);

      // Check that static exercises have null reps and durationSeconds set
      final staticEx = workout.exercises.where((e) => e.name.contains('Планка') || e.name.contains('Стульчик')).toList();
      for (final e in staticEx) {
        expect(e.reps, isNull);
        expect(e.durationSeconds, isNotNull);
      }
    });

    test('generates EMOM workout with correct rounds and duration', () async {
      final workout = await coach.generateWorkout(
        targetType: WorkoutType.emom,
        targetDurationMinutes: 15,
        targetMuscleGroup: MuscleGroup.upperBody,
        equipment: ExerciseEquipment.bodyweight,
        recoveryReport: report,
        profile: profile,
      );

      expect(workout.type, WorkoutType.emom);
      expect(workout.emomRounds, 15);
      expect(workout.emomRoundDurationSeconds, 60);
      expect(workout.exercises.isNotEmpty, true);
    });

    test('generates AMRAP workout with correct duration', () async {
      final workout = await coach.generateWorkout(
        targetType: WorkoutType.amrap,
        targetDurationMinutes: 20,
        targetMuscleGroup: MuscleGroup.metabolicFullBody,
        equipment: ExerciseEquipment.kettlebell,
        recoveryReport: report,
        profile: profile,
      );

      expect(workout.type, WorkoutType.amrap);
      expect(workout.amrapDurationSeconds, 1200);
      expect(workout.exercises.isNotEmpty, true);
    });
  });
}
