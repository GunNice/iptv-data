// lib/models/league_model.dart

import 'package:hive/hive.dart';

part 'league_model.g.dart';

@HiveType(typeId: 5)
class League extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String logoUrl;

  @HiveField(3)
  final String sport;

  League({
    required this.id,
    required this.name,
    required this.logoUrl,
    required this.sport,
  });

  factory League.fromJson(Map<String, dynamic> json) {
    return League(
      id: json['idLeague'] ?? '0',
      name: json['strLeague'] ?? 'Liga Desconhecida',
      // CORREÇÃO: Se o logo for nulo, salvamos como uma string vazia.
      logoUrl: json['strBadge'] ?? '',
      sport: json['strSport'] ?? 'Unknown',
    );
  }
}
