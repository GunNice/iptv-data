// lib/services/football_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import '../models/league_model.dart';
import '../models/fixture_model.dart';

// Nomes das caixas do Hive
const String allLeaguesBoxName = 'allLeaguesBox';
const String footballSettingsBoxName = 'footballSettingsBox';

class FootballService {
  final String _apiKey = "123"; // Sua chave de API TheSportsDB
  String get _baseUrl => "https://www.thesportsdb.com/api/v1/json/$_apiKey";

  Future<void> fetchAndCacheAllLeagues() async {
    final box = await Hive.openBox<League>(allLeaguesBoxName);
    if (box.isNotEmpty) {
      print("Ligas já estão no cache.");
      return;
    }

    print("Cache de ligas vazio. Buscando da API TheSportsDB...");
    try {
      final response = await http.get(Uri.parse("$_baseUrl/all_leagues.php"));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List leaguesJson = data['leagues'];
        final List<League> footballLeagues = leaguesJson
            .map((json) => League.fromJson(json))
            .where((league) => league.sport == 'Soccer')
            .toList();

        Map<String, League> leagueMap = {
          for (var v in footballLeagues) v.id: v,
        };
        await box.putAll(leagueMap);
        print(
          "Encontradas e salvas ${footballLeagues.length} ligas de futebol.",
        );
      }
    } catch (e) {
      print("Erro ao buscar todas as ligas: $e");
    }
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
        await Future.delayed(const Duration(seconds: 1));
      }
    }
    throw Exception('Falha inesperada na requisição.');
  }
}
