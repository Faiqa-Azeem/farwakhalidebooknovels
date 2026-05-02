import 'package:hive/hive.dart';

part 'local_scene.g.dart';

@HiveType(typeId: 1) // ✅ unique ID (change if already used)
class LocalScene extends HiveObject {
  @HiveField(0)
  String ebookId;

  @HiveField(1)
  int ord;

  @HiveField(2)
  String? text;

  @HiveField(3)
  String? imageUrl;

  LocalScene({
    required this.ebookId,
    required this.ord,
    this.text,
    this.imageUrl,
  });
}
