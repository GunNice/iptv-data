// lib/screens/splash_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToHome();
  }

  void _navigateToHome() async {
    // Espera o primeiro frame ser desenhado para garantir que o tema foi carregado
    await Future.delayed(const Duration(milliseconds: 50));

    // Simula um tempo de carregamento
    await Future.delayed(const Duration(seconds: 3));

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Usamos o Consumer para pegar o tema assim que ele estiver disponível
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: themeProvider.currentGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    width: 800,
                  ), // Ajuste a largura como desejar
                  //const Icon(
                  //  Icons.tv_rounded,
                  //  size: 120,
                  //   color: Colors.white70,
                  // ),
                  //const SizedBox(height: 20),
                  // Text(
                  // 'IPTV Concept',
                  //style: TextStyle(
                  //  fontSize: 24,
                  // fontWeight: FontWeight.bold,
                  // color: Colors.white.withAlpha(200),
                  //),
                  // ),
                  const SizedBox(height: 40),
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      themeProvider.currentAppTheme.primaryColor.withAlpha(150),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
