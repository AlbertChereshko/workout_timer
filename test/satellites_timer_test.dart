import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_timer/core/theme.dart';
import 'package:workout_timer/core/typography_scale_provider.dart';
import 'package:workout_timer/data/models/workout.dart';
import 'package:workout_timer/domain/timer_state.dart';
import 'package:workout_timer/features/timer/widgets/cosmic_timer_view.dart';
import 'package:workout_timer/features/timer/widgets/real_time_clock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestWidget({
    required Workout workout,
    required TimerState state,
  }) {
    return MaterialApp(
      home: CosmicTimerView(
        workout: workout,
        state: state,
        progress: 0.5,
        scaleConfig: const TypographyScaleConfig(),
        theme: AppThemes.satellitesDark,
        initialShowSatellites: true,
        onTogglePlayPause: () {},
        onSkipPrevious: () {},
        onSkipNext: () {},
        onReset: () {},
        onFinishEarly: () {},
      ),
    );
  }

  group('CosmicTimerView Satellites Mode Tests', () {
    late Workout tabataWorkout;

    setUp(() {
      tabataWorkout = Workout()
        ..name = 'Табата Тест'
        ..type = WorkoutType.tabata
        ..tabataRounds = 4
        ..tabataWorkSeconds = 20
        ..tabataRestSeconds = 10;
    });

    testWidgets('displays static durations during countdown/preparation', (tester) async {
      final state = TimerState(
        phase: TimerPhase.countdown,
        currentRound: 1,
        totalRounds: 4,
        remainingSeconds: 3,
        totalPhaseSeconds: 3,
        isRunning: false,
      );

      await tester.pumpWidget(buildTestWidget(workout: tabataWorkout, state: state));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Titles
      expect(find.text('РАБОТА'), findsOneWidget);
      expect(find.text('ОТДЫХ'), findsOneWidget);
      expect(find.text('СЕТЫ'), findsOneWidget);
      expect(find.text('ОБЩЕЕ ВРЕМЯ'), findsOneWidget);

      // Work should show 00:20 (total round work time) before work starts
      expect(find.text('00:20'), findsOneWidget);
      // Rest should show 00:10 (total rest time)
      expect(find.text('00:10'), findsOneWidget);
      // Sets
      expect(find.text('1 / 4'), findsOneWidget);
    });

    testWidgets('displays active countdown in РАБОТА circle during work phase', (tester) async {
      // 7 seconds remaining in work phase
      final state = TimerState(
        phase: TimerPhase.work,
        currentRound: 1,
        totalRounds: 4,
        remainingSeconds: 7,
        totalPhaseSeconds: 20,
        isRunning: true,
      );

      await tester.pumpWidget(buildTestWidget(workout: tabataWorkout, state: state));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // РАБОТА now displays remaining 7 seconds: 00:07!
      expect(find.text('00:07'), findsOneWidget);
      // ОТДЫХ still displays configured rest: 00:10
      expect(find.text('00:10'), findsOneWidget);
    });

    testWidgets('displays active countdown in ОТДЫХ circle during rest phase', (tester) async {
      // 4 seconds remaining in rest phase
      final state = TimerState(
        phase: TimerPhase.rest,
        currentRound: 1,
        totalRounds: 4,
        remainingSeconds: 4,
        totalPhaseSeconds: 10,
        isRunning: true,
      );

      await tester.pumpWidget(buildTestWidget(workout: tabataWorkout, state: state));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // РАБОТА displays configured work time: 00:20
      expect(find.text('00:20'), findsOneWidget);
      // ОТДЫХ displays remaining rest time: 00:04!
      expect(find.text('00:04'), findsOneWidget);
    });

    testWidgets('displays 00:00 when workout is finished', (tester) async {
      final state = TimerState(
        phase: TimerPhase.finished,
        currentRound: 4,
        totalRounds: 4,
        remainingSeconds: 0,
        totalPhaseSeconds: 0,
        isRunning: false,
      );

      await tester.pumpWidget(buildTestWidget(workout: tabataWorkout, state: state));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Both work and rest show 00:00
      expect(find.text('00:00'), findsNWidgets(3)); // Work, Rest, and Total Remaining
    });

    testWidgets('displays square clock satellite and exercise names without prefix', (tester) async {
      tabataWorkout.exercises = [
        Exercise()..name = 'Отжимания с переходом',
        Exercise()..name = 'Приседания с поворотом',
      ];
      final state = TimerState(
        phase: TimerPhase.work,
        currentRound: 1,
        totalRounds: 4,
        remainingSeconds: 15,
        totalPhaseSeconds: 20,
        isRunning: true,
      );

      await tester.pumpWidget(buildTestWidget(workout: tabataWorkout, state: state));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(RealTimeClock), findsOneWidget);
      expect(find.text('ВРЕМЯ'), findsNothing);
      expect(find.text('Текущее'), findsNothing);
      expect(find.text('ОТЖИМАНИЯ С ПЕРЕХОДОМ'), findsOneWidget);
      expect(find.text('ПРИСЕДАНИЯ С ПОВОРОТОМ'), findsOneWidget);
      expect(find.textContaining('СЛЕДУЮЩЕЕ:'), findsNothing);
    });

    testWidgets('EMOM mode renders 3 circles without ОТДЫХ and with large РАБОТА', (tester) async {
      final emomWorkout = Workout()
        ..name = 'EMOM 10 Min'
        ..type = WorkoutType.emom
        ..emomRounds = 10
        ..emomRoundDurationSeconds = 60
        ..tabataRestSeconds = 0;

      final state = TimerState(
        phase: TimerPhase.work,
        currentRound: 2,
        totalRounds: 10,
        remainingSeconds: 45,
        totalPhaseSeconds: 60,
        isRunning: true,
      );

      await tester.pumpWidget(buildTestWidget(workout: emomWorkout, state: state));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // ОТДЫХ must NOT be present in EMOM mode
      expect(find.text('ОТДЫХ'), findsNothing);
      expect(find.text('Перерыв'), findsNothing);

      // 3 remaining circles must be present
      expect(find.text('РАБОТА'), findsOneWidget);
      expect(find.text('СЕТЫ'), findsOneWidget);
      expect(find.text('ОБЩЕЕ ВРЕМЯ'), findsOneWidget);

      // Verify values
      expect(find.text('00:45'), findsOneWidget); // remaining work
      expect(find.text('2 / 10'), findsOneWidget); // sets
    });

    testWidgets('Header has back/exit button and music picker button', (tester) async {
      final state = TimerState(
        phase: TimerPhase.work,
        currentRound: 1,
        totalRounds: 4,
        remainingSeconds: 20,
        totalPhaseSeconds: 20,
        isRunning: true,
      );

      await tester.pumpWidget(buildTestWidget(workout: tabataWorkout, state: state));
      await tester.pump();

      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
      expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);
    });
  });
}
