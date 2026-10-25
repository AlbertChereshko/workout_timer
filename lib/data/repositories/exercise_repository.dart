import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/exercise_library.dart';

class ExerciseRepository {
  static const String _boxName = 'settings';
  static const String _customExercisesKey = 'custom_user_exercises';
  static const String _customBaseOnlyKey = 'custom_base_only';

  /// Returns whether user has opted to completely replace or clear the built-in catalog
  bool isCustomBaseOnly() {
    try {
      if (Hive.isBoxOpen(_boxName)) {
        return Hive.box(_boxName).get(_customBaseOnlyKey, defaultValue: false) == true;
      }
    } catch (_) {}
    return false;
  }

  /// Returns all available exercises: built-in catalog + custom user exercises.
  /// Overrides of built-in catalog exercises replace the catalog entry in place,
  /// preserving order.
  List<ExerciseDefinition> getAllExercises() {
    final bool customOnly = isCustomBaseOnly();
    final map = <String, ExerciseDefinition>{};

    if (!customOnly) {
      for (final e in ExerciseLibrary.catalog) {
        map[e.id] = e;
      }
    }

    try {
      if (Hive.isBoxOpen(_boxName)) {
        final box = Hive.box(_boxName);
        final raw = box.get(_customExercisesKey);
        if (raw is List) {
          for (final item in raw) {
            if (item is String) {
              final json = jsonDecode(item) as Map<String, dynamic>;
              final def = _fromJson(json);
              map[def.id] = def;
            }
          }
        }
      }
    } catch (_) {}
    return map.values.toList();
  }

  /// Returns only user-created custom or overridden exercises from storage
  List<ExerciseDefinition> getCustomExercises() {
    final list = <ExerciseDefinition>[];
    try {
      if (Hive.isBoxOpen(_boxName)) {
        final box = Hive.box(_boxName);
        final raw = box.get(_customExercisesKey);
        if (raw is List) {
          for (final item in raw) {
            if (item is String) {
              final map = jsonDecode(item) as Map<String, dynamic>;
              list.add(_fromJson(map));
            }
          }
        }
      }
    } catch (_) {}
    return list;
  }

  /// Checks if an exercise is user-created (not part of original built-in catalog)
  bool isCustom(String id) {
    return !ExerciseLibrary.catalog.any((e) => e.id == id);
  }

  /// Checks if a built-in exercise has been modified/overridden by the user
  bool isOverridden(String id) {
    if (isCustom(id)) return false;
    final customList = getCustomExercises();
    return customList.any((e) => e.id == id);
  }

  /// Adds or updates an exercise (works for both custom exercises and built-in overrides)
  Future<void> saveExercise(ExerciseDefinition exercise) async {
    final box = Hive.box(_boxName);
    final current = getCustomExercises();
    final withTimestamp = ExerciseDefinition(
      id: exercise.id,
      name: exercise.name,
      description: exercise.description,
      targetMuscle: exercise.targetMuscle,
      subgroup: exercise.subgroup,
      isStatic: exercise.isStatic,
      defaultDurationSeconds: exercise.defaultDurationSeconds,
      defaultReps: exercise.defaultReps,
      equipment: exercise.equipment,
      difficulty: exercise.difficulty,
      tags: exercise.tags,
      videoUrl: exercise.videoUrl,
      notes: exercise.notes,
      updatedAt: exercise.updatedAt ?? DateTime.now(),
    );

    final idx = current.indexWhere((e) => e.id == withTimestamp.id);
    if (idx >= 0) {
      current[idx] = withTimestamp;
    } else {
      current.add(withTimestamp);
    }

    final rawList = current.map((e) => jsonEncode(_toJson(e))).toList();
    await box.put(_customExercisesKey, rawList);
  }

  /// Bulk saves or updates a list of exercises (merges into current database)
  Future<void> bulkSaveExercises(List<ExerciseDefinition> exercises) async {
    final box = Hive.box(_boxName);
    final current = getCustomExercises();
    final now = DateTime.now();

    for (final ex in exercises) {
      final withTimestamp = ExerciseDefinition(
        id: ex.id,
        name: ex.name,
        description: ex.description,
        targetMuscle: ex.targetMuscle,
        subgroup: ex.subgroup,
        isStatic: ex.isStatic,
        defaultDurationSeconds: ex.defaultDurationSeconds,
        defaultReps: ex.defaultReps,
        equipment: ex.equipment,
        difficulty: ex.difficulty,
        tags: ex.tags,
        videoUrl: ex.videoUrl,
        notes: ex.notes,
        updatedAt: ex.updatedAt ?? now,
      );
      final idx = current.indexWhere((e) => e.id == withTimestamp.id);
      if (idx >= 0) {
        current[idx] = withTimestamp;
      } else {
        current.add(withTimestamp);
      }
    }

    final rawList = current.map((e) => jsonEncode(_toJson(e))).toList();
    await box.put(_customExercisesKey, rawList);
  }

  /// Replaces the entire exercise database with only the given list of exercises
  Future<void> replaceAllExercises(List<ExerciseDefinition> exercises) async {
    final box = Hive.box(_boxName);
    await box.put(_customBaseOnlyKey, true);
    final now = DateTime.now();
    final toSave = exercises.map((ex) {
      return ExerciseDefinition(
        id: ex.id,
        name: ex.name,
        description: ex.description,
        targetMuscle: ex.targetMuscle,
        subgroup: ex.subgroup,
        isStatic: ex.isStatic,
        defaultDurationSeconds: ex.defaultDurationSeconds,
        defaultReps: ex.defaultReps,
        equipment: ex.equipment,
        difficulty: ex.difficulty,
        tags: ex.tags,
        videoUrl: ex.videoUrl,
        notes: ex.notes,
        updatedAt: ex.updatedAt ?? now,
      );
    }).toList();

    final rawList = toSave.map((e) => jsonEncode(_toJson(e))).toList();
    await box.put(_customExercisesKey, rawList);
  }

  /// Completely clears all exercises from the database
  Future<void> clearAllExercises() async {
    final box = Hive.box(_boxName);
    await box.put(_customBaseOnlyKey, true);
    await box.put(_customExercisesKey, <String>[]);
  }

  /// Restores the default built-in catalog (36 exercises)
  Future<void> restoreDefaultCatalog() async {
    final box = Hive.box(_boxName);
    await box.put(_customBaseOnlyKey, false);
    await box.put(_customExercisesKey, <String>[]);
  }

  /// Deletes a custom exercise or resets an overridden built-in exercise back to default
  Future<void> deleteExercise(String id) async {
    final box = Hive.box(_boxName);
    final current = getCustomExercises();
    current.removeWhere((e) => e.id == id);
    final rawList = current.map((e) => jsonEncode(_toJson(e))).toList();
    await box.put(_customExercisesKey, rawList);
  }

  Map<String, dynamic> _toJson(ExerciseDefinition e) {
    return {
      'id': e.id,
      'name': e.name,
      'description': e.description,
      'targetMuscle': e.targetMuscle.name,
      'subgroup': e.subgroup?.name,
      'isStatic': e.isStatic,
      'defaultDurationSeconds': e.defaultDurationSeconds,
      'defaultReps': e.defaultReps,
      'equipment': e.equipment.name,
      'difficulty': e.difficulty.name,
      'tags': e.tags,
      'videoUrl': e.videoUrl,
      'notes': e.notes,
      'updatedAt': e.updatedAt?.toIso8601String(),
    };
  }

  ExerciseDefinition _fromJson(Map<String, dynamic> map) {
    return ExerciseDefinition.fromJson(map);
  }
}

class ExerciseListNotifier extends StateNotifier<List<ExerciseDefinition>> {
  final ExerciseRepository _repo;

  ExerciseListNotifier(this._repo) : super(_repo.getAllExercises());

  void refresh() {
    state = _repo.getAllExercises();
  }

  Future<void> saveExercise(ExerciseDefinition exercise) async {
    await _repo.saveExercise(exercise);
    state = _repo.getAllExercises();
  }

  Future<void> bulkSaveExercises(List<ExerciseDefinition> exercises) async {
    await _repo.bulkSaveExercises(exercises);
    state = _repo.getAllExercises();
  }

  Future<void> replaceAll(List<ExerciseDefinition> exercises) async {
    await _repo.replaceAllExercises(exercises);
    state = _repo.getAllExercises();
  }

  Future<void> clearAll() async {
    await _repo.clearAllExercises();
    state = _repo.getAllExercises();
  }

  Future<void> restoreDefaultCatalog() async {
    await _repo.restoreDefaultCatalog();
    state = _repo.getAllExercises();
  }

  Future<void> deleteExercise(String id) async {
    await _repo.deleteExercise(id);
    state = _repo.getAllExercises();
  }
}

final exerciseRepositoryProvider = Provider<ExerciseRepository>((ref) {
  return ExerciseRepository();
});

final allExercisesProvider = StateNotifierProvider<ExerciseListNotifier, List<ExerciseDefinition>>((ref) {
  final repo = ref.watch(exerciseRepositoryProvider);
  return ExerciseListNotifier(repo);
});
