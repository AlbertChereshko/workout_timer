import 'package:hive_flutter/hive_flutter.dart';

part 'workout.g.dart';

@HiveType(typeId: 1)
enum WorkoutType {
  @HiveField(0)
  emom,
  @HiveField(1)
  tabata,
  @HiveField(2)
  amrap,
}

@HiveType(typeId: 0)
class Workout extends HiveObject {
  Workout();

  @HiveField(0)
  String name = '';

  @HiveField(1)
  WorkoutType type = WorkoutType.tabata;

  @HiveField(2)
  int emomRounds = 10;

  @HiveField(3)
  int emomRoundDurationSeconds = 60;

  @HiveField(4)
  int tabataWorkSeconds = 20;

  @HiveField(5)
  int tabataRestSeconds = 10;

  @HiveField(6)
  int tabataRounds = 8;

  @HiveField(7)
  DateTime createdAt = DateTime.now();

  @HiveField(8)
  List<Exercise> exercises = [];

  @HiveField(9)
  List<String> tags = [];

  @HiveField(10)
  int amrapDurationSeconds = 900;

  @HiveField(11)
  bool amrapCountByRounds = true;

  @HiveField(12)
  String? videoUrl;

  Workout cloneWithName(String newName) {
    final copy = Workout()
      ..name = newName
      ..type = type
      ..emomRounds = emomRounds
      ..emomRoundDurationSeconds = emomRoundDurationSeconds
      ..tabataWorkSeconds = tabataWorkSeconds
      ..tabataRestSeconds = tabataRestSeconds
      ..tabataRounds = tabataRounds
      ..amrapDurationSeconds = amrapDurationSeconds
      ..amrapCountByRounds = amrapCountByRounds
      ..videoUrl = videoUrl
      ..createdAt = DateTime.now()
      ..tags = List<String>.from(tags)
      ..exercises = exercises
          .map((e) => Exercise()
            ..name = e.name
            ..description = e.description
            ..reps = e.reps
            ..durationSeconds = e.durationSeconds
            ..videoUrl = e.videoUrl
            ..notes = e.notes)
          .toList();
    return copy;
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type.name,
      'emomRounds': emomRounds,
      'emomRoundDurationSeconds': emomRoundDurationSeconds,
      'tabataWorkSeconds': tabataWorkSeconds,
      'tabataRestSeconds': tabataRestSeconds,
      'tabataRounds': tabataRounds,
      'amrapDurationSeconds': amrapDurationSeconds,
      'amrapCountByRounds': amrapCountByRounds,
      'videoUrl': videoUrl,
      'tags': tags,
      'exercises': exercises.map((e) => e.toJson()).toList(),
    };
  }

  factory Workout.fromJson(Map<String, dynamic> json) {
    final w = Workout()
      ..name = json['name'] as String? ?? 'Тренировка'
      ..type = WorkoutType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => WorkoutType.tabata,
      )
      ..emomRounds = json['emomRounds'] as int? ?? 10
      ..emomRoundDurationSeconds = json['emomRoundDurationSeconds'] as int? ?? 60
      ..tabataWorkSeconds = json['tabataWorkSeconds'] as int? ?? 20
      ..tabataRestSeconds = json['tabataRestSeconds'] as int? ?? 10
      ..tabataRounds = json['tabataRounds'] as int? ?? 8
      ..amrapDurationSeconds = json['amrapDurationSeconds'] as int? ?? 900
      ..amrapCountByRounds = json['amrapCountByRounds'] as bool? ?? true
      ..videoUrl = json['videoUrl'] as String?
      ..createdAt = DateTime.now()
      ..tags = (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? []
      ..exercises = (json['exercises'] as List?)
              ?.map((e) => Exercise.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [];
    return w;
  }
}

@HiveType(typeId: 2)
class Exercise extends HiveObject {
  Exercise();

  @HiveField(0)
  String name = '';

  @HiveField(1)
  String? description;

  @HiveField(2)
  int? reps;

  @HiveField(3)
  int? durationSeconds;

  @HiveField(4)
  String? videoUrl;

  @HiveField(5)
  String? notes;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (description != null) 'description': description,
      if (reps != null) 'reps': reps,
      if (durationSeconds != null) 'durationSeconds': durationSeconds,
      if (videoUrl != null) 'videoUrl': videoUrl,
      if (notes != null) 'notes': notes,
    };
  }

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise()
      ..name = json['name'] as String? ?? ''
      ..description = json['description'] as String?
      ..reps = json['reps'] as int?
      ..durationSeconds = json['durationSeconds'] as int?
      ..videoUrl = json['videoUrl'] as String?
      ..notes = json['notes'] as String?;
  }
}

extension WorkoutDurationExtension on Workout {
  int get totalDurationSeconds {
    if (type == WorkoutType.amrap) {
      return amrapDurationSeconds;
    } else if (type == WorkoutType.emom) {
      if (exercises.isNotEmpty) {
        int sumPerCircuit = 0;
        for (final e in exercises) {
          sumPerCircuit += (e.durationSeconds ?? emomRoundDurationSeconds);
        }
        final circuits = (emomRounds / exercises.length).ceil();
        return sumPerCircuit * (circuits > 0 ? circuits : 1);
      } else {
        return emomRounds * emomRoundDurationSeconds;
      }
    } else {
      if (exercises.isNotEmpty) {
        int sumPerCircuit = 0;
        for (final e in exercises) {
          sumPerCircuit += (e.durationSeconds ?? tabataWorkSeconds) + tabataRestSeconds;
        }
        final circuits = (tabataRounds / exercises.length).ceil();
        return sumPerCircuit * (circuits > 0 ? circuits : 1);
      } else {
        return tabataRounds * (tabataWorkSeconds + tabataRestSeconds);
      }
    }
  }

  String formatTotalDuration([String? minShort, String? secShort]) {
    return formatSeconds(totalDurationSeconds, minShort: minShort, secShort: secShort);
  }

  static String formatSeconds(int totalSecs, {String? minShort, String? secShort}) {
    final mLabel = minShort ?? 'мин';
    final sLabel = secShort ?? 'сек';
    if (totalSecs <= 0) return '0 $sLabel';
    if (totalSecs < 60) return '$totalSecs $sLabel';
    final hours = totalSecs ~/ 3600;
    final mins = (totalSecs % 3600) ~/ 60;
    final secs = totalSecs % 60;
    if (hours > 0) {
      if (mins == 0 && secs == 0) return '$hours ч';
      if (secs == 0) return '$hours ч $mins $mLabel';
      return '$hours ч $minsм $secsс';
    }
    if (secs == 0) return '$mins $mLabel';
    return '$minsм $secsс';
  }
}
