import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_timer/core/theme.dart';
import 'package:workout_timer/data/models/workout.dart';
import 'package:workout_timer/domain/timer_state.dart';
import 'package:workout_timer/core/typography_scale_provider.dart';
import 'package:workout_timer/features/timer/widgets/neon_timer_view.dart';
import 'package:workout_timer/features/timer/widgets/cosmic_timer_view.dart';
import 'package:workout_timer/features/timer/widgets/real_time_clock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Theme Consistency & Header Buttons Tests', () {
    test('Unified theme suite has exactly 6 themes covering 3 active styles x 2 modes', () {
      expect(AppThemes.all.length, 6);
      for (final style in [TimerStyle.satellites, TimerStyle.neon, TimerStyle.circular]) {
        final dark = AppThemes.all.where((t) => t.timerStyle == style && !t.isLight);
        final light = AppThemes.all.where((t) => t.timerStyle == style && t.isLight);
        expect(dark.length, 1, reason: 'Dark theme for $style should exist');
        expect(light.length, 1, reason: 'Light theme for $style should exist');
      }
    });

    testWidgets('NeonTimerView renders with passed theme colors and has no palette button', (tester) async {
      final workout = Workout()
        ..name = 'Табата Тест'
        ..type = WorkoutType.tabata
        ..tabataRounds = 4
        ..tabataWorkSeconds = 20
        ..tabataRestSeconds = 10;

      final state = TimerState(
        phase: TimerPhase.work,
        remainingSeconds: 20,
        currentRound: 1,
        totalRounds: 4,
        totalPhaseSeconds: 20,
        isRunning: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NeonTimerView(
              workout: workout,
              state: state,
              progress: 1.0,
              theme: AppThemes.neonLight,
              onTogglePlayPause: () {},
              onSkipPrevious: () {},
              onSkipNext: () {},
              onFinishEarly: () {},
            ),
          ),
        ),
      );

      // Verify no palette or volume icons in header
      expect(find.byIcon(Icons.palette_outlined), findsNothing);
      expect(find.byIcon(Icons.palette), findsNothing);
      expect(find.byIcon(Icons.volume_up_rounded), findsNothing);
      expect(find.byIcon(Icons.volume_off_rounded), findsNothing);

      // Verify workout name is displayed (NeonTimerView uppercases workout name)
      expect(find.text('ТАБАТА ТЕСТ'), findsOneWidget);
    });

    testWidgets('CosmicTimerView renders with passed theme and has no palette/volume button', (tester) async {
      final workout = Workout()
        ..name = 'Космос Тест'
        ..type = WorkoutType.emom
        ..emomRoundDurationSeconds = 60
        ..emomRounds = 5;

      final state = TimerState(
        phase: TimerPhase.work,
        remainingSeconds: 60,
        currentRound: 1,
        totalRounds: 5,
        totalPhaseSeconds: 60,
        isRunning: true,
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

      // Verify no palette or volume icons in header
      expect(find.byIcon(Icons.palette_outlined), findsNothing);
      expect(find.byIcon(Icons.palette), findsNothing);
      expect(find.byIcon(Icons.volume_up_rounded), findsNothing);
      expect(find.byIcon(Icons.volume_off_rounded), findsNothing);

      // Verify RealTimeClock is displayed and workout name is removed from header
      expect(find.byType(RealTimeClock), findsOneWidget);
      expect(find.text('Космос Тест'), findsNothing);
    });
  });
}
