// lib/services/football_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/league_model.dart';
import '../models/fixture_model.dart';

class FootballService {
  // O SEU NOVO BACKEND!
  final String _baseUrl = "https://gunnice.github.io/iptv-data/data";

  Future<List<League>> getVisibleLeagues() async {
    try {
      final response = await http.get(Uri.parse("$_baseUrl/leagues.json"));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List leaguesJson = data['leagues'];
        return leaguesJson.map((json) => League.fromJson(json)).toList();
      } else {
        throw Exception('Falha ao carregar as ligas do GitHub Pages.');
      }
    } catch (e) {
      print("Erro ao buscar ligas do GitHub: $e");
      return [];
    }
  }

  Future<List<Fixture>> getFixturesForLeague(String leagueId) async {
    try {
      final response = await http.get(
        Uri.parse("$_baseUrl/fixtures_$leagueId.json"),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['events'] == null) return [];

        final List fixturesJson = data['events'];
        return fixturesJson.map((json) => Fixture.fromJson(json)).toList();
      } else {
        // Se não encontrar o arquivo de jogos, retorna uma lista vazia sem erro
        print("Arquivo de jogos para a liga $leagueId não encontrado.");
        return [];
      }
    } catch (e) {
      print("Erro ao buscar jogos para a liga $leagueId: $e");
      return [];
    }
  }
}
