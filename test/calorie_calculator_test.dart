import 'package:flutter_test/flutter_test.dart';
import 'package:workout_timer/data/models/athlete_profile.dart';
import 'package:workout_timer/data/models/workout.dart';
import 'package:workout_timer/services/calorie_calculator.dart';

void main() {
  group('CalorieCalculator Tests', () {
    test('calculates correct calories for Tabata workout with default profile', () {
      const profile = AthleteProfile(
        weightKg: 75.0,
        heightCm: 178.0,
        age: 30,
        gender: 'male',
        fitnessLevel: FitnessLevel.intermediate,
      );

      final workout = Workout()
        ..name = 'Табата Интенсив'
        ..type = WorkoutType.tabata
        ..tabataRounds = 8
        ..tabataWorkSeconds = 20
        ..tabataRestSeconds = 10
        ..tags = ['ВИТ'];

      // durationSeconds = 240 (4 mins)
      final calories = CalorieCalculator.calculateCaloriesBurned(
        type: workout.type,
        tags: workout.tags,
        durationSeconds: 240,
        weightKg: profile.weightKg,
        fitnessLevel: profile.fitnessLevel,
      );

      // MET = 10.5 (Tabata) + 1.0 (ВИТ) = 11.5
      // Cal = 11.5 * 3.5 * 75 / 200 * 4 * 1.0 ≈ 60.375 -> 60 kcal
      expect(calories, greaterThanOrEqualTo(50));
      expect(calories, lessThanOrEqualTo(75));
    });

    test('statika workout has lower MET than high-intensity workout', () {
      const profile = AthleteProfile(weightKg: 80.0);

      final statikaWorkout = Workout()
        ..name = 'Планка'
        ..type = WorkoutType.emom
        ..tags = ['Статика'];

      final hiitWorkout = Workout()
        ..name = 'HIIT Бёрпи'
        ..type = WorkoutType.tabata
        ..tags = ['ВИТ'];

      final statikaCal = CalorieCalculator.calculateCaloriesBurned(
        type: statikaWorkout.type,
        tags: statikaWorkout.tags,
        durationSeconds: 600, // 10 mins
        weightKg: profile.weightKg,
      );

      final hiitCal = CalorieCalculator.calculateCaloriesBurned(
        type: hiitWorkout.type,
        tags: hiitWorkout.tags,
        durationSeconds: 600, // 10 mins
        weightKg: profile.weightKg,
      );

      expect(statikaCal, lessThan(hiitCal));
      expect(statikaCal, greaterThan(0));
    });

    test('beginner expends slightly more calories than advanced due to efficiency factor', () {
      final begCal = CalorieCalculator.calculateCaloriesBurned(
        type: WorkoutType.emom,
        tags: [],
        durationSeconds: 900,
        weightKg: 70.0,
        fitnessLevel: FitnessLevel.beginner,
      );

      final advCal = CalorieCalculator.calculateCaloriesBurned(
        type: WorkoutType.emom,
        tags: [],
        durationSeconds: 900,
        weightKg: 70.0,
        fitnessLevel: FitnessLevel.advanced,
      );

      expect(begCal, greaterThan(advCal));
    });
  });
}
