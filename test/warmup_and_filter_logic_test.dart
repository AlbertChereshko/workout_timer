import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workout_timer/data/models/workout.dart';
import 'package:workout_timer/domain/timer_state.dart';
import 'package:workout_timer/domain/emom_timer_notifier.dart';
import 'package:workout_timer/services/warmup_service.dart';
import 'package:workout_timer/services/audio_service.dart';
import 'package:workout_timer/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WarmupService Tests', () {
    test('warmup 3 minutes has 6 exercises with 30s each and back protection tips', () {
      final list = WarmupService.getExercisesForDuration(180);
      expect(list.length, 6);
      for (final ex in list) {
        expect(ex.durationSeconds, 30);
        expect(ex.title.isNotEmpty, true);
        expect(ex.backProtectionTip.isNotEmpty, true);
      }
      expect(list.any((e) => e.title.contains('Кошка — Собака')), true);
      expect(list.any((e) => e.title.contains('Гудморнинг')), true);
    });

    test('warmup 5 minutes has 10 exercises including glute activation and thoracic mobility', () {
      final list = WarmupService.getExercisesForDuration(300);
      expect(list.length, 10);
      expect(list.any((e) => e.title.contains('ягодичн')), true);
      expect(list.any((e) => e.title.contains('грудного')), true);
      expect(list.any((e) => e.title.contains('Мельница')), true);
    });
  });

  group('TimerNotifier Warmup Phase Tests', () {
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

    final testWorkout = Workout()
      ..name = 'Тестовый комплекс'
      ..type = WorkoutType.emom
      ..emomRounds = 5
      ..emomRoundDurationSeconds = 60
      ..exercises = [];

    test('loadWorkout with warmupSeconds starts in TimerPhase.warmup', () {
      final notifier = container.read(activeTimerProvider.notifier);
      notifier.loadWorkout(testWorkout, warmupSeconds: 180);

      final state = container.read(activeTimerProvider);
      expect(state.phase, TimerPhase.warmup);
      expect(state.remainingSeconds, 180);
      expect(state.totalPhaseSeconds, 180);
      expect(state.currentExerciseIndex, 0);
      expect(state.warmupTotalSeconds, 180);
    });

    test('skipWarmup transitions immediately to TimerPhase.countdown', () {
      final notifier = container.read(activeTimerProvider.notifier);
      notifier.loadWorkout(testWorkout, warmupSeconds: 180);

      expect(container.read(activeTimerProvider).phase, TimerPhase.warmup);

      notifier.skipWarmup();

      final state = container.read(activeTimerProvider);
      expect(state.phase, TimerPhase.countdown);
      expect(state.remainingSeconds, 3);
      expect(state.totalPhaseSeconds, 3);
      expect(state.currentExerciseIndex, 0);
    });

    test('skipWarmupExercise advances index and decrements remaining by 30 seconds', () {
      final notifier = container.read(activeTimerProvider.notifier);
      notifier.loadWorkout(testWorkout, warmupSeconds: 180);

      notifier.skipWarmupExercise();

      var state = container.read(activeTimerProvider);
      expect(state.phase, TimerPhase.warmup);
      expect(state.currentExerciseIndex, 1);
      expect(state.remainingSeconds, 150);

      // Skip through the rest
      notifier.skipWarmupExercise(); // idx 2, 120s
      notifier.skipWarmupExercise(); // idx 3, 90s
      notifier.skipWarmupExercise(); // idx 4, 60s
      notifier.skipWarmupExercise(); // idx 5, 30s
      notifier.skipWarmupExercise(); // idx 6 >= length -> transitions to countdown!

      state = container.read(activeTimerProvider);
      expect(state.phase, TimerPhase.countdown);
      expect(state.remainingSeconds, 3);
    });

    test('loadWorkout with 0 warmupSeconds starts directly in countdown', () {
      final notifier = container.read(activeTimerProvider.notifier);
      notifier.loadWorkout(testWorkout, warmupSeconds: 0);

      final state = container.read(activeTimerProvider);
      expect(state.phase, TimerPhase.countdown);
      expect(state.remainingSeconds, 3);
    });
  });

  group('Equipment Matching Edge Cases', () {
    test('16 kg workout does not match 6 kg filter', () {
      final workout16 = Workout()
        ..name = 'Плечевой пояс'
        ..tags = ['16 кг', 'Плечи', 'Верх']
        ..exercises = [
          Exercise()..name = 'Махи 16 кг',
        ];

      // Re-verify regexp logic matching
      final reg6 = RegExp(r'(^|\D)6\s*(кг|kg)?($|\D)', caseSensitive: false);
      final has6Tag = workout16.tags.any((t) =>
          reg6.hasMatch(t) &&
          (t.contains('кг') || t.contains('гир')) &&
          !t.contains('16') &&
          !t.contains('26'));
      final has6Ex = workout16.exercises.any((e) =>
          RegExp(r'(^|\D)6\s*(кг|kg)($|\D)', caseSensitive: false).hasMatch(e.name));

      expect(has6Tag, false);
      expect(has6Ex, false);
    });

    test('6 exercises count does not trigger 6 kg equipment filter', () {
      final workout6Ex = Workout()
        ..name = 'Базовый сет'
        ..tags = ['6 упр.', 'Тело']
        ..exercises = [
          Exercise()..name = 'Отжимания',
        ];

      final reg6 = RegExp(r'(^|\D)6\s*(кг|kg)?($|\D)', caseSensitive: false);
      final has6Tag = workout6Ex.tags.any((t) =>
          reg6.hasMatch(t) &&
          (t.contains('кг') || t.contains('гир')) &&
          !t.contains('16') &&
          !t.contains('26'));

      expect(has6Tag, false);
    });

    test('toWorkout produces valid workout with tabata structure', () {
      final workout = WarmupService.toWorkout(180);
      expect(workout.type, WorkoutType.tabata);
      expect(workout.tabataRounds, 6);
      expect(workout.tabataWorkSeconds, 30);
      expect(workout.tabataRestSeconds, 0);
      expect(workout.tags.contains('Разминка'), true);
      expect(workout.tags.contains('Без инвентаря'), true);
    });
  });
}
