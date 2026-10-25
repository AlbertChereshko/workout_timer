import '../data/models/athlete_profile.dart';
import '../data/models/workout.dart';

class CalorieCalculator {
  /// Computes the Metabolic Equivalent of Task (MET) value
  /// for a given workout type and its tags.
  static double getMetValue(WorkoutType type, List<String> tags) {
    if (tags.contains('Статика')) {
      return 4.5;
    }

    double met;
    switch (type) {
      case WorkoutType.tabata:
        met = 10.5;
        break;
      case WorkoutType.amrap:
        met = 9.5;
        break;
      case WorkoutType.emom:
        met = 8.0;
        break;
    }

    if (tags.contains('ВИТ') || tags.contains('Full Body')) {
      met += 1.0;
    }

    return met;
  }

  /// Calculates burned calories using standard MET formula:
  /// Calories = MET * 3.5 * weightKg / 200 * durationMinutes
  static int calculateCaloriesBurned({
    required WorkoutType type,
    required List<String> tags,
    required int durationSeconds,
    required double weightKg,
    FitnessLevel fitnessLevel = FitnessLevel.intermediate,
  }) {
    if (durationSeconds <= 0 || weightKg <= 0) return 0;

    double met = getMetValue(type, tags);

    // Minor adjustment based on fitness efficiency
    switch (fitnessLevel) {
      case FitnessLevel.beginner:
        met *= 1.05; // Beginners expend slightly more mechanical energy
        break;
      case FitnessLevel.intermediate:
        break;
      case FitnessLevel.advanced:
        met *= 0.95; // Highly conditioned athletes have optimized metabolic efficiency
        break;
    }

    final durationMinutes = durationSeconds / 60.0;
    final calories = (met * 3.5 * weightKg / 200.0) * durationMinutes;

    return calories.round().clamp(1, 9999);
  }

  /// Formats calorie display with icon and unit
  static String formatCalories(int calories) {
    return '🔥 $calories ккал';
  }
}
