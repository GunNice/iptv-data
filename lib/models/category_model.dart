// lib/models/category_model.dart

import 'package:hive/hive.dart';

part 'category_model.g.dart';

@HiveType(typeId: 3)
class Category extends HiveObject {
  @HiveField(0)
  final String categoryId;

  @HiveField(1)
  final String categoryName; // O nome original, como "CANAIS | ESPN"

  Category({required this.categoryId, required this.categoryName});

  // "COLUNA VIRTUAL" QUE VOCÊ SUGERIU:
  // Um getter que limpa e agrupa o nome para exibição.
  String get displayName {
    // 1. Remove o prefixo (ex: "CANAIS | ")
    String cleanedName = categoryName.split('|').last.trim();

    // 2. Remove números e caracteres especiais no final para agrupar
    cleanedName = cleanedName
        .replaceAll(RegExp(r'[\s\d¹²³⁴⁵⁶⁷⁸⁹]+$'), '')
        .trim();

    return cleanedName.isEmpty ? "Geral" : cleanedName;
  }
}
