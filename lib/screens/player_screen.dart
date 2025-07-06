// lib/screens/player_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:provider/provider.dart';
import '../models/channel_model.dart';
import '../providers/theme_provider.dart';
import '../widgets/focusable_item.dart';

class PlayerScreen extends StatefulWidget {
  final Channel channel;
  // No futuro, passaremos a lista de canais da categoria para troca rápida
  // final List<Channel> channelList;
  // final int initialIndex;

  const PlayerScreen({
    super.key,
    required this.channel,
    // required this.channelList,
    // required this.initialIndex,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _areControlsVisible = true;
  Timer? _controlsTimer;

  // Nós de Foco para os controles do player
  final FocusNode _playPauseFocusNode = FocusNode();
  final FocusNode _closeButtonFocusNode = FocusNode();
  // Adicionar nós para outros botões (EPG, Lista, etc.) aqui

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _setOrientationAndInitializePlayer();
  }

  Future<void> _setOrientationAndInitializePlayer() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.channel.videoUrl),
      httpHeaders: const {'User-Agent': 'VLC/3.0.20 (Linux; Android 11)'},
    );

    try {
      await _controller.initialize();
      await _controller.play();
      setState(() {
        _isInitialized = true;
      });
      _startControlsTimer();
      // Pede o foco para o botão de play/pause quando o player inicia
      FocusScope.of(context).requestFocus(_playPauseFocusNode);
    } catch (e) {
      print("Erro ao inicializar o player: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Erro ao carregar o canal. Verifique a lista ou a conexão.',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    WakelockPlus.disable();
    _controlsTimer?.cancel();
    _playPauseFocusNode.dispose();
    _closeButtonFocusNode.dispose();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    super.dispose();
  }

  void _toggleControls() {
    setState(() {
      _areControlsVisible = !_areControlsVisible;
      if (_areControlsVisible) {
        _startControlsTimer();
        // Devolve o foco ao botão principal quando os controles reaparecem
        FocusScope.of(context).requestFocus(_playPauseFocusNode);
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

  // Lógica para trocar de canal
  void _changeChannel(int direction) {
    print(
      "Apertou para ${direction > 0 ? 'baixo (próximo)' : 'cima (anterior)'}",
    );
    // Lógica para buscar o próximo/anterior canal na lista e reiniciar o player virá aqui
    _showFeedback("Próximo Canal (a implementar)");
  }

  void _showFeedback(String message) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.center),
        backgroundColor: Colors.black.withOpacity(0.7),
        duration: const Duration(seconds: 1),
        width: 300,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        // Foco principal da tela para capturar eventos de seta
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              _changeChannel(1);
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              _changeChannel(-1);
              return KeyEventResult.handled;
            }
            // Lógica para setas esquerda/direita para mostrar painéis virá aqui
          }
          return KeyEventResult.ignored;
        },
        child: _isInitialized
            ? GestureDetector(
                onTap: _toggleControls,
                child: Stack(
                  alignment: Alignment.center,
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
                      child: Container(color: Colors.black.withOpacity(0.4)),
                    ),
                    AnimatedOpacity(
                      opacity: _areControlsVisible ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: _buildControls(),
                    ),
                  ],
                ),
              )
            : const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
      ),
    );
  }

  Widget _buildControls() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.channel.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(blurRadius: 2.0, color: Colors.black)],
                ),
              ),
              FocusableItem(
                focusNode: _closeButtonFocusNode,
                onSelected: () => Navigator.of(context).pop(),
                child: (isFocused) => IconButton(
                  icon: const Icon(Icons.close, size: 30),
                  color: isFocused
                      ? context
                            .read<ThemeProvider>()
                            .currentAppTheme
                            .primaryColor
                      : Colors.white,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
        FocusableItem(
          focusNode: _playPauseFocusNode,
          onSelected: () {
            setState(() {
              _controller.value.isPlaying
                  ? _controller.pause()
                  : _controller.play();
            });
            _startControlsTimer();
          },
          child: (isFocused) => Icon(
            _controller.value.isPlaying
                ? Icons.pause_circle_outline
                : Icons.play_circle_outline,
            color: isFocused
                ? context.read<ThemeProvider>().currentAppTheme.primaryColor
                : Colors.white,
            size: 64,
          ),
        ),
        const SizedBox(height: 60),
      ],
    );
  }
}
