// lib/screens/vod_player_screen.dart

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/watched_progress_model.dart';
import '../providers/theme_provider.dart';
import '../widgets/focusable_item.dart';
import '../services/iptv_service.dart';
import '../models/movie_model.dart';

class VodPlayerScreen extends StatefulWidget {
  final dynamic vodItem;
  final List? episodeList;
  final int? currentEpisodeIndex;

  const VodPlayerScreen({
    super.key,
    required this.vodItem,
    this.episodeList,
    this.currentEpisodeIndex,
  });

  @override
  State<VodPlayerScreen> createState() => _VodPlayerScreenState();
}

class _VodPlayerScreenState extends State<VodPlayerScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _areControlsVisible = true;
  Timer? _controlsTimer;
  Timer? _progressTimer;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  final IptvService iptvService = IptvService();
  late Box<WatchedProgress> _progressBox;

  late dynamic _currentItem;
  late int _currentIndex;

  final FocusNode _playPauseFocusNode = FocusNode();
  final FocusNode _rewindFocusNode = FocusNode();
  final FocusNode _forwardFocusNode = FocusNode();
  final FocusNode _closeButtonFocusNode = FocusNode();
  final FocusNode _nextEpisodeFocusNode = FocusNode();
  final FocusNode _prevEpisodeFocusNode = FocusNode();
  final FocusNode _progressSliderFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _currentItem = widget.vodItem;
    _currentIndex = widget.currentEpisodeIndex ?? 0;
    WakelockPlus.enable();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    setState(() => _isInitialized = false);
    _progressBox = await Hive.openBox<WatchedProgress>(watchedProgressBoxName);

    try {
      final streamId = (_currentItem is Map)
          ? int.tryParse(_currentItem['id'].toString()) ?? 0
          : (_currentItem as Movie).streamId;
      final extension = (_currentItem is Map)
          ? _currentItem['container_extension']
          : 'mp4';

      final streamUrl = await iptvService.getVodStreamUrl(
        streamId: streamId,
        containerExtension: extension ?? 'mp4',
      );

      _controller = VideoPlayerController.networkUrl(
        Uri.parse(streamUrl),
        httpHeaders: const {'User-Agent': 'VLC/3.0.20 (Linux; Android 11)'},
      );

      await _controller.initialize();
      final progress = _progressBox.get(streamId.toString());
      if (progress != null && !progress.isFinished) {
        await _controller.seekTo(Duration(seconds: progress.position));
      }

      await _controller.play();
      _controller.addListener(_videoListener);

      setState(() {
        _isInitialized = true;
        _totalDuration = _controller.value.duration;
      });
      _startControlsTimer();
      _startProgressTimer();
      _playPauseFocusNode.requestFocus();
    } catch (e) {
      print("Erro ao inicializar o player VOD: $e");
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar vídeo: ${e.toString()}')),
        );
      }
    }
  }

  void _videoListener() {
    if (!_isInitialized || !_controller.value.isInitialized) return;

    setState(() {
      _currentPosition = _controller.value.position;
    });

    // Autoplay quando faltarem 30 segundos para o fim
    if (!_controller.value.isBuffering &&
        _totalDuration > const Duration(seconds: 30) &&
        _currentPosition >= (_totalDuration - const Duration(seconds: 30))) {
      _onVideoEnd();
    }
  }

  void _onVideoEnd() {
    _saveProgress(isFinished: true);
    if (widget.episodeList != null &&
        _currentIndex < widget.episodeList!.length - 1) {
      _playNextEpisode();
    } else {
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _playNextEpisode() {
    if (widget.episodeList == null ||
        _currentIndex >= widget.episodeList!.length - 1)
      return;

    _saveProgress(isFinished: true);
    setState(() {
      _currentIndex++;
      _currentItem = widget.episodeList![_currentIndex];
    });
    _controller.removeListener(_videoListener);
    _controller.dispose();
    _initializePlayer();
  }

  void _playPrevEpisode() {
    if (widget.episodeList == null || _currentIndex <= 0) return;

    _saveProgress();
    setState(() {
      _currentIndex--;
      _currentItem = widget.episodeList![_currentIndex];
    });
    _controller.removeListener(_videoListener);
    _controller.dispose();
    _initializePlayer();
  }

  @override
  void dispose() {
    _saveProgress();
    _controller.removeListener(_videoListener);
    _controller.dispose();
    WakelockPlus.disable();
    _controlsTimer?.cancel();
    _progressTimer?.cancel();
    _playPauseFocusNode.dispose();
    _rewindFocusNode.dispose();
    _forwardFocusNode.dispose();
    _closeButtonFocusNode.dispose();
    _nextEpisodeFocusNode.dispose();
    _prevEpisodeFocusNode.dispose();
    _progressSliderFocusNode.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _saveProgress(),
    );
  }

  void _saveProgress({bool isFinished = false}) {
    if (!_isInitialized || !_controller.value.isInitialized) return;
    final streamId =
        ((_currentItem is Map)
                ? _currentItem['id']
                : (_currentItem as Movie).streamId)
            .toString();
    final position = _controller.value.position.inSeconds;
    final duration = _controller.value.duration.inSeconds;

    if (duration > 0) {
      final progress = WatchedProgress(
        position: position,
        duration: duration,
        isFinished: isFinished || (position / duration > 0.95),
      );
      _progressBox.put(streamId, progress);
      print(
        "Progresso salvo para o item $streamId: $position/$duration segundos.",
      );
    }
  }

  void _toggleControls() {
    setState(() {
      _areControlsVisible = !_areControlsVisible;
      if (_areControlsVisible) {
        _startControlsTimer();
        _playPauseFocusNode.requestFocus();
      } else {
        _controlsTimer?.cancel();
      }
    });
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _areControlsVisible) {
        setState(() {
          _areControlsVisible = false;
        });
      }
    });
  }

  void _seek(Duration delta) async {
    if (!_isInitialized) return;
    final newPosition = (await _controller.position)! + delta;
    await _controller.seekTo(newPosition);
    _startControlsTimer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isInitialized
          ? GestureDetector(
              onTap: _toggleControls,
              child: Stack(
                children: [
                  Center(
                    child: AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    ),
                  ),
                  AnimatedOpacity(
                    opacity: _areControlsVisible ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: _buildControlsOverlay(),
                  ),
                ],
              ),
            )
          : const Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }

  Widget _buildControlsOverlay() {
    final themeProvider = context.watch<ThemeProvider>();
    final primaryColor = themeProvider.currentAppTheme.primaryColor;
    final itemName = (_currentItem is Map)
        ? _currentItem['title']
        : (_currentItem as Movie).name;

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.7),
                Colors.transparent,
                Colors.black.withOpacity(0.7),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
        Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 48.0,
              vertical: 24.0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    itemName ?? 'Carregando...',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                FocusableItem(
                  focusNode: _closeButtonFocusNode,
                  onSelected: () => Navigator.of(context).pop(),
                  onArrowDown: () => _playPauseFocusNode.requestFocus(),
                  child: (isFocused) => IconButton(
                    icon: const Icon(Icons.close, size: 30),
                    color: isFocused ? primaryColor : Colors.white,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 64.0,
              vertical: 24.0,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildPlaybackControls(primaryColor),
                      const SizedBox(height: 12),
                      _buildProgressBar(primaryColor),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaybackControls(Color primaryColor) {
    final bool isSeries = widget.episodeList != null;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildControlButton(
          focusNode: _prevEpisodeFocusNode,
          label: 'Anterior',
          icon: Icons.skip_previous_rounded,
          onSelected: isSeries ? _playPrevEpisode : null,
          primaryColor: primaryColor,
        ),
        const SizedBox(width: 20),
        _buildControlButton(
          focusNode: _rewindFocusNode,
          label: 'Retroceder 15s',
          icon: Icons.replay_10_rounded,
          onSelected: () => _seek(const Duration(seconds: -15)),
          primaryColor: primaryColor,
        ),
        const SizedBox(width: 20),
        FocusableItem(
          focusNode: _playPauseFocusNode,
          onSelected: () {
            setState(
              () => _controller.value.isPlaying
                  ? _controller.pause()
                  : _controller.play(),
            );
            _startControlsTimer();
          },
          child: (isFocused) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFocused
                      ? primaryColor
                      : Colors.white.withOpacity(0.2),
                  boxShadow: isFocused
                      ? [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.7),
                            blurRadius: 15,
                            spreadRadius: 5,
                          ),
                        ]
                      : [],
                ),
                child: Icon(
                  _controller.value.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: isFocused ? Colors.black : Colors.white,
                  size: 56, // Tamanho reduzido
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Play/Pause',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        _buildControlButton(
          focusNode: _forwardFocusNode,
          label: 'Avançar 15s',
          icon: Icons.forward_10_rounded,
          onSelected: () => _seek(const Duration(seconds: 15)),
          primaryColor: primaryColor,
        ),
        const SizedBox(width: 20),
        _buildControlButton(
          focusNode: _nextEpisodeFocusNode,
          label: 'Próximo',
          icon: Icons.skip_next_rounded,
          onSelected: isSeries ? _playNextEpisode : null,
          primaryColor: primaryColor,
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required FocusNode focusNode,
    required String label,
    required IconData icon,
    required VoidCallback? onSelected,
    required Color primaryColor,
  }) {
    return FocusableItem(
      focusNode: focusNode,
      onSelected: onSelected ?? () {},
      child: (isFocused) {
        final color = (onSelected != null && isFocused)
            ? primaryColor
            : Colors.white;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(icon, size: 28), // Tamanho reduzido
              color: color,
              onPressed: onSelected,
            ),
            Text(
              label,
              style: TextStyle(color: color.withOpacity(0.7), fontSize: 10),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProgressBar(Color primaryColor) {
    String formatDuration(Duration d) =>
        d.toString().split('.').first.padLeft(8, "0");

    return FocusableItem(
      focusNode: _progressSliderFocusNode,
      onSelected: () {},
      onArrowUp: () => _playPauseFocusNode.requestFocus(),
      child: (isFocused) {
        return Row(
          children: [
            Text(
              formatDuration(_currentPosition),
              style: const TextStyle(color: Colors.white70),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 6.0,
                  trackShape: const RoundedRectSliderTrackShape(),
                  activeTrackColor: primaryColor,
                  inactiveTrackColor: Colors.white.withOpacity(0.3),
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 8.0,
                  ),
                  thumbColor: primaryColor,
                  overlayColor: primaryColor.withAlpha(isFocused ? 80 : 32),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 28.0,
                  ),
                ),
                child: Slider(
                  value: _currentPosition.inSeconds.toDouble().clamp(
                    0.0,
                    _totalDuration.inSeconds.toDouble(),
                  ),
                  min: 0.0,
                  max: _totalDuration.inSeconds.toDouble(),
                  onChanged: (value) {
                    _controller.seekTo(Duration(seconds: value.toInt()));
                    _startControlsTimer();
                  },
                ),
              ),
            ),
            Text(
              formatDuration(_totalDuration),
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        );
      },
    );
  }
}
