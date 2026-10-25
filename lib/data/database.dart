import 'package:hive_flutter/hive_flutter.dart';
import 'models/workout.dart';
import 'models/workout_session.dart';

Future<void> initDatabase() async {
  await Hive.initFlutter();
  
  Hive.registerAdapter(WorkoutTypeAdapter());
  Hive.registerAdapter(WorkoutAdapter());
  Hive.registerAdapter(ExerciseAdapter());
  Hive.registerAdapter(WorkoutSessionAdapter());

  final workoutsBox = await Hive.openBox<Workout>('workouts');
  final sessionsBox = await Hive.openBox<WorkoutSession>('sessions');
  await Hive.openBox('settings');

  // One-time tag migration
  for (final w in workoutsBox.values) {
    bool changed = false;
    final updated = w.tags.map((t) {
      if (t == 'Верх тела') { changed = true; return 'Верх'; }
      if (t == 'Низ тела') { changed = true; return 'Низ'; }
      if (t == 'ВИТ на всё тело') { changed = true; return 'ВИТ'; }
      return t;
    }).toList();
    if (changed) {
      w.tags = updated;
      await w.save();
    }
  }

  for (final s in sessionsBox.values) {
    bool changed = false;
    final updated = s.tags.map((t) {
      if (t == 'Верх тела') { changed = true; return 'Верх'; }
      if (t == 'Низ тела') { changed = true; return 'Низ'; }
      if (t == 'ВИТ на всё тело') { changed = true; return 'ВИТ'; }
      return t;
    }).toList();
    if (changed) {
      s.tags = updated;
      await s.save();
    }
  }
}
