import 'package:flutter_test/flutter_test.dart';
import 'package:workout_timer/data/models/workout.dart';
import 'package:workout_timer/data/models/workout_session.dart';

void main() {
  group('WorkoutSession RPE and AMRAP field tests', () {
    test('WorkoutSession stores and reads RPE rating', () {
      final session = WorkoutSession()
        ..workoutId = 1
        ..workoutName = 'AMRAP Test'
        ..workoutType = WorkoutType.amrap
        ..startedAt = DateTime.now()
        ..finishedAt = DateTime.now().add(const Duration(minutes: 15))
        ..completedRounds = 5
        ..totalRounds = 5
        ..isCompleted = true
        ..extraReps = 12
        ..rpe = 8
        ..note = 'Отличная тренировка, вес гири 16 кг';

      expect(session.rpe, equals(8));
      expect(session.completedRounds, equals(5));
      expect(session.extraReps, equals(12));
      expect(session.note, contains('вес гири 16 кг'));
    });
  });

  group('Equipment Matching Logic Tests', () {
    bool matchesEquipment(Workout w, String equipment) {
      if (equipment == 'Все') return true;
      final lowerEq = equipment.toLowerCase();
      final lowerTags = w.tags.map((t) => t.toLowerCase()).toList();
      final hasEquipmentInExercises = w.exercises.any((e) =>
          e.name.toLowerCase().contains(lowerEq) ||
          (e.description?.toLowerCase().contains(lowerEq) ?? false));

      if (lowerEq == 'без инвентаря') {
        final explicitNoEquip = lowerTags.any((t) => t.contains('без инвентар') || t.contains('свой вес'));
        if (explicitNoEquip) return true;
        final hasAnyEquipment = lowerTags.any((t) =>
            t.contains('гиря') ||
            t.contains('16') ||
            t.contains('6') ||
            t.contains('резин') ||
            t.contains('гантел') ||
            t.contains('штан') ||
            t.contains('петл') ||
            t.contains('турник') ||
            t.contains('брус'));
        return !hasAnyEquipment;
      }

      if (lowerEq == 'с инвентарём') {
        final explicitNoEquip = lowerTags.any((t) => t.contains('без инвентар') || t.contains('свой вес'));
        final hasAnyEquipment = lowerTags.any((t) =>
            t.contains('гиря') ||
            t.contains('16') ||
            t.contains('6') ||
            t.contains('резин') ||
            t.contains('гантел') ||
            t.contains('штан') ||
            t.contains('петл') ||
            t.contains('турник') ||
            t.contains('брус')) || hasEquipmentInExercises;
        if (explicitNoEquip && !hasAnyEquipment) return false;
        return hasAnyEquipment;
      }

      if (lowerEq == 'гиря 16 кг') {
        return lowerTags.any((t) => (t.contains('16') && (t.contains('кг') || t.contains('гир')))) ||
            w.exercises.any((e) => e.name.toLowerCase().contains('16') || (e.notes?.toLowerCase().contains('16') ?? false));
      }

      if (lowerEq == 'гиря 6 кг') {
        return lowerTags.any((t) => (t.contains('6') && (t.contains('кг') || t.contains('гир')))) ||
            w.exercises.any((e) => e.name.toLowerCase().contains('6') || (e.notes?.toLowerCase().contains('6') ?? false));
      }

      if (lowerEq == 'резинка') {
        return lowerTags.any((t) => t.contains('резин')) ||
            w.exercises.any((e) => e.name.toLowerCase().contains('резин') || (e.notes?.toLowerCase().contains('резин') ?? false));
      }

      return lowerTags.any((t) => t.contains(lowerEq)) || hasEquipmentInExercises;
    }

    test('matches equipment correctly', () {
      final kettlebellWorkout = Workout()
        ..name = 'Махи гирей'
        ..tags = ['16 кг', 'Кор']
        ..exercises = [Exercise()..name = 'Махи гири 16 кг'];

      final bodyweightWorkout = Workout()
        ..name = 'Отжимания и пресс'
        ..tags = ['Свой вес', 'Верх']
        ..exercises = [Exercise()..name = 'Отжимания'];

      final bandWorkout = Workout()
        ..name = 'Разводка с резиной'
        ..tags = ['Резинка', 'Плечи']
        ..exercises = [Exercise()..name = 'Тяга резинки'];

      expect(matchesEquipment(kettlebellWorkout, 'Все'), isTrue);
      expect(matchesEquipment(kettlebellWorkout, 'Гиря 16 кг'), isTrue);
      expect(matchesEquipment(kettlebellWorkout, 'С инвентарём'), isTrue);
      expect(matchesEquipment(kettlebellWorkout, 'Без инвентаря'), isFalse);
      expect(matchesEquipment(kettlebellWorkout, 'Резинка'), isFalse);

      expect(matchesEquipment(bodyweightWorkout, 'Без инвентаря'), isTrue);
      expect(matchesEquipment(bodyweightWorkout, 'С инвентарём'), isFalse);
      expect(matchesEquipment(bodyweightWorkout, 'Гиря 16 кг'), isFalse);

      expect(matchesEquipment(bandWorkout, 'Резинка'), isTrue);
      expect(matchesEquipment(bandWorkout, 'С инвентарём'), isTrue);
      expect(matchesEquipment(bandWorkout, 'Без инвентаря'), isFalse);
    });
  });

  group('Workout Sorting Tests', () {
    test('sorts by duration correctly', () {
      final shortW = Workout()
        ..name = 'Short'
        ..type = WorkoutType.tabata
        ..tabataWorkSeconds = 20
        ..tabataRestSeconds = 10
        ..tabataRounds = 4; // 120s

      final longW = Workout()
        ..name = 'Long'
        ..type = WorkoutType.tabata
        ..tabataWorkSeconds = 20
        ..tabataRestSeconds = 10
        ..tabataRounds = 8; // 240s

      final list = [shortW, longW];
      final sortedDesc = List<Workout>.from(list)..sort((a, b) => b.totalDurationSeconds.compareTo(a.totalDurationSeconds));
      expect(sortedDesc.first.name, equals('Long'));

      final sortedAsc = List<Workout>.from(list)..sort((a, b) => a.totalDurationSeconds.compareTo(b.totalDurationSeconds));
      expect(sortedAsc.first.name, equals('Short'));
    });

    test('sorts by equipment correctly (no_equipment_first and equipment_first)', () {
      final bw = Workout()
        ..name = 'Bodyweight'
        ..tags = ['Свой вес'];
      final equip = Workout()
        ..name = 'Kettlebell'
        ..tags = ['16 кг'];

      final list = [equip, bw];
      // no_equipment_first
      final noEquipFirst = List<Workout>.from(list)
        ..sort((a, b) {
          final ea = a.tags.contains('Свой вес') ? 0 : 1;
          final eb = b.tags.contains('Свой вес') ? 0 : 1;
          return ea.compareTo(eb);
        });
      expect(noEquipFirst.first.name, equals('Bodyweight'));

      // equipment_first
      final equipFirst = List<Workout>.from(list)
        ..sort((a, b) {
          final ea = a.tags.contains('Свой вес') ? 1 : 0;
          final eb = b.tags.contains('Свой вес') ? 1 : 0;
          return ea.compareTo(eb);
        });
      expect(equipFirst.first.name, equals('Kettlebell'));
    });
  });
}
