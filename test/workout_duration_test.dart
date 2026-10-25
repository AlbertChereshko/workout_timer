import 'package:flutter_test/flutter_test.dart';
import 'package:workout_timer/data/models/workout.dart';

void main() {
  group('WorkoutDurationExtension Unit Tests', () {
    test('calculates duration for simple EMOM without exercises', () {
      final workout = Workout()
        ..type = WorkoutType.emom
        ..emomRounds = 10
        ..emomRoundDurationSeconds = 60;

      expect(workout.totalDurationSeconds, 600);
      expect(workout.formatTotalDuration(), '10 мин');
    });

    test('calculates duration for simple Tabata without exercises', () {
      final workout = Workout()
        ..type = WorkoutType.tabata
        ..tabataRounds = 8
        ..tabataWorkSeconds = 20
        ..tabataRestSeconds = 10;

      // 8 * (20 + 10) = 240 seconds = 4 minutes
      expect(workout.totalDurationSeconds, 240);
      expect(workout.formatTotalDuration(), '4 мин');
    });

    test('calculates duration for EMOM with exercises and circuits', () {
      final workout = Workout()
        ..type = WorkoutType.emom
        ..emomRounds = 6 // 3 exercises * 2 circuits
        ..emomRoundDurationSeconds = 60
        ..exercises = [
          Exercise()..name = 'Pushups'..durationSeconds = 45,
          Exercise()..name = 'Squats'..durationSeconds = 50,
          Exercise()..name = 'Plank'..durationSeconds = 60,
        ];

      // circuits = (6 / 3).round() = 2
      // per circuit = 45 + 50 + 60 = 155s
      // total = 155 * 2 = 310s = 5м 10с
      expect(workout.totalDurationSeconds, 310);
      expect(workout.formatTotalDuration(), '5м 10с');
    });

    test('calculates duration for Tabata with exercises and circuits', () {
      final workout = Workout()
        ..type = WorkoutType.tabata
        ..tabataRounds = 4 // 2 exercises * 2 circuits
        ..tabataWorkSeconds = 30
        ..tabataRestSeconds = 15
        ..exercises = [
          Exercise()..name = 'Burpees'..durationSeconds = 40,
          Exercise()..name = 'Jumping Jacks'..durationSeconds = 30,
        ];

      // circuits = (4 / 2).round() = 2
      // per exercise: work + rest: (40 + 15) + (30 + 15) = 55 + 45 = 100s
      // total = 100 * 2 = 200s = 3м 20с
      expect(workout.totalDurationSeconds, 200);
      expect(workout.formatTotalDuration(), '3м 20с');
    });

    test('formats hours and minutes accurately', () {
      expect(WorkoutDurationExtension.formatSeconds(3600), '1 ч');
      expect(WorkoutDurationExtension.formatSeconds(3660), '1 ч 1 мин');
      expect(WorkoutDurationExtension.formatSeconds(7200), '2 ч');
      expect(WorkoutDurationExtension.formatSeconds(45), '45 сек');
      expect(WorkoutDurationExtension.formatSeconds(0), '0 сек');
    });
  });
}
