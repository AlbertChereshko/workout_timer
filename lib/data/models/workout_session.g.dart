// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_session.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WorkoutSessionAdapter extends TypeAdapter<WorkoutSession> {
  @override
  final int typeId = 3;

  @override
  WorkoutSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WorkoutSession()
      ..workoutId = fields[0] as int
      ..workoutName = fields[1] as String
      ..workoutType = fields[2] as WorkoutType
      ..startedAt = fields[3] as DateTime
      ..finishedAt = fields[4] as DateTime?
      ..completedRounds = fields[5] as int
      ..totalRounds = fields[6] as int
      ..isCompleted = fields[7] as bool
      ..note = fields[8] as String?
      ..tags = (fields[9] as List).cast<String>()
      ..exerciseSnapshots = fields[10] != null ? (fields[10] as List).cast<String>() : <String>[]
      ..extraReps = (fields[11] as int?) ?? 0;
  }

  @override
  void write(BinaryWriter writer, WorkoutSession obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.workoutId)
      ..writeByte(1)
      ..write(obj.workoutName)
      ..writeByte(2)
      ..write(obj.workoutType)
      ..writeByte(3)
      ..write(obj.startedAt)
      ..writeByte(4)
      ..write(obj.finishedAt)
      ..writeByte(5)
      ..write(obj.completedRounds)
      ..writeByte(6)
      ..write(obj.totalRounds)
      ..writeByte(7)
      ..write(obj.isCompleted)
      ..writeByte(8)
      ..write(obj.note)
      ..writeByte(9)
      ..write(obj.tags)
      ..writeByte(10)
      ..write(obj.exerciseSnapshots)
      ..writeByte(11)
      ..write(obj.extraReps);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
