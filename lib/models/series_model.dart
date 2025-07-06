// lib/models/series_model.dart

import 'package:hive/hive.dart';

part 'series_model.g.dart';

@HiveType(typeId: 2) // ID do tipo DEVE ser diferente dos outros
class Series {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final String cover; // Poster

  @HiveField(2)
  final int seriesId;

  @HiveField(3)
  final String categoryId;

  Series({
    required this.name,
    required this.cover,
    required this.seriesId,
    required this.categoryId,
  });
}
