import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_timer/core/theme.dart';
import 'package:workout_timer/data/models/workout.dart';
import 'package:workout_timer/domain/timer_state.dart';
import 'package:workout_timer/features/timer/widgets/neon_timer_view.dart';
import 'package:workout_timer/features/timer/widgets/cosmic_timer_view.dart';
import 'package:workout_timer/core/typography_scale_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Workout buildTestWorkout() {
    return Workout()
      ..name = 'Табата Тренировка'
      ..type = WorkoutType.tabata
      ..tabataWorkSeconds = 20
      ..tabataRestSeconds = 10
      ..tabataRounds = 3
      ..exercises = [
        Exercise()..name = 'Приседания',
        Exercise()..name = 'Отжимания',
        Exercise()..name = 'Планка',
      ];
  }

  group('Next Exercise and Header Features Tests', () {
    testWidgets('NeonTimerView shows exit button and music button in header', (tester) async {
      final workout = buildTestWorkout();
      final state = TimerState(
        phase: TimerPhase.work,
        remainingSeconds: 20,
        totalPhaseSeconds: 20,
        currentRound: 1,
        totalRounds: 3,
        isRunning: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NeonTimerView(
              workout: workout,
              state: state,
              progress: 1.0,
              theme: AppThemes.neonDark,
              onTogglePlayPause: () {},
              onSkipPrevious: () {},
              onSkipNext: () {},
              onFinishEarly: () {},
            ),
          ),
        ),
      );

      // Verify header back / exit button is present
      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
      // Verify music button is present
      expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);
      // Verify next exercise shows exercise 2 with upward arrow
      expect(find.text('↑ ОТЖИМАНИЯ'), findsOneWidget);
    });

    testWidgets('NeonTimerView shows "↑ КОНЕЦ ТРЕНИРОВКИ" on final round without wrapping to exercise 1', (tester) async {
      final workout = buildTestWorkout();
      final state = TimerState(
        phase: TimerPhase.work,
        remainingSeconds: 20,
        totalPhaseSeconds: 20,
        currentRound: 3,
        totalRounds: 3,
        isRunning: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NeonTimerView(
              workout: workout,
              state: state,
              progress: 1.0,
              theme: AppThemes.neonDark,
              onTogglePlayPause: () {},
              onSkipPrevious: () {},
              onSkipNext: () {},
              onFinishEarly: () {},
            ),
          ),
        ),
      );

      // On final round 3 of 3, next exercise must be "КОНЕЦ ТРЕНИРОВКИ", NOT "ПРИСЕДАНИЯ"
      expect(find.text('↑ КОНЕЦ ТРЕНИРОВКИ'), findsOneWidget);
      expect(find.text('↑ ПРИСЕДАНИЯ'), findsNothing);
    });

    testWidgets('CosmicTimerView shows exit button, music button, and "Конец тренировки" on final round', (tester) async {
      final workout = buildTestWorkout();
      final state = TimerState(
        phase: TimerPhase.work,
        remainingSeconds: 20,
        totalPhaseSeconds: 20,
        currentRound: 3,
        totalRounds: 3,
        isRunning: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CosmicTimerView(
              workout: workout,
              state: state,
              progress: 1.0,
              scaleConfig: const TypographyScaleConfig(),
              theme: AppThemes.cosmicDark,
              initialShowSatellites: false,
              onTogglePlayPause: () {},
              onSkipPrevious: () {},
              onSkipNext: () {},
              onReset: () {},
              onFinishEarly: () {},
            ),
          ),
        ),
      );

      // Verify header buttons
      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
      expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);
      // Verify next exercise is КОНЕЦ ТРЕНИРОВКИ and not exercise 1
      expect(find.text('↑ КОНЕЦ ТРЕНИРОВКИ'), findsOneWidget);
    });
  });
}
