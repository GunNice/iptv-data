// lib/models/movie_model.dart

import 'package:hive/hive.dart';

part 'movie_model.g.dart';

@HiveType(typeId: 1) // ID do tipo DEVE ser diferente do Channel
class Movie {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final String icon; // Poster

  @HiveField(2)
  final int streamId;

  @HiveField(3)
  final String categoryId;

  Movie({
    required this.name,
    required this.icon,
    required this.streamId,
    required this.categoryId,
  });
}
