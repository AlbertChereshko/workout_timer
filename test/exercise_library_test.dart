import 'package:flutter_test/flutter_test.dart';
import 'package:workout_timer/data/models/exercise_library.dart';
import 'package:workout_timer/services/recovery_analyzer.dart';

void main() {
  group('ExerciseLibrary tests', () {
    test('catalog contains static and dynamic exercises', () {
      expect(ExerciseLibrary.catalog.isNotEmpty, true);

      final staticExercises = ExerciseLibrary.catalog.where((e) => e.isStatic).toList();
      final dynamicExercises = ExerciseLibrary.catalog.where((e) => !e.isStatic).toList();

      expect(staticExercises.isNotEmpty, true);
      expect(dynamicExercises.isNotEmpty, true);
    });

    test('static exercise toExercise sets durationSeconds and null reps', () {
      final plankDef = ExerciseLibrary.findByNameOrId('plank_classic');
      expect(plankDef, isNotNull);
      expect(plankDef!.isStatic, true);

      final exercise = plankDef.toExercise();
      expect(exercise.durationSeconds, plankDef.defaultDurationSeconds);
      expect(exercise.reps, isNull);
    });

    test('dynamic exercise toExercise sets reps', () {
      final pushupsDef = ExerciseLibrary.findByNameOrId('pushups_classic');
      expect(pushupsDef, isNotNull);
      expect(pushupsDef!.isStatic, false);

      final exercise = pushupsDef.toExercise();
      expect(exercise.reps, pushupsDef.defaultReps);
    });

    test('filter by muscleGroup returns correct exercises', () {
      final coreList = ExerciseLibrary.filter(muscleGroup: MuscleGroup.coreStatic);
      expect(coreList.every((e) => e.targetMuscle == MuscleGroup.coreStatic), true);
    });

    test('filter by equipment returns kettlebell exercises', () {
      final kbList = ExerciseLibrary.filter(equipment: ExerciseEquipment.kettlebell);
      expect(kbList.every((e) => e.equipment.isKettlebell), true);
    });
  });
}
