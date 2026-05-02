// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ebook.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LocalEbookAdapter extends TypeAdapter<LocalEbook> {
  @override
  final int typeId = 0;

  @override
  LocalEbook read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LocalEbook(
      id: fields[0] as String,
      title: fields[1] as String,
      coverUrl: fields[2] as String?,
      authorId: fields[3] as String,
      localFilePath: fields[4] as String,
      price: fields[5] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, LocalEbook obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.coverUrl)
      ..writeByte(3)
      ..write(obj.authorId)
      ..writeByte(4)
      ..write(obj.localFilePath)
      ..writeByte(5)
      ..write(obj.price);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalEbookAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
