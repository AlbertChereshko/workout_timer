import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:workout_timer/data/models/exercise_library.dart';
import 'package:workout_timer/data/models/workout.dart';

void main() {
  const enc = JsonEncoder.withIndent('  ');

  Workout sample(String name, WorkoutType type) {
    return Workout()
      ..name = name
      ..type = type
      ..emomRounds = 12
      ..emomRoundDurationSeconds = 45
      ..tabataWorkSeconds = 30
      ..tabataRestSeconds = 15
      ..tabataRounds = 6
      ..amrapDurationSeconds = 600
      ..amrapCountByRounds = false
      ..videoUrl = 'https://youtu.be/abc'
      ..tags = ['дом', 'ноги']
      ..exercises = [
        Exercise()
          ..name = 'Присед'
          ..reps = 15
          ..description = 'desc'
          ..notes = 'note',
        Exercise()
          ..name = 'Планка'
          ..durationSeconds = 40
          ..videoUrl = 'https://youtu.be/xyz',
      ];
  }

  void expectSame(Workout a, Workout b) {
    expect(b.name, a.name);
    expect(b.type, a.type);
    expect(b.emomRounds, a.emomRounds);
    expect(b.emomRoundDurationSeconds, a.emomRoundDurationSeconds);
    expect(b.tabataWorkSeconds, a.tabataWorkSeconds);
    expect(b.tabataRestSeconds, a.tabataRestSeconds);
    expect(b.tabataRounds, a.tabataRounds);
    expect(b.amrapDurationSeconds, a.amrapDurationSeconds);
    expect(b.amrapCountByRounds, a.amrapCountByRounds);
    expect(b.videoUrl, a.videoUrl);
    expect(b.tags, a.tags);
    expect(b.exercises.length, a.exercises.length);
    for (var i = 0; i < a.exercises.length; i++) {
      expect(b.exercises[i].name, a.exercises[i].name);
      expect(b.exercises[i].reps, a.exercises[i].reps);
      expect(b.exercises[i].durationSeconds, a.exercises[i].durationSeconds);
      expect(b.exercises[i].description, a.exercises[i].description);
      expect(b.exercises[i].notes, a.exercises[i].notes);
      expect(b.exercises[i].videoUrl, a.exercises[i].videoUrl);
    }
  }

  group('Workout export/import', () {
    test('single workout round-trip for every type', () {
      for (final t in WorkoutType.values) {
        final w = sample('Комплекс ${t.name}', t);
        final decoded = jsonDecode(enc.convert(w.toJson())) as Map<String, dynamic>;
        expectSame(w, Workout.fromJson(decoded));
      }
    });

    test('all workouts list round-trip', () {
      final list = [
        sample('A', WorkoutType.emom),
        sample('B', WorkoutType.amrap),
      ];
      final decoded = jsonDecode(enc.convert(list.map((w) => w.toJson()).toList())) as List;
      final back = decoded.map((e) => Workout.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      expect(back.length, 2);
      for (var i = 0; i < 2; i++) {
        expectSame(list[i], back[i]);
      }
    });

    test('malformed/minimal json does not crash', () {
      final w = Workout.fromJson({'name': 'X'});
      expect(w.name, 'X');
      expect(w.exercises, isEmpty);
    });
  });

  group('ExerciseDefinition export/import', () {
    test('round-trip for entire built-in library', () {
      const all = ExerciseLibrary.catalog;
      expect(all, isNotEmpty);
      final decoded = jsonDecode(enc.convert(all.map((e) => e.toJson()).toList())) as List;
      final back = decoded.map((e) => ExerciseDefinition.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      expect(back.length, all.length);
      for (var i = 0; i < all.length; i++) {
        final a = all[i];
        final b = back[i];
        expect(b.id, a.id);
        expect(b.name, a.name);
        expect(b.targetMuscle, a.targetMuscle, reason: a.name);
        expect(b.subgroup, a.subgroup, reason: a.name);
        expect(b.isStatic, a.isStatic);
        expect(b.defaultReps, a.defaultReps);
        expect(b.defaultDurationSeconds, a.defaultDurationSeconds);
        expect(b.equipment, a.equipment, reason: a.name);
        expect(b.difficulty, a.difficulty, reason: a.name);
        expect(b.tags, a.tags);
        expect(b.videoUrl, a.videoUrl);
        expect(b.notes, a.notes);
      }
    });
  });
}
