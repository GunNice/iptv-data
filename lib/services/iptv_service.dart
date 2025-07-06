// lib/services/iptv_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/channel_model.dart';
import '../models/movie_model.dart';
import '../models/series_model.dart';
import '../models/category_model.dart';
import '../models/watched_progress_model.dart';

// Nomes das caixas do Hive
const String channelsBoxName = 'channelsBox';
const String moviesBoxName = 'moviesBox';
const String seriesBoxName = 'seriesBox';
const String liveCategoriesBoxName = 'liveCategoriesBox';
const String vodCategoriesBoxName = 'vodCategoriesBox';
const String seriesCategoriesBoxName = 'seriesCategoriesBox';
const String watchedProgressBoxName = 'watchedProgressBox';

class IptvService {
  // --- MÉTODOS DE BUSCA PRINCIPAIS (CHAMADOS PELA UI) ---

  Future<List<Channel>> fetchLiveChannels() async =>
      _fetchFromBox<Channel>(channelsBoxName);
  Future<List<Movie>> fetchMovies() async =>
      _fetchFromBox<Movie>(moviesBoxName);
  Future<List<Series>> fetchSeries() async =>
      _fetchFromBox<Series>(seriesBoxName);

  Future<List<Category>> fetchLiveCategories() async =>
      _fetchAndGroupCategories(liveCategoriesBoxName);
  Future<List<Category>> fetchVodCategories() async =>
      _fetchAndGroupCategories(vodCategoriesBoxName);
  Future<List<Category>> fetchSeriesCategories() async =>
      _fetchAndGroupCategories(seriesCategoriesBoxName);

  Future<List<T>> _fetchFromBox<T>(String boxName) async {
    final box = await Hive.openBox<T>(boxName);
    return box.values.toList();
  }

  Future<List<Category>> _fetchAndGroupCategories(String boxName) async {
    final box = await Hive.openBox<Category>(boxName);
    final Map<String, Category> uniqueCategories = {};
    for (var cat in box.values) {
      if (!uniqueCategories.containsKey(cat.displayName)) {
        uniqueCategories[cat.displayName] = cat;
      }
    }
    return uniqueCategories.values.toList();
  }

  // --- LÓGICA DE DETALHES E URLS DE STREAM ---

  Future<Map<String, dynamic>> fetchItemDetails({
    int? vodId,
    int? seriesId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final dns = prefs.getString('xtream_dns');
    final user = prefs.getString('xtream_user');
    final password = prefs.getString('xtream_password');

    if (dns == null || user == null || password == null) {
      throw Exception('Dados da API não configurados.');
    }

    String action = '';
    String idParam = '';
    if (vodId != null) {
      action = 'get_vod_info';
      idParam = '&vod_id=$vodId';
    } else if (seriesId != null) {
      action = 'get_series_info';
      idParam = '&series_id=$seriesId';
    } else {
      throw Exception('Nenhum ID de filme ou série fornecido.');
    }

    final apiUrl =
        '$dns/player_api.php?username=$user&password=$password&action=$action$idParam';
    print('Buscando detalhes de: $apiUrl');

    final response = await http.get(Uri.parse(apiUrl));

    if (response.statusCode == 200) {
      if (response.headers['content-type']?.contains('application/json') !=
          true) {
        throw Exception(
          'Resposta inesperada do servidor (não é JSON). Verifique os dados de login.',
        );
      }
      final decodedBody = jsonDecode(response.body);
      return decodedBody as Map<String, dynamic>;
    } else {
      throw Exception(
        'Falha ao buscar detalhes: Status ${response.statusCode}',
      );
    }
  }

  Future<String> getVodStreamUrl({
    required int streamId,
    required String containerExtension,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final dns = prefs.getString('xtream_dns');
    final user = prefs.getString('xtream_user');
    final password = prefs.getString('xtream_password');

    return '$dns/movie/$user/$password/$streamId.$containerExtension';
  }

  // --- LÓGICA DE ATUALIZAÇÃO FORÇADA (CHAMADA PELAS CONFIGURAÇÕES) ---

  Future<void> forceRefreshAndCacheAllData() async {
    final prefs = await SharedPreferences.getInstance();
    final configType = prefs.getInt('iptv_config_type') ?? 0;

    await _clearAllBoxes();

    if (configType == 0) {
      await _processM3uData(prefs);
    } else {
      // Xtream Codes
      await _processXtreamData(prefs);
    }
    print('Todos os dados foram atualizados e salvos no Hive.');
  }

  Future<void> _clearAllBoxes() async {
    await Hive.deleteBoxFromDisk(channelsBoxName);
    await Hive.deleteBoxFromDisk(moviesBoxName);
    await Hive.deleteBoxFromDisk(seriesBoxName);
    await Hive.deleteBoxFromDisk(liveCategoriesBoxName);
    await Hive.deleteBoxFromDisk(vodCategoriesBoxName);
    await Hive.deleteBoxFromDisk(seriesCategoriesBoxName);
  }

  // --- LÓGICA DE PROCESSAMENTO XTREAM ---

  Future<void> _processXtreamData(SharedPreferences prefs) async {
    final liveCategoriesRaw = await _fetchXtreamRawList(
      prefs,
      'get_live_categories',
    );
    final vodCategoriesRaw = await _fetchXtreamRawList(
      prefs,
      'get_vod_categories',
    );
    final seriesCategoriesRaw = await _fetchXtreamRawList(
      prefs,
      'get_series_categories',
    );

    final liveCategoryMap = _createCleanCategoryMap(liveCategoriesRaw);
    final vodCategoryMap = _createCleanCategoryMap(vodCategoriesRaw);
    final seriesCategoryMap = _createCleanCategoryMap(seriesCategoriesRaw);

    await _saveCleanedCategories(liveCategoriesBoxName, liveCategoryMap);
    await _saveCleanedCategories(vodCategoriesBoxName, vodCategoryMap);
    await _saveCleanedCategories(seriesCategoriesBoxName, seriesCategoryMap);

    await _fetchAndCacheItems<Channel>(
      prefs,
      'get_live_streams',
      channelsBoxName,
      (item) => _parseChannelFromXtream(item, prefs, liveCategoryMap),
    );
    await _fetchAndCacheItems<Movie>(
      prefs,
      'get_vod_streams',
      moviesBoxName,
      (item) => _parseMovieFromXtream(item, vodCategoryMap),
    );
    await _fetchAndCacheItems<Series>(
      prefs,
      'get_series',
      seriesBoxName,
      (item) => _parseSeriesFromXtream(item, seriesCategoryMap),
    );
  }

  Map<String, String> _createCleanCategoryMap(
    List<Map<String, dynamic>> rawCategories,
  ) {
    final Map<String, String> idToCleanName = {};
    for (var cat in rawCategories) {
      final originalId = (cat['category_id'] ?? '0').toString();
      final originalName = (cat['category_name'] ?? 'Sem Categoria').toString();
      idToCleanName[originalId] = _cleanCategoryName(originalName);
    }
    return idToCleanName;
  }

  Future<void> _saveCleanedCategories(
    String boxName,
    Map<String, String> categoryMap,
  ) async {
    final Map<String, Category> uniqueCategories = {};
    categoryMap.forEach((id, name) {
      if (!uniqueCategories.containsKey(name)) {
        uniqueCategories[name] = Category(categoryId: name, categoryName: name);
      }
    });
    final box = await Hive.openBox<Category>(boxName);
    await box.addAll(uniqueCategories.values);
  }

  Future<void> _fetchAndCacheItems<T>(
    SharedPreferences prefs,
    String action,
    String boxName,
    Function(Map<String, dynamic>) parser,
  ) async {
    try {
      final itemsRaw = await _fetchXtreamRawList(prefs, action);
      final parsedItems = itemsRaw.map((item) => parser(item)).toList();
      final box = await Hive.openBox<T>(boxName);
      await box.addAll(parsedItems.cast<T>());
    } catch (e) {
      print("Erro ao processar a ação '$action': $e");
    }
  }

  Future<List<Map<String, dynamic>>> _fetchXtreamRawList(
    SharedPreferences prefs,
    String action,
  ) async {
    final dns = prefs.getString('xtream_dns');
    final user = prefs.getString('xtream_user');
    final password = prefs.getString('xtream_password');

    if (dns == null || dns.isEmpty || user == null || user.isEmpty) {
      throw Exception('Dados da API Xtream incompletos.');
    }

    final apiUrl =
        '$dns/player_api.php?username=$user&password=$password&action=$action';
    print('Buscando dados Xtream: $action');
    final response = await http.get(Uri.parse(apiUrl));

    if (response.statusCode == 200) {
      if (response.headers['content-type']?.contains('application/json') !=
          true) {
        throw Exception(
          'O servidor respondeu com um formato inesperado (HTML em vez de JSON). Verifique os dados de login ou a URL.',
        );
      }
      final decodedBody = jsonDecode(response.body);
      if (decodedBody is Map && decodedBody.containsKey('user_info')) {
        throw Exception('Autenticação falhou. Verifique seus dados.');
      }
      if (decodedBody is List) {
        return decodedBody.cast<Map<String, dynamic>>();
      }
      return [];
    } else {
      throw Exception('Falha na API ($action): Status ${response.statusCode}');
    }
  }

  // --- FUNÇÕES DE PARSE E LIMPEZA (COM CORREÇÕES) ---

  String _sanitizeUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    final trimmedUrl = url.trim();
    if (trimmedUrl.startsWith('http')) {
      return trimmedUrl;
    }
    return '';
  }

  String _cleanCategoryName(String rawName) {
    String cleanedName = rawName.split('|').last.trim();
    cleanedName = cleanedName
        .replaceAll(RegExp(r'[\s\d¹²³⁴⁵⁶⁷⁸⁹]+$'), '')
        .trim();
    return cleanedName.isEmpty ? "Geral" : cleanedName;
  }

  Category _parseCategoryFromXtream(Map<String, dynamic> item) => Category(
    categoryId: (item['category_id'] ?? '0').toString(),
    categoryName: (item['category_name'] ?? 'Sem Categoria').toString(),
  );

  Channel _parseChannelFromXtream(
    Map<String, dynamic> item,
    SharedPreferences prefs,
    Map<String, String> categoryMap,
  ) {
    final dns = prefs.getString('xtream_dns');
    final user = prefs.getString('xtream_user');
    final password = prefs.getString('xtream_password');
    final streamId = (item['stream_id'] ?? '0').toString();
    final extension = (item['container_extension'] ?? 'ts').toString();
    final originalCatId = (item['category_id'] ?? '0').toString();

    return Channel(
      name: (item['name'] ?? 'Canal sem nome').toString(),
      logoUrl: _sanitizeUrl((item['stream_icon'] ?? '').toString()),
      videoUrl: '$dns/live/$user/$password/$streamId.$extension',
      category: categoryMap[originalCatId] ?? 'Geral',
    );
  }

  Movie _parseMovieFromXtream(
    Map<String, dynamic> item,
    Map<String, String> categoryMap,
  ) {
    final originalCatId = (item['category_id'] ?? '0').toString();
    return Movie(
      name: (item['name'] ?? 'Filme sem nome').toString(),
      icon: _sanitizeUrl((item['stream_icon'] ?? '').toString()),
      streamId: item['stream_id'],
      categoryId: categoryMap[originalCatId] ?? 'Geral',
    );
  }

  Series _parseSeriesFromXtream(
    Map<String, dynamic> item,
    Map<String, String> categoryMap,
  ) {
    final originalCatId = (item['category_id'] ?? '0').toString();
    return Series(
      name: (item['name'] ?? 'Série sem nome').toString(),
      cover: _sanitizeUrl((item['cover'] ?? '').toString()),
      seriesId: int.tryParse(item['series_id'].toString()) ?? 0,
      categoryId: categoryMap[originalCatId] ?? 'Geral',
    );
  }

  // --- LÓGICA DE PROCESSAMENTO M3U ---

  Future<void> _processM3uData(SharedPreferences prefs) async {
    final channels = await _fetchAndParseM3u(prefs);
    final channelsBox = await Hive.openBox<Channel>(channelsBoxName);
    await channelsBox.addAll(channels);

    final categoryNames = channels.map((c) => c.category).toSet().toList();
    final cleanedCategories = categoryNames
        .map((name) => _cleanCategoryName(name))
        .toSet()
        .toList();
    final catBox = await Hive.openBox<Category>(liveCategoriesBoxName);
    await catBox.addAll(
      cleanedCategories.map(
        (name) => Category(categoryId: name, categoryName: name),
      ),
    );
  }

  Future<List<Channel>> _fetchAndParseM3u(SharedPreferences prefs) async {
    final url = prefs.getString('m3u_url');
    if (url == null || url.isEmpty) throw Exception('Configure uma URL M3U.');

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) return _parseM3uContent(response.body);

    throw Exception('Falha ao carregar M3U: Status ${response.statusCode}');
  }

  List<Channel> _parseM3uContent(String content) {
    final List<Channel> channels = [];
    final lines = content.split('\n');

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.startsWith('#EXTINF:')) {
        final nameRegex = RegExp(r',(.+)$');
        final logoRegex = RegExp(r'tvg-logo="([^"]+)"');
        final groupRegex = RegExp(r'group-title="([^"]+)"');

        final nameMatch = nameRegex.firstMatch(line);
        final logoMatch = logoRegex.firstMatch(line);
        final groupMatch = groupRegex.firstMatch(line);

        final videoUrl = (i + 1 < lines.length) ? lines[i + 1].trim() : '';

        if (nameMatch != null &&
            videoUrl.isNotEmpty &&
            !videoUrl.startsWith('#')) {
          channels.add(
            Channel(
              name: nameMatch.group(1)!,
              logoUrl: _sanitizeUrl(logoMatch?.group(1)),
              videoUrl: videoUrl,
              category: _cleanCategoryName(groupMatch?.group(1) ?? 'Geral'),
            ),
          );
        }
      }
    }
    if (channels.isEmpty && lines.isNotEmpty)
      throw Exception('O arquivo M3U parece inválido.');
    return channels;
  }
}
