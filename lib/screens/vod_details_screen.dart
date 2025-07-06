// lib/screens/vod_details_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import '../models/movie_model.dart';
import '../models/series_model.dart';
import '../models/watched_progress_model.dart';
import '../providers/theme_provider.dart';
import '../services/iptv_service.dart';
import '../widgets/focusable_item.dart';
import 'vod_player_screen.dart';

class VodDetailsScreen extends StatefulWidget {
  final dynamic vodItem;

  const VodDetailsScreen({super.key, required this.vodItem});

  @override
  State<VodDetailsScreen> createState() => _VodDetailsScreenState();
}

class _VodDetailsScreenState extends State<VodDetailsScreen>
    with TickerProviderStateMixin {
  final IptvService iptvService = IptvService();
  late Future<Map<String, dynamic>> futureDetails;
  TabController? _tabController;

  Map<String, dynamic>? _lastWatchedEpisode;
  String? _lastWatchedSeason;

  @override
  void initState() {
    super.initState();
    _fetchDetailsAndProgress();
  }

  void _fetchDetailsAndProgress() {
    if (widget.vodItem is Movie) {
      futureDetails = iptvService.fetchItemDetails(
        vodId: widget.vodItem.streamId,
      );
    } else if (widget.vodItem is Series) {
      futureDetails = iptvService.fetchItemDetails(
        seriesId: widget.vodItem.seriesId,
      );
      futureDetails
          .then((details) {
            final episodes = details['episodes'];
            if (mounted &&
                episodes != null &&
                episodes is Map &&
                episodes.isNotEmpty) {
              final seasons = episodes.keys.toList()
                ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
              setState(() {
                _tabController = TabController(
                  length: seasons.length,
                  vsync: this,
                );
              });
              _findLastWatched(Map<String, dynamic>.from(episodes));
            }
          })
          .catchError((e) {
            print("Erro ao buscar detalhes da série: $e");
          });
    }
  }

  Future<void> _findLastWatched(Map<String, dynamic> episodesData) async {
    final progressBox = await Hive.openBox<WatchedProgress>(
      watchedProgressBoxName,
    );
    Map<String, dynamic>? firstUnfinishedEpisode;
    String? firstUnfinishedSeason;

    final seasons = episodesData.keys.toList()
      ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));

    // Itera para encontrar o primeiro episódio não finalizado
    for (var season in seasons) {
      final List episodes = episodesData[season];
      for (var episode in episodes) {
        final progress = progressBox.get(episode['id'].toString());
        if (progress == null || !progress.isFinished) {
          firstUnfinishedEpisode = episode;
          firstUnfinishedSeason = season;
          break;
        }
      }
      if (firstUnfinishedEpisode != null) break;
    }

    if (mounted) {
      setState(() {
        _lastWatchedEpisode = firstUnfinishedEpisode;
        _lastWatchedSeason = firstUnfinishedSeason;
      });
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final String initialName = widget.vodItem.name;
    final String posterUrl = (widget.vodItem is Movie)
        ? widget.vodItem.icon
        : widget.vodItem.cover;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (posterUrl.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(posterUrl),
                  fit: BoxFit.cover,
                ),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(color: Colors.black.withOpacity(0.6)),
              ),
            ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.9),
                  Colors.transparent,
                  Colors.black.withOpacity(0.9),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: FutureBuilder<Map<String, dynamic>>(
              future: futureDetails,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return _buildDetailsContent(initialName, posterUrl, null);
                }
                if (snapshot.hasError) {
                  return _buildDetailsContent(
                    initialName,
                    posterUrl,
                    null,
                    hasError: true,
                  );
                }
                final details = snapshot.data;
                return _buildDetailsContent(initialName, posterUrl, details);
              },
            ),
          ),
          Positioned(
            top: 40,
            left: 10,
            child: FocusableItem(
              autofocus: true,
              onSelected: () => Navigator.of(context).pop(),
              child: (isFocused) => IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new,
                  color: isFocused
                      ? themeProvider.currentAppTheme.primaryColor
                      : Colors.white,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsContent(
    String name,
    String posterUrl,
    Map<String, dynamic>? details, {
    bool hasError = false,
  }) {
    final info = details?['info'];
    final plot =
        info?['plot'] ??
        (hasError
            ? 'Não foi possível carregar a sinopse.'
            : 'Carregando sinopse...');
    final genre = info?['genre'] ?? '';
    final duration = info?['duration'] ?? '';
    final cast = info?['cast'] ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 60),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 120,
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: posterUrl.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(posterUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                  color: Colors.grey.shade800,
                ),
                child: posterUrl.isEmpty
                    ? const Icon(Icons.movie, color: Colors.white, size: 50)
                    : null,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (genre.isNotEmpty)
                      Text(
                        genre,
                        style: TextStyle(color: Colors.grey.shade400),
                      ),
                    if (duration.isNotEmpty)
                      Text(
                        duration,
                        style: TextStyle(color: Colors.grey.shade400),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildActionButton(details),
          const SizedBox(height: 24),
          Text(
            'Sinopse',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            plot,
            style: TextStyle(color: Colors.grey.shade300, height: 1.5),
          ),
          const SizedBox(height: 24),
          if (cast.isNotEmpty) ...[
            Text(
              'Elenco',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(cast, style: TextStyle(color: Colors.grey.shade300)),
          ],
          if (widget.vodItem is Series)
            _buildSeriesSeasons(details?['episodes'] ?? {}),
        ],
      ),
    );
  }

  Widget _buildActionButton(Map<String, dynamic>? details) {
    String buttonText = 'Assistir';
    VoidCallback? onPressedAction;

    if (widget.vodItem is Movie) {
      buttonText = 'Assistir Filme';
      onPressedAction = () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VodPlayerScreen(vodItem: widget.vodItem),
          ),
        );
      };
    } else if (widget.vodItem is Series) {
      if (_lastWatchedEpisode != null) {
        buttonText =
            'Continuar S${_lastWatchedSeason} E${_lastWatchedEpisode!['episode_num']}';
        onPressedAction = () {
          final List episodeList = details?['episodes'][_lastWatchedSeason];
          final int index = episodeList.indexWhere(
            (ep) => ep['id'] == _lastWatchedEpisode!['id'],
          );
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VodPlayerScreen(
                vodItem: _lastWatchedEpisode,
                episodeList: episodeList,
                currentEpisodeIndex: index,
              ),
            ),
          ).then((_) => _fetchDetailsAndProgress());
        };
      } else {
        buttonText = 'Assistir T01 E01';
        onPressedAction = () {
          final episodesData = details?['episodes'];
          if (episodesData != null && episodesData.isNotEmpty) {
            final firstSeasonKey =
                (episodesData.keys.toList()
                      ..sort((a, b) => int.parse(a).compareTo(int.parse(b))))
                    .first;
            final List episodeList = episodesData[firstSeasonKey];
            if (episodeList.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VodPlayerScreen(
                    vodItem: episodeList.first,
                    episodeList: episodeList,
                    currentEpisodeIndex: 0,
                  ),
                ),
              ).then((_) => _fetchDetailsAndProgress());
            }
          }
        };
      }
    }

    return Row(
      children: [
        Expanded(
          child: FocusableItem(
            onSelected: onPressedAction ?? () {},
            child: (isFocused) => ElevatedButton.icon(
              onPressed: onPressedAction,
              icon: const Icon(Icons.play_arrow),
              label: Text(buttonText),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor: context
                    .read<ThemeProvider>()
                    .currentAppTheme
                    .primaryColor,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  side: isFocused
                      ? const BorderSide(color: Colors.white, width: 2)
                      : BorderSide.none,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        FocusableItem(
          onSelected: () {
            /* Lógica para favoritar */
          },
          child: (isFocused) => IconButton(
            onPressed: () {},
            icon: Icon(
              Icons.favorite_border,
              size: 30,
              color: isFocused
                  ? context.read<ThemeProvider>().currentAppTheme.primaryColor
                  : Colors.white,
            ),
            tooltip: 'Adicionar aos Favoritos',
          ),
        ),
      ],
    );
  }

  Widget _buildSeriesSeasons(Map<String, dynamic> episodesData) {
    if (_tabController == null) {
      return (episodesData.isEmpty && futureDetails != null)
          ? const Padding(
              padding: EdgeInsets.only(top: 24.0),
              child: Center(child: CircularProgressIndicator()),
            )
          : const SizedBox.shrink();
    }

    final seasons = episodesData.keys.toList()
      ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          'Temporadas',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        _buildSeasonTabs(seasons),
        SizedBox(
          height: 400,
          child: TabBarView(
            controller: _tabController,
            children: seasons.map((season) {
              final List episodes = episodesData[season];
              return ListView.builder(
                itemCount: episodes.length,
                itemBuilder: (context, index) {
                  final episode = episodes[index];
                  return _buildEpisodeCard(episode, episodes, index);
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSeasonTabs(List<String> seasons) {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: seasons.length,
        itemBuilder: (context, index) {
          return FocusableItem(
            onSelected: () => _tabController?.animateTo(index),
            child: (isFocused) {
              return GestureDetector(
                onTap: () => _tabController?.animateTo(index),
                child: AnimatedBuilder(
                  animation: _tabController!,
                  builder: (context, child) {
                    final isSelected = _tabController!.index == index;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: (isSelected || isFocused)
                                ? context
                                      .read<ThemeProvider>()
                                      .currentAppTheme
                                      .primaryColor
                                : Colors.transparent,
                            width: 4,
                          ),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Temporada ${seasons[index]}',
                          style: TextStyle(
                            color: (isSelected || isFocused)
                                ? Colors.white
                                : Colors.grey.shade400,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEpisodeCard(
    Map<String, dynamic> episode,
    List allEpisodes,
    int currentIndex,
  ) {
    final String episodeId = episode['id'].toString();
    final String episodeTitle =
        episode['title'] ?? 'Episódio ${episode['episode_num']}';
    final String episodeIcon = episode['info']?['movie_image'] ?? '';
    final String durationStr = episode['info']?['duration'] ?? '00:00:00';
    final int totalSeconds = _parseDuration(durationStr);

    return ValueListenableBuilder(
      valueListenable: Hive.box<WatchedProgress>(
        watchedProgressBoxName,
      ).listenable(keys: [episodeId]),
      builder: (context, Box<WatchedProgress> box, _) {
        final progress = box.get(episodeId);
        final double progressValue = (progress != null && totalSeconds > 0)
            ? progress.position / totalSeconds
            : 0.0;
        final bool isFinished = progress?.isFinished ?? false;

        return FocusableItem(
          onSelected: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VodPlayerScreen(
                  vodItem: episode,
                  episodeList: allEpisodes,
                  currentEpisodeIndex: currentIndex,
                ),
              ),
            ).then(
              (_) => setState(() {
                // Atualiza a tela ao voltar do player para refletir o novo progresso
                _fetchDetailsAndProgress();
              }),
            );
          },
          child: (isFocused) {
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isFocused
                    ? Colors.white.withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Container(
                    width: 140,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.black.withOpacity(0.5),
                      image: episodeIcon.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(episodeIcon),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: episodeIcon.isEmpty
                        ? const Center(
                            child: Icon(Icons.movie, color: Colors.white54),
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${episode['episode_num']}. $episodeTitle",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Duração: $durationStr",
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: progressValue,
                          backgroundColor: Colors.grey.shade700,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            context
                                .read<ThemeProvider>()
                                .currentAppTheme
                                .primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  if (isFinished)
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 20,
                    )
                  else
                    const SizedBox(width: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  int _parseDuration(String durationStr) {
    final parts = durationStr.split(':');
    if (parts.length == 3) {
      try {
        return int.parse(parts[0]) * 3600 +
            int.parse(parts[1]) * 60 +
            int.parse(parts[2]);
      } catch (e) {
        return 0;
      }
    }
    return 0;
  }
}
