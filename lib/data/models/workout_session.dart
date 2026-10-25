import 'package:hive_flutter/hive_flutter.dart';
import 'workout.dart';

part 'workout_session.g.dart';

@HiveType(typeId: 3)
class WorkoutSession extends HiveObject {
  @HiveField(0)
  late int workoutId;

  @HiveField(1)
  late String workoutName;

  @HiveField(2)
  late WorkoutType workoutType;

  @HiveField(3)
  late DateTime startedAt;

  @HiveField(4)
  DateTime? finishedAt;

  @HiveField(5)
  int completedRounds = 0;

  @HiveField(6)
  int totalRounds = 0;

  @HiveField(7)
  bool isCompleted = false;

  @HiveField(8)
  String? note;

  @HiveField(9)
  List<String> tags = [];

  @HiveField(10)
  List<String> exerciseSnapshots = [];

  @HiveField(11)
  int extraReps = 0;
}
