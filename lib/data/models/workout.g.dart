// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WorkoutAdapter extends TypeAdapter<Workout> {
  @override
  final int typeId = 0;

  @override
  Workout read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Workout()
      ..name = fields[0] as String
      ..type = fields[1] as WorkoutType
      ..emomRounds = fields[2] as int
      ..emomRoundDurationSeconds = fields[3] as int
      ..tabataWorkSeconds = fields[4] as int
      ..tabataRestSeconds = fields[5] as int
      ..tabataRounds = fields[6] as int
      ..createdAt = fields[7] as DateTime
      ..exercises = (fields[8] as List).cast<Exercise>()
      ..tags = (fields[9] as List).cast<String>()
      ..amrapDurationSeconds = (fields[10] as int?) ?? 900
      ..amrapCountByRounds = (fields[11] as bool?) ?? true
      ..videoUrl = fields[12] as String?;
  }

  @override
  void write(BinaryWriter writer, Workout obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.emomRounds)
      ..writeByte(3)
      ..write(obj.emomRoundDurationSeconds)
      ..writeByte(4)
      ..write(obj.tabataWorkSeconds)
      ..writeByte(5)
      ..write(obj.tabataRestSeconds)
      ..writeByte(6)
      ..write(obj.tabataRounds)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.exercises)
      ..writeByte(9)
      ..write(obj.tags)
      ..writeByte(10)
      ..write(obj.amrapDurationSeconds)
      ..writeByte(11)
      ..write(obj.amrapCountByRounds)
      ..writeByte(12)
      ..write(obj.videoUrl);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ExerciseAdapter extends TypeAdapter<Exercise> {
  @override
  final int typeId = 2;

  @override
  Exercise read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Exercise()
      ..name = fields[0] as String
      ..description = fields[1] as String?
      ..reps = fields[2] as int?
      ..durationSeconds = fields[3] as int?
      ..videoUrl = fields[4] as String?
      ..notes = fields[5] as String?;
  }

  @override
  void write(BinaryWriter writer, Exercise obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.description)
      ..writeByte(2)
      ..write(obj.reps)
      ..writeByte(3)
      ..write(obj.durationSeconds)
      ..writeByte(4)
      ..write(obj.videoUrl)
      ..writeByte(5)
      ..write(obj.notes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExerciseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class WorkoutTypeAdapter extends TypeAdapter<WorkoutType> {
  @override
  final int typeId = 1;

  @override
  WorkoutType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return WorkoutType.emom;
      case 1:
        return WorkoutType.tabata;
      case 2:
        return WorkoutType.amrap;
      default:
        return WorkoutType.emom;
    }
  }

  @override
  void write(BinaryWriter writer, WorkoutType obj) {
    switch (obj) {
      case WorkoutType.emom:
        writer.writeByte(0);
        break;
      case WorkoutType.tabata:
        writer.writeByte(1);
        break;
      case WorkoutType.amrap:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
