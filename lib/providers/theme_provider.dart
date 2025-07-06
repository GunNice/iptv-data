// lib/providers/theme_provider.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 1. Classe para guardar a paleta de cores de cada tema
class AppThemeData {
  final String name;
  final Color primaryColor;
  final List<Color> gradientColors;
  final Color glassColor;
  final Color? accentColorForCircle; // Opcional para o círculo do tema 'Brasil'

  AppThemeData({
    required this.name,
    required this.primaryColor,
    required this.gradientColors,
    required this.glassColor,
    this.accentColorForCircle,
  });
}

// 2. Provedor de Tema atualizado
class ThemeProvider with ChangeNotifier {
  int _selectedThemeIndex = 6; // Começa com o tema Dark

  // Lista com as paletas de cores completas para cada tema
  static final List<AppThemeData> appThemes = [
    // 0: Azul
    AppThemeData(
      name: 'Azul',
      primaryColor: Colors.lightBlueAccent,
      gradientColors: [const Color(0xFF005C97), const Color(0xFF363795)],
      glassColor: Colors.lightBlue.withAlpha((255 * 0.1).round()),
    ),
    // 1: Verde
    AppThemeData(
      name: 'Verde',
      primaryColor: Colors.greenAccent,
      gradientColors: [const Color(0xFF134E5E), const Color(0xFF71B280)],
      glassColor: Colors.green.withAlpha((255 * 0.1).round()),
    ),
    // 2: Vermelho
    AppThemeData(
      name: 'Vermelho',
      primaryColor: Colors.redAccent,
      gradientColors: [const Color(0xFF4B0000), const Color(0xFFD31027)],
      glassColor: Colors.red.withAlpha((255 * 0.1).round()),
    ),
    // 3: Amarelo
    AppThemeData(
      name: 'Amarelo',
      primaryColor: Colors.amberAccent,
      gradientColors: [const Color(0xFF544200), const Color(0xFFF7971E)],
      glassColor: Colors.amber.withAlpha((255 * 0.1).round()),
    ),
    // 4: Brasil
    AppThemeData(
      name: 'Brasil',
      primaryColor: Colors.yellowAccent,
      gradientColors: [const Color(0xFF004D00), const Color(0xFFF7DD43)],
      glassColor: Colors.green.withAlpha((255 * 0.15).round()),
      accentColorForCircle:
          Colors.yellow, // Para o gradiente no círculo de seleção
    ),
    // 5: Branco
    AppThemeData(
      name: 'Branco',
      primaryColor: Colors.black, // Cor de destaque para o tema branco
      gradientColors: [const Color(0xFFE0EAFC), const Color(0xFFCFDEF3)],
      glassColor: Colors.white.withAlpha((255 * 0.2).round()),
    ),
    // 6: Dark (Original)
    AppThemeData(
      name: 'Dark',
      primaryColor: const Color(0xFF6A11CB),
      gradientColors: [
        const Color(0xFF0F0C29),
        const Color(0xFF302B63),
        const Color(0xFF24243E),
      ],
      glassColor: Colors.black.withAlpha((255 * 0.25).round()),
    ),
  ];

  // Getters para acessar facilmente as cores do tema atual
  AppThemeData get currentAppTheme => appThemes[_selectedThemeIndex];
  List<Color> get currentGradient => currentAppTheme.gradientColors;
  Color get currentGlassColor => currentAppTheme.glassColor;

  // Getter para o ThemeData do Material, usado pelo MaterialApp
  ThemeData get currentMaterialTheme {
    final theme = currentAppTheme;
    final isLightTheme = theme.name == 'Branco';

    return ThemeData(
      brightness: isLightTheme ? Brightness.light : Brightness.dark,
      primaryColor: theme.primaryColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: theme.primaryColor,
        brightness: isLightTheme ? Brightness.light : Brightness.dark,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.primaryColor,
          foregroundColor: isLightTheme ? Colors.white : Colors.black,
        ),
      ),
      useMaterial3: true,
    );
  }

  int get selectedThemeIndex => _selectedThemeIndex;

  ThemeProvider() {
    loadTheme();
  }

  void setTheme(int themeIndex) async {
    _selectedThemeIndex = themeIndex;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('theme_index', themeIndex);
  }

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedThemeIndex =
        prefs.getInt('theme_index') ?? 6; // Padrão para o tema Dark
    notifyListeners();
  }
}
