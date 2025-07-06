// lib/services/football_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import '../models/league_model.dart';
import '../models/fixture_model.dart';

const String allLeaguesBoxName = 'allLeaguesBox';
const String footballSettingsBoxName = 'footballSettingsBox';

class FootballService {
  final String _apiKey = "123"; // Sua chave de API TheSportsDB
  String get _baseUrl => "https://www.thesportsdb.com/api/v1/json/$_apiKey";

  // LISTA EXPANDIDA E OTIMIZADA DE CAMPEONATOS
  final Map<String, String> _topLeagues = {
    '4328': 'UEFA Champions League',
    '4335': 'Brasileirão Serie A',
    '4334': 'Ligue 1 Francesa',
    '4331': 'Bundesliga Alemã',
    '4332': 'Serie A Italiana',
    '4337': 'Eredivisie Holandesa',
    '4338': 'Primeira Liga Portuguesa',
    '4329': 'UEFA Europa League',
    '4413': 'FIFA Club World Cup',
    '4346': 'Copa Libertadores',
    '4344': 'Campeonato Carioca', // Adicionado
    '4391': 'Copa do Mundo', // Adicionado
    '4503': 'Copa do Mundo de Clubes', // Adicionado
  };

  Future<void> fetchAndCacheAllLeagues() async {
    final box = await Hive.openBox<League>(allLeaguesBoxName);
    if (box.isNotEmpty) {
      print("Ligas já estão no cache.");
      return;
    }

    print("Buscando detalhes das principais ligas...");
    Map<String, League> leagueMap = {};
    for (var entry in _topLeagues.entries) {
      try {
        final response = await http.get(
          Uri.parse("$_baseUrl/lookupleague.php?id=${entry.key}"),
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['leagues'] != null && data['leagues'].isNotEmpty) {
            final league = League.fromJson(data['leagues'][0]);
            leagueMap[league.id] = league;
          }
        }
      } catch (e) {
        print("Erro ao buscar detalhes da liga ${entry.key}: $e");
      }
    }
    await box.putAll(leagueMap);
    print("Salvas ${box.length} ligas no cache.");
  }

  Future<List<League>> getLeaguesForManagement() async {
    final box = await Hive.openBox<League>(allLeaguesBoxName);
    if (box.isEmpty) {
      await fetchAndCacheAllLeagues();
    }
    return box.values.toList();
  }

  Future<List<League>> getVisibleLeagues() async {
    final settingsBox = await Hive.openBox(footballSettingsBoxName);
    final allLeaguesBox = await Hive.openBox<League>(allLeaguesBoxName);

    if (allLeaguesBox.isEmpty) {
      await fetchAndCacheAllLeagues();
    }

    List<String> leagueOrder = List<String>.from(
      settingsBox.get('league_order') ?? [],
    );
    List<String> hiddenLeagues = List<String>.from(
      settingsBox.get('hidden_leagues') ?? [],
    );

    if (leagueOrder.isEmpty) {
      leagueOrder = allLeaguesBox.values.map((l) => l.id).toList();
      await settingsBox.put('league_order', leagueOrder);
    }

    List<League> visibleLeagues = [];
    for (var id in leagueOrder) {
      if (!hiddenLeagues.contains(id)) {
        final league = allLeaguesBox.get(id);
        if (league != null) {
          visibleLeagues.add(league);
        }
      }
    }
    return visibleLeagues;
  }

  Future<List<Fixture>> getFixturesForLeague(String leagueId) async {
    try {
      final response = await _makeRequestWithRetry(
        "$_baseUrl/eventsnextleague.php?id=$leagueId",
      );
      final data = jsonDecode(response.body);
      if (data['events'] == null) return [];

      final List fixturesJson = data['events'];
      return fixturesJson.map((json) => Fixture.fromJson(json)).toList();
    } catch (e) {
      print("Erro final ao buscar jogos para a liga $leagueId: $e");
      return [];
    }
  }

  // NOVA LÓGICA DE RETRY
  Future<http.Response> _makeRequestWithRetry(
    String url, {
    int retries = 2,
  }) async {
    int attempt = 0;
    while (attempt < retries) {
      try {
        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 15));
        if (response.statusCode == 200) {
          return response;
        } else {
          throw Exception('Status code: ${response.statusCode}');
        }
      } catch (e) {
        attempt++;
        print("Tentativa $attempt falhou para $url: $e");
        if (attempt >= retries) {
          throw Exception('Falha ao conectar à API após $retries tentativas.');
        }
        await Future.delayed(
          const Duration(seconds: 1),
        ); // Espera antes de tentar novamente
      }
    }
    throw Exception('Falha inesperada na requisição.');
  }
}
