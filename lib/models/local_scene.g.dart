// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_scene.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LocalSceneAdapter extends TypeAdapter<LocalScene> {
  @override
  final int typeId = 1;

  @override
  LocalScene read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LocalScene(
      ebookId: fields[0] as String,
      ord: fields[1] as int,
      text: fields[2] as String?,
      imageUrl: fields[3] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, LocalScene obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.ebookId)
      ..writeByte(1)
      ..write(obj.ord)
      ..writeByte(2)
      ..write(obj.text)
      ..writeByte(3)
      ..write(obj.imageUrl);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalSceneAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
