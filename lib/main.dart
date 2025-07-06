// lib/main.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'models/channel_model.dart';
import 'models/movie_model.dart';
import 'models/series_model.dart';
import 'models/category_model.dart'; // A importação principal já estava aqui
import 'providers/theme_provider.dart';
import 'screens/splash_screen.dart';
import 'models/watched_progress_model.dart'; // <-- Adicione esta linha
import 'models/league_model.dart'; // <-- Adicione esta linha

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  // Registra os adaptadores
  Hive.registerAdapter(ChannelAdapter());
  Hive.registerAdapter(MovieAdapter());
  Hive.registerAdapter(SeriesAdapter());
  Hive.registerAdapter(CategoryAdapter()); // Este agora será encontrado
  Hive.registerAdapter(WatchedProgressAdapter());
  Hive.registerAdapter(LeagueAdapter()); // <-- Adicione esta linha

  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isLightTheme = themeProvider.currentAppTheme.name == 'Branco';
        final textColor = isLightTheme ? Colors.black87 : Colors.white;

        return MaterialApp(
          title: 'IPTV Concept',
          debugShowCheckedModeBanner: false,
          theme: themeProvider.currentMaterialTheme.copyWith(
            textTheme: GoogleFonts.poppinsTextTheme(
              Theme.of(context).textTheme.apply(bodyColor: textColor),
            ),
          ),
          home: const SplashScreen(),
        );
      },
    );
  }
}
