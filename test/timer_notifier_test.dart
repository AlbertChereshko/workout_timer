import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workout_timer/domain/emom_timer_notifier.dart';
import 'package:workout_timer/domain/timer_state.dart';
import 'package:workout_timer/data/models/workout.dart';

import 'package:workout_timer/services/audio_service.dart';
import 'package:workout_timer/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TimerNotifier Unit Tests', () {
    late ProviderContainer container;

    setUp(() {
      AudioService().soundMode = SoundMode.vibrationOnly;
      AudioService().isVibrationEnabled = false;
      NotificationService().isNotificationsEnabled = false;
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state has 3 seconds countdown and is not running', () {
      final state = container.read(activeTimerProvider);
      expect(state.phase, TimerPhase.countdown);
      expect(state.remainingSeconds, 3);
      expect(state.isRunning, false);
      expect(state.currentRound, 1);
    });

    test('loadWorkout loads EMOM workout with correct total rounds', () {
      final workout = Workout()
        ..name = 'Test EMOM'
        ..type = WorkoutType.emom
        ..emomRounds = 8
        ..emomRoundDurationSeconds = 60;

      final notifier = container.read(activeTimerProvider.notifier);
      notifier.loadWorkout(workout);

      final state = container.read(activeTimerProvider);
      expect(state.phase, TimerPhase.countdown);
      expect(state.totalRounds, 8);
      expect(state.remainingSeconds, 3);
      expect(state.isRunning, false);
    });

    test('loadWorkout loads Tabata workout with correct total rounds', () {
      final workout = Workout()
        ..name = 'Test Tabata'
        ..type = WorkoutType.tabata
        ..tabataRounds = 4
        ..tabataWorkSeconds = 20
        ..tabataRestSeconds = 10;

      final notifier = container.read(activeTimerProvider.notifier);
      notifier.loadWorkout(workout);

      final state = container.read(activeTimerProvider);
      expect(state.phase, TimerPhase.countdown);
      expect(state.totalRounds, 4);
    });

    test('skipNext transitions from countdown to work phase', () {
      final workout = Workout()
        ..name = 'Test EMOM'
        ..type = WorkoutType.emom
        ..emomRounds = 3
        ..emomRoundDurationSeconds = 45;

      final notifier = container.read(activeTimerProvider.notifier);
      notifier.loadWorkout(workout);

      // Skip countdown
      notifier.skipNext();

      final state = container.read(activeTimerProvider);
      expect(state.phase, TimerPhase.work);
      expect(state.currentRound, 1);
      expect(state.remainingSeconds, 45);
    });

    test('skipNext in Tabata alternates between work and rest', () {
      final workout = Workout()
        ..name = 'Test Tabata'
        ..type = WorkoutType.tabata
        ..tabataRounds = 2
        ..tabataWorkSeconds = 20
        ..tabataRestSeconds = 10;

      final notifier = container.read(activeTimerProvider.notifier);
      notifier.loadWorkout(workout);

      // From countdown -> Work Round 1
      notifier.skipNext();
      expect(container.read(activeTimerProvider).phase, TimerPhase.work);
      expect(container.read(activeTimerProvider).remainingSeconds, 20);

      // From Work Round 1 -> Rest Round 1
      notifier.skipNext();
      expect(container.read(activeTimerProvider).phase, TimerPhase.rest);
      expect(container.read(activeTimerProvider).remainingSeconds, 10);

      // From Rest Round 1 -> Work Round 2
      notifier.skipNext();
      expect(container.read(activeTimerProvider).phase, TimerPhase.work);
      expect(container.read(activeTimerProvider).currentRound, 2);

      // From Work Round 2 -> Rest Round 2
      notifier.skipNext();
      expect(container.read(activeTimerProvider).phase, TimerPhase.rest);

      // From Rest Round 2 -> Finished
      notifier.skipNext();
      expect(container.read(activeTimerProvider).phase, TimerPhase.finished);
    });

    test('toggle starts and pauses timer state', () {
      final notifier = container.read(activeTimerProvider.notifier);
      expect(container.read(activeTimerProvider).isRunning, false);

      notifier.toggle();
      expect(container.read(activeTimerProvider).isRunning, true);

      notifier.toggle();
      expect(container.read(activeTimerProvider).isRunning, false);
    });

    test('skipPrevious resets current phase or goes to previous round', () {
      final workout = Workout()
        ..name = 'Test EMOM'
        ..type = WorkoutType.emom
        ..emomRounds = 3
        ..emomRoundDurationSeconds = 60;

      final notifier = container.read(activeTimerProvider.notifier);
      notifier.loadWorkout(workout);
      notifier.skipNext(); // to work round 1

      expect(container.read(activeTimerProvider).currentRound, 1);
      
      notifier.skipNext(); // to work round 2
      expect(container.read(activeTimerProvider).currentRound, 2);

      notifier.skipPrevious(); // back to round 1 (or reset)
      expect(container.read(activeTimerProvider).phase, TimerPhase.work);
    });

    test('resume and finishEarly update timer state correctly', () async {
      final workout = Workout()
        ..name = 'Quick EMOM'
        ..type = WorkoutType.emom
        ..emomRounds = 5
        ..emomRoundDurationSeconds = 60;

      final notifier = container.read(activeTimerProvider.notifier);
      notifier.loadWorkout(workout);
      notifier.pause();
      expect(container.read(activeTimerProvider).isRunning, false);

      notifier.resume();
      expect(container.read(activeTimerProvider).isRunning, true);

      await notifier.finishEarly();
      expect(container.read(activeTimerProvider).phase, TimerPhase.finished);
      expect(container.read(activeTimerProvider).isRunning, false);
      expect(container.read(activeTimerProvider).remainingSeconds, 0);
    });

    test('loadWorkout loads AMRAP workout and records rounds/exercises', () {
      final workout = Workout()
        ..name = 'Test AMRAP'
        ..type = WorkoutType.amrap
        ..amrapDurationSeconds = 600
        ..amrapCountByRounds = false
        ..exercises = [
          Exercise()..name = 'Pull ups'..reps = 5,
          Exercise()..name = 'Push ups'..reps = 10,
        ];

      final notifier = container.read(activeTimerProvider.notifier);
      notifier.loadWorkout(workout);

      var state = container.read(activeTimerProvider);
      expect(state.phase, TimerPhase.countdown);
      expect(state.totalRounds, 0);
      expect(state.currentRound, 0);

      // Skip countdown to start work
      notifier.skipNext();
      state = container.read(activeTimerProvider);
      expect(state.phase, TimerPhase.work);
      expect(state.remainingSeconds, 600);
      expect(state.currentRound, 0);
      expect(state.currentExerciseIndex, 0);

      // Complete exercise 1
      notifier.recordAmrapExercise();
      state = container.read(activeTimerProvider);
      expect(state.currentExerciseIndex, 1);
      expect(state.extraReps, 1);
      expect(state.currentRound, 0);

      // Complete exercise 2 -> loop completed, round increments
      notifier.recordAmrapExercise();
      state = container.read(activeTimerProvider);
      expect(state.currentExerciseIndex, 0);
      expect(state.extraReps, 0);
      expect(state.currentRound, 1);

      // Direct round recording
      notifier.recordAmrapRound();
      state = container.read(activeTimerProvider);
      expect(state.currentRound, 2);
    });
  });
}

