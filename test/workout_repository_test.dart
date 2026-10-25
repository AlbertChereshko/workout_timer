import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:workout_timer/data/models/workout.dart';
import 'package:workout_timer/data/repositories/workout_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Box<Workout> box;
  late WorkoutRepository repository;
  late WorkoutListNotifier notifier;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_workout_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(WorkoutAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(WorkoutTypeAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(ExerciseAdapter());
    }
    box = await Hive.openBox<Workout>('workouts');
    repository = WorkoutRepository(box);
    notifier = WorkoutListNotifier(repository);
  });

  tearDown(() async {
    await box.close();
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('WorkoutRepository & WorkoutListNotifier Tests', () {
    test('initially returns empty list when box is empty', () {
      expect(repository.getWorkouts(), isEmpty);
      expect(notifier.state, isEmpty);
    });

    test('saving a workout adds it to repository and updates notifier state', () async {
      final workout = Workout()
        ..name = 'Тестовая Табата'
        ..type = WorkoutType.tabata
        ..tabataRounds = 8
        ..tags = ['Кор'];

      await notifier.saveWorkout(workout);

      expect(repository.getWorkouts().length, 1);
      expect(repository.getWorkouts().first.name, 'Тестовая Табата');
      expect(notifier.state.length, 1);
      expect(notifier.state.first.name, 'Тестовая Табата');
    });

    test('deleting a workout removes it and updates notifier state', () async {
      final workout = Workout()
        ..name = 'Комплекс для удаления'
        ..type = WorkoutType.emom
        ..emomRounds = 10;

      await notifier.saveWorkout(workout);
      expect(notifier.state.length, 1);

      final key = workout.key as int;
      await notifier.deleteWorkout(key);

      expect(repository.getWorkouts(), isEmpty);
      expect(notifier.state, isEmpty);
    });

    test('editing a saved workout updates it in place', () async {
      final workout = Workout()
        ..name = 'Исходное имя'
        ..type = WorkoutType.amrap;

      await notifier.saveWorkout(workout);
      expect(notifier.state.first.name, 'Исходное имя');

      workout.name = 'Новое имя после редактирования';
      await notifier.saveWorkout(workout);

      expect(notifier.state.length, 1);
      expect(notifier.state.first.name, 'Новое имя после редактирования');
    });
  });
}
