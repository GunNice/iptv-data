// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'watched_progress_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WatchedProgressAdapter extends TypeAdapter<WatchedProgress> {
  @override
  final int typeId = 4;

  @override
  WatchedProgress read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WatchedProgress(
      position: fields[0] as int,
      duration: fields[1] as int,
      isFinished: fields[2] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, WatchedProgress obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.position)
      ..writeByte(1)
      ..write(obj.duration)
      ..writeByte(2)
      ..write(obj.isFinished);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WatchedProgressAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
