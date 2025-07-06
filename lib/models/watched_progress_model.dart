// lib/models/watched_progress_model.dart

import 'package:hive/hive.dart';

part 'watched_progress_model.g.dart'; // O build_runner vai criar este arquivo

@HiveType(typeId: 4) // ID do tipo DEVE ser único
class WatchedProgress extends HiveObject {
  @HiveField(0)
  int position; // Posição assistida em segundos

  @HiveField(1)
  int duration; // Duração total em segundos

  @HiveField(2)
  bool isFinished;

  WatchedProgress({
    required this.position,
    required this.duration,
    this.isFinished = false,
  });
}
