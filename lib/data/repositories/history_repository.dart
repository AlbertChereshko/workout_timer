import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/workout_session.dart';
import '../models/workout.dart';
import '../../services/widget_sync_service.dart';

class HistoryRepository {
  final Box<WorkoutSession> _box;

  HistoryRepository(this._box);

  List<WorkoutSession> getSessions() {
    final list = _box.values.toList();
    list.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return list;
  }

  Future<void> saveSession(WorkoutSession session) async {
    if (session.isInBox) {
      await session.save();
    } else {
      await _box.add(session);
    }
    _triggerWidgetSync();
  }

  Future<void> deleteSession(int key) async {
    await _box.delete(key);
    _triggerWidgetSync();
  }

  void _triggerWidgetSync() {
    try {
      final sessions = getSessions();
      List<Workout> workouts = [];
      if (Hive.isBoxOpen('workouts')) {
        workouts = Hive.box<Workout>('workouts').values.toList();
      }
      WidgetSyncService.syncAll(sessions: sessions, workouts: workouts);
    } catch (_) {}
  }
}

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  return HistoryRepository(Hive.box<WorkoutSession>('sessions'));
});
