// lib/screens/football_guide_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../providers/theme_provider.dart';
import '../widgets/focusable_item.dart';
import '../services/football_service.dart';
import '../models/league_model.dart';
import '../models/fixture_model.dart';
import 'manage_leagues_screen.dart';

class FootballGuideScreen extends StatefulWidget {
  const FootballGuideScreen({super.key});

  @override
  State<FootballGuideScreen> createState() => _FootballGuideScreenState();
}

class _FootballGuideScreenState extends State<FootballGuideScreen> {
  final FootballService footballService = FootballService();
  Future<List<League>>? futureLeagues;
  Future<List<Fixture>>? futureFixtures;
  String? _selectedLeagueId;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('pt_BR', null);
    _loadData();
  }

  void _loadData() {
    setState(() {
      futureLeagues = footballService.getVisibleLeagues();
      futureLeagues!.then((leagues) {
        if (mounted && leagues.isNotEmpty) {
          _onLeagueSelected(leagues.first.id);
        } else {
          setState(() {
            futureFixtures = Future.value([]);
          });
        }
      });
    });
  }

  void _onLeagueSelected(String leagueId) {
    setState(() {
      _selectedLeagueId = leagueId;
      futureFixtures = footballService.getFixturesForLeague(leagueId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final textColor = themeProvider.currentAppTheme.name == 'Branco'
        ? Colors.black87
        : Colors.white;

    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Guia de Futebol',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              FocusableItem(
                onSelected: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ManageLeaguesScreen(),
                    ),
                  );
                  _loadData();
                },
                child: (isFocused) => IconButton(
                  icon: Icon(
                    Icons.settings_suggest,
                    color: isFocused
                        ? themeProvider.currentAppTheme.primaryColor
                        : textColor,
                  ),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ManageLeaguesScreen(),
                      ),
                    );
                    _loadData();
                  },
                  tooltip: 'Gerenciar Campeonatos',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildLeaguesFilter(themeProvider),
          const SizedBox(height: 24),
          Expanded(child: _buildMatchesList(themeProvider)),
        ],
      ),
    );
  }

  Widget _buildLeaguesFilter(ThemeProvider themeProvider) {
    return SizedBox(
      height: 80,
      child: FutureBuilder<List<League>>(
        future: futureLeagues,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError ||
              !snapshot.hasData ||
              snapshot.data!.isEmpty) {
            return const Center(child: Text('Nenhuma liga para exibir.'));
          }
          final leagues = snapshot.data!;
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: leagues.length,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final league = leagues[index];
              return FocusableItem(
                autofocus: index == 0,
                onSelected: () => _onLeagueSelected(league.id),
                child: (isFocused) {
                  final isSelected = _selectedLeagueId == league.id;
                  return Opacity(
                    opacity: isSelected || isFocused ? 1.0 : 0.6,
                    child: Column(
                      children: [
                        Container(
                          height: 50,
                          width: 50,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isFocused
                                ? themeProvider.currentAppTheme.primaryColor
                                      .withOpacity(0.2)
                                : Colors.transparent,
                            border: isFocused
                                ? Border.all(
                                    color: themeProvider
                                        .currentAppTheme
                                        .primaryColor,
                                    width: 2,
                                  )
                                : null,
                          ),
                          child: league.logoUrl.isNotEmpty
                              ? Image.network(
                                  league.logoUrl,
                                  fit: BoxFit.contain,
                                  errorBuilder: (c, e, s) => const Icon(
                                    Icons.shield,
                                    color: Colors.white54,
                                  ),
                                )
                              : const Icon(Icons.shield, color: Colors.white54),
                        ),
                        const SizedBox(height: 4),
                        if (isSelected)
                          Container(
                            width: 10,
                            height: 4,
                            decoration: BoxDecoration(
                              color: themeProvider.currentAppTheme.primaryColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMatchesList(ThemeProvider themeProvider) {
    if (futureFixtures == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return FutureBuilder<List<Fixture>>(
      future: futureFixtures,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Erro ao carregar jogos: ${snapshot.error}'),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text('Nenhum jogo encontrado para esta liga.'),
          );
        }
        final matches = snapshot.data!;
        return ListView.separated(
          itemCount: matches.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final match = matches[index];
            return FocusableItem(
              onSelected: () {},
              child: (isFocused) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: isFocused
                            ? Colors.white.withOpacity(0.15)
                            : Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            match.formattedDate,
                            style: TextStyle(
                              color: themeProvider.currentAppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Text(
                              match.strEvent,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _buildMatchButton(
                            label: 'Lembrete',
                            icon: Icons.notifications_on_outlined,
                            onPressed: () {},
                          ),
                          const SizedBox(width: 16),
                          _buildMatchButton(
                            label: 'Detalhes',
                            icon: Icons.info_outline,
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMatchButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return FocusableItem(
      onSelected: onPressed,
      child: (isFocused) {
        return InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isFocused
                  ? context.read<ThemeProvider>().currentAppTheme.primaryColor
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isFocused ? Colors.black : Colors.white70,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: isFocused ? Colors.black : Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
