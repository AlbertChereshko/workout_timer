import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/workout.dart';

class WorkoutRepository {
  final Box<Workout> _box;

  WorkoutRepository(this._box);

  Box<Workout> get box => _box;

  List<Workout> getWorkouts() {
    return _box.values.toList();
  }

  Workout? getWorkout(dynamic key) {
    return _box.get(key);
  }

  Future<void> saveWorkout(Workout workout) async {
    if (workout.isInBox) {
      await workout.save();
    } else {
      await _box.add(workout);
    }
  }

  Future<void> deleteWorkout(dynamic keyOrWorkout) async {
    if (keyOrWorkout is Workout) {
      if (keyOrWorkout.isInBox) {
        await keyOrWorkout.delete();
        return;
      }
      if (keyOrWorkout.key != null) {
        await _box.delete(keyOrWorkout.key);
        return;
      }
    } else {
      await _box.delete(keyOrWorkout);
    }
  }
}

class WorkoutListNotifier extends StateNotifier<List<Workout>> {
  final WorkoutRepository _repo;
  StreamSubscription? _boxSubscription;

  WorkoutListNotifier(this._repo) : super(_repo.getWorkouts()) {
    _boxSubscription = _repo.box.watch().listen((_) {
      refresh();
    });
  }

  @override
  void dispose() {
    _boxSubscription?.cancel();
    super.dispose();
  }

  void refresh() {
    state = _repo.getWorkouts();
  }

  Future<void> saveWorkout(Workout workout) async {
    await _repo.saveWorkout(workout);
    state = _repo.getWorkouts();
  }

  Future<void> deleteWorkout(dynamic keyOrWorkout) async {
    await _repo.deleteWorkout(keyOrWorkout);
    state = _repo.getWorkouts();
  }
}

final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  return WorkoutRepository(Hive.box<Workout>('workouts'));
});

final workoutsNotifierProvider = StateNotifierProvider<WorkoutListNotifier, List<Workout>>((ref) {
  final repo = ref.watch(workoutRepositoryProvider);
  return WorkoutListNotifier(repo);
});

final workoutsProvider = Provider<List<Workout>>((ref) {
  return ref.watch(workoutsNotifierProvider);
});
