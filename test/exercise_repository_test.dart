import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:workout_timer/data/models/exercise_library.dart';
import 'package:workout_timer/data/repositories/exercise_repository.dart';
import 'package:workout_timer/services/recovery_analyzer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late ExerciseRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_exercise_test_');
    Hive.init(tempDir.path);
    await Hive.openBox('settings');
    repository = ExerciseRepository();
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('ExerciseRepository Tests', () {
    test('getAllExercises initially returns all catalog exercises without duplicates', () {
      final all = repository.getAllExercises();
      expect(all.length, ExerciseLibrary.catalog.length);
      expect(all.first.id, ExerciseLibrary.catalog.first.id);
    });

    test('isCustom returns false for catalog exercise and true for custom exercise', () {
      expect(repository.isCustom('plank_classic'), false);
      expect(repository.isCustom('custom_12345'), true);
    });

    test('overriding catalog exercise updates in place without duplicating', () async {
      final initialCount = repository.getAllExercises().length;

      expect(repository.isOverridden('plank_classic'), false);

      const modifiedPlank = ExerciseDefinition(
        id: 'plank_classic',
        name: 'Супер Планка 60 сек',
        description: 'Новое модифицированное описание',
        targetMuscle: MuscleGroup.coreStatic,
        isStatic: true,
        defaultDurationSeconds: 60,
        defaultReps: 0,
        equipment: ExerciseEquipment.bodyweight,
        tags: ['Кор', 'Статика'],
      );

      await repository.saveExercise(modifiedPlank);

      final updatedList = repository.getAllExercises();
      // Count must not increase!
      expect(updatedList.length, initialCount);

      // Must be overridden
      expect(repository.isOverridden('plank_classic'), true);
      expect(repository.isCustom('plank_classic'), false);

      // Finding by id must return modified values
      final fetched = updatedList.firstWhere((e) => e.id == 'plank_classic');
      expect(fetched.name, 'Супер Планка 60 сек');
      expect(fetched.defaultDurationSeconds, 60);
      expect(fetched.description, 'Новое модифицированное описание');

      // Original catalog index must be preserved
      final originalIndex = ExerciseLibrary.catalog.indexWhere((e) => e.id == 'plank_classic');
      final newIndex = updatedList.indexWhere((e) => e.id == 'plank_classic');
      expect(newIndex, originalIndex);
    });

    test('deleting overridden exercise resets it back to catalog defaults', () async {
      const modifiedPlank = ExerciseDefinition(
        id: 'plank_classic',
        name: 'Временная Планка',
        description: 'Тест',
        targetMuscle: MuscleGroup.coreStatic,
        isStatic: true,
        defaultDurationSeconds: 99,
        defaultReps: 0,
        equipment: ExerciseEquipment.bodyweight,
      );

      await repository.saveExercise(modifiedPlank);
      expect(repository.isOverridden('plank_classic'), true);

      // Reset / delete override
      await repository.deleteExercise('plank_classic');
      expect(repository.isOverridden('plank_classic'), false);

      final restoredPlank = repository.getAllExercises().firstWhere((e) => e.id == 'plank_classic');
      final defaultPlank = ExerciseLibrary.findByNameOrId('plank_classic')!;
      expect(restoredPlank.name, defaultPlank.name);
      expect(restoredPlank.defaultDurationSeconds, defaultPlank.defaultDurationSeconds);
    });

    test('creating and deleting user custom exercise', () async {
      final initialCount = repository.getAllExercises().length;

      const customExercise = ExerciseDefinition(
        id: 'custom_jumping_burpees',
        name: 'Прыжковые бёрпи с хлопком',
        description: 'Высокая интенсивность',
        targetMuscle: MuscleGroup.metabolicFullBody,
        isStatic: false,
        defaultDurationSeconds: 30,
        defaultReps: 25,
        equipment: ExerciseEquipment.bodyweight,
      );

      await repository.saveExercise(customExercise);

      expect(repository.getAllExercises().length, initialCount + 1);
      expect(repository.isCustom('custom_jumping_burpees'), true);
      expect(repository.isOverridden('custom_jumping_burpees'), false);

      final added = repository.getAllExercises().firstWhere((e) => e.id == 'custom_jumping_burpees');
      expect(added.name, 'Прыжковые бёрпи с хлопком');
      expect(added.defaultReps, 25);

      // Deleting custom exercise
      await repository.deleteExercise('custom_jumping_burpees');
      expect(repository.getAllExercises().length, initialCount);
      expect(repository.getAllExercises().any((e) => e.id == 'custom_jumping_burpees'), false);
    });

    test('ExerciseListNotifier updates state on save and delete', () async {
      final notifier = ExerciseListNotifier(repository);
      expect(notifier.state.length, repository.getAllExercises().length);

      const custom = ExerciseDefinition(
        id: 'custom_notifier_test',
        name: 'Тестовое упражнение',
        description: '',
        targetMuscle: MuscleGroup.lowerBody,
        isStatic: false,
        defaultDurationSeconds: 30,
        defaultReps: 15,
        equipment: ExerciseEquipment.bodyweight,
      );

      await notifier.saveExercise(custom);
      expect(notifier.state.any((e) => e.id == 'custom_notifier_test'), true);

      await notifier.deleteExercise('custom_notifier_test');
      expect(notifier.state.any((e) => e.id == 'custom_notifier_test'), false);
    });
  });
}
