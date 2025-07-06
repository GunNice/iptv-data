// lib/screens/manage_leagues_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import '../models/league_model.dart';
import '../providers/theme_provider.dart';
import '../services/football_service.dart';

class ManageLeaguesScreen extends StatefulWidget {
  const ManageLeaguesScreen({super.key});

  @override
  State<ManageLeaguesScreen> createState() => _ManageLeaguesScreenState();
}

class _ManageLeaguesScreenState extends State<ManageLeaguesScreen> {
  final FootballService footballService = FootballService();

  List<League> _visibleLeagues = [];
  List<League> _hiddenLeagues = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLeagues();
  }

  Future<void> _loadLeagues() async {
    final allLeagues = await footballService.getLeaguesForManagement();
    final settingsBox = await Hive.openBox(footballSettingsBoxName);

    List<String> order = List<String>.from(
      settingsBox.get('league_order') ?? [],
    );
    List<String> hidden = List<String>.from(
      settingsBox.get('hidden_leagues') ?? [],
    );

    List<League> tempVisible = [];
    List<League> tempHidden = [];

    if (order.isEmpty) {
      order = allLeagues.map((l) => l.id).toList();
    }

    Map<String, League> allLeaguesMap = {for (var l in allLeagues) l.id: l};

    for (var id in order) {
      final league = allLeaguesMap[id];
      if (league != null) {
        if (hidden.contains(id)) {
          tempHidden.add(league);
        } else {
          tempVisible.add(league);
        }
      }
    }

    setState(() {
      _visibleLeagues = tempVisible;
      _hiddenLeagues = tempHidden;
      _isLoading = false;
    });
  }

  void _savePreferences() async {
    final settingsBox = await Hive.openBox(footballSettingsBoxName);

    final order =
        _visibleLeagues.map((l) => l.id).toList() +
        _hiddenLeagues.map((l) => l.id).toList();
    final hidden = _hiddenLeagues.map((l) => l.id).toList();

    await settingsBox.put('league_order', order);
    await settingsBox.put('hidden_leagues', hidden);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Preferências salvas!'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Gerenciar Campeonatos', style: GoogleFonts.poppins()),
        backgroundColor: themeProvider.currentGradient.first,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _savePreferences,
            tooltip: 'Salvar e Voltar',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: themeProvider.currentGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ReorderableListView(
                padding: const EdgeInsets.all(8.0),
                header: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Arraste para reordenar. Ative para exibir.',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) {
                      newIndex -= 1;
                    }
                    final item = _visibleLeagues.removeAt(oldIndex);
                    _visibleLeagues.insert(newIndex, item);
                  });
                },
                children:
                    _visibleLeagues
                        .map((league) => _buildLeagueTile(league, true))
                        .toList() +
                    [
                      if (_hiddenLeagues.isNotEmpty)
                        Padding(
                          key: const ValueKey('hidden_header'),
                          padding: const EdgeInsets.symmetric(
                            vertical: 24.0,
                            horizontal: 16.0,
                          ),
                          child: Text(
                            'Ocultos',
                            style: GoogleFonts.poppins(
                              color: Colors.white54,
                              fontSize: 18,
                            ),
                          ),
                        ),
                    ] +
                    _hiddenLeagues
                        .map((league) => _buildLeagueTile(league, false))
                        .toList(),
              ),
      ),
    );
  }

  Widget _buildLeagueTile(League league, bool isVisible) {
    return Card(
      key: ValueKey(league.id),
      color: Colors.white.withOpacity(0.1),
      child: SwitchListTile(
        title: Text(league.name, style: const TextStyle(color: Colors.white)),
        subtitle: Text(
          league.sport,
          style: const TextStyle(color: Colors.white70),
        ),
        secondary: league.logoUrl.isNotEmpty
            ? Image.network(
                league.logoUrl,
                width: 40,
                height: 40,
                errorBuilder: (c, e, s) =>
                    const Icon(Icons.shield, color: Colors.white54),
              )
            : const Icon(Icons.shield, color: Colors.white54, size: 40),
        value: isVisible,
        onChanged: (bool value) {
          setState(() {
            if (value) {
              _hiddenLeagues.remove(league);
              _visibleLeagues.add(league);
            } else {
              _visibleLeagues.remove(league);
              _hiddenLeagues.add(league);
            }
          });
        },
      ),
    );
  }
}
