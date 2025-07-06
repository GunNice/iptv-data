// lib/models/channel_model.dart

import 'package:hive/hive.dart';

part 'channel_model.g.dart'; // Esta linha vai dar erro até gerarmos o arquivo

@HiveType(typeId: 0) // Identificador único para a classe
class Channel {
  @HiveField(0) // Identificador único para o campo
  final String name;

  @HiveField(1)
  final String logoUrl;

  @HiveField(2)
  final String videoUrl;

  @HiveField(3)
  final String category;

  Channel({
    required this.name,
    required this.logoUrl,
    required this.videoUrl,
    required this.category,
  });
}
