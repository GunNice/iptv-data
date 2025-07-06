// lib/screens/settings_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/theme_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/iptv_service.dart';
import '../widgets/focusable_item.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _audioPlayer = AudioPlayer();
  final _listNameController = TextEditingController();
  final _m3uUrlController = TextEditingController();
  final _xtreamDnsController = TextEditingController();
  final _xtreamUserController = TextEditingController();
  final _xtreamPasswordController = TextEditingController();

  late int _tempSelectedColorIndex;
  int _selectedIptvConfig = 0;
  bool _soundEnabled = true;
  int _selectedSound = 0;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _tempSelectedColorIndex = context
          .read<ThemeProvider>()
          .selectedThemeIndex;
      _selectedIptvConfig = prefs.getInt('iptv_config_type') ?? 0;
      _soundEnabled = prefs.getBool('sound_enabled') ?? true;
      _selectedSound = prefs.getInt('selected_sound') ?? 0;
      _listNameController.text = prefs.getString('list_name') ?? '';
      _m3uUrlController.text = prefs.getString('m3u_url') ?? '';
      _xtreamDnsController.text = prefs.getString('xtream_dns') ?? '';
      _xtreamUserController.text = prefs.getString('xtream_user') ?? '';
      _xtreamPasswordController.text = prefs.getString('xtream_password') ?? '';
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _listNameController.dispose();
    _m3uUrlController.dispose();
    _xtreamDnsController.dispose();
    _xtreamUserController.dispose();
    _xtreamPasswordController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _showFeedback(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _saveAndProcessIptvConfig() async {
    setState(() => _isSaving = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('list_name', _listNameController.text.trim());
      await prefs.setInt('iptv_config_type', _selectedIptvConfig);

      if (_selectedIptvConfig == 0) {
        await prefs.setString('m3u_url', _m3uUrlController.text.trim());
      } else {
        await prefs.setString('xtream_dns', _xtreamDnsController.text.trim());
        await prefs.setString('xtream_user', _xtreamUserController.text.trim());
        await prefs.setString(
          'xtream_password',
          _xtreamPasswordController.text,
        );
      }

      final iptvService = IptvService();
      await iptvService.forceRefreshAndCacheAllData();

      _showFeedback('Lista salva e processada com sucesso!');

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      _showFeedback(
        'Erro: ${e.toString().replaceAll("Exception: ", "")}',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // MÉTODO MOVIDO PARA CÁ PARA SER ACESSÍVEL A TODOS
  InputDecoration _inputDecoration(
    String label,
    String? hint, [
    bool isFocused = false,
  ]) {
    final themeProvider = context.read<ThemeProvider>();
    final isLightTheme = themeProvider.currentAppTheme.name == 'Branco';
    final textColor = isLightTheme ? Colors.black87 : Colors.white;

    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: textColor.withAlpha(200)),
      hintStyle: TextStyle(color: textColor.withAlpha(150)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      filled: true,
      fillColor: Colors.black.withAlpha(20),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: isFocused
            ? BorderSide(color: Colors.white, width: 2)
            : BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: themeProvider.currentAppTheme.primaryColor,
          width: 2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isLightTheme = themeProvider.currentAppTheme.name == 'Branco';
    final textColor = isLightTheme ? Colors.black87 : Colors.white;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Configurações',
          style: GoogleFonts.poppins(color: textColor),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: FocusableItem(
          autofocus: true,
          onSelected: () => Navigator.of(context).pop(),
          child: (isFocused) => IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new,
              color: isFocused
                  ? themeProvider.currentAppTheme.primaryColor
                  : textColor,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: themeProvider.currentGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    color: themeProvider.currentAppTheme.primaryColor,
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(20.0),
                  children: [
                    _buildSectionCard(
                      title: 'Tema',
                      child: _buildThemeSelector(themeProvider),
                    ),
                    const SizedBox(height: 20),
                    _buildSectionCard(
                      title: 'Configurar IPTV',
                      child: _buildIptvConfig(themeProvider),
                    ),
                    const SizedBox(height: 20),
                    _buildSectionCard(
                      title: 'Sons de Navegação',
                      child: _buildSoundSelector(themeProvider),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    final themeProvider = context.watch<ThemeProvider>();
    final isLightTheme = themeProvider.currentAppTheme.name == 'Branco';
    final textColor = isLightTheme ? Colors.black87 : Colors.white;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
        child: Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: themeProvider.currentGlassColor,
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(color: Colors.white.withAlpha(30)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeSelector(ThemeProvider themeProvider) {
    final List<AppThemeData> themes = ThemeProvider.appThemes;
    final isLightTheme = themeProvider.currentAppTheme.name == 'Branco';
    final textColor = isLightTheme ? Colors.black87 : Colors.white;

    return Column(
      children: [
        SizedBox(
          height: 60,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: themes.length,
            separatorBuilder: (context, index) => const SizedBox(width: 15),
            itemBuilder: (context, index) {
              final theme = themes[index];
              return FocusableItem(
                onSelected: () =>
                    setState(() => _tempSelectedColorIndex = index),
                child: (isFocused) {
                  final isSelected = _tempSelectedColorIndex == index;
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: isFocused
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                          gradient: theme.accentColorForCircle != null
                              ? LinearGradient(
                                  colors: [
                                    theme.primaryColor,
                                    theme.accentColorForCircle!,
                                  ],
                                )
                              : null,
                          color: theme.accentColorForCircle == null
                              ? theme.primaryColor
                              : null,
                        ),
                        child: isSelected
                            ? Icon(
                                Icons.check,
                                color: theme.name == 'Branco'
                                    ? Colors.white
                                    : Colors.black,
                                size: 20,
                              )
                            : null,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        theme.name,
                        style: TextStyle(fontSize: 12, color: textColor),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        FocusableItem(
          onSelected: () {
            context.read<ThemeProvider>().setTheme(_tempSelectedColorIndex);
            _showFeedback('Tema aplicado!');
          },
          child: (isFocused) => ElevatedButton(
            onPressed: () {
              context.read<ThemeProvider>().setTheme(_tempSelectedColorIndex);
              _showFeedback('Tema aplicado!');
            },
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                side: isFocused
                    ? BorderSide(color: Colors.white, width: 2)
                    : BorderSide.none,
              ),
            ),
            child: const Text('Aplicar Tema'),
          ),
        ),
      ],
    );
  }

  Widget _buildIptvConfig(ThemeProvider themeProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FocusableItem(
          onSelected: () {},
          child: (isFocused) => ToggleButtons(
            isSelected: [_selectedIptvConfig == 0, _selectedIptvConfig == 1],
            onPressed: (index) => setState(() => _selectedIptvConfig = index),
            borderRadius: BorderRadius.circular(8.0),
            selectedColor: themeProvider.currentAppTheme.name == 'Branco'
                ? Colors.white
                : Colors.black,
            fillColor: themeProvider.currentAppTheme.primaryColor,
            color: Colors.white,
            borderColor: isFocused ? Colors.white : Colors.white30,
            selectedBorderColor: themeProvider.currentAppTheme.primaryColor,
            children: const [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('Lista M3U'),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('API Xtream'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _FocusableTextField(
          controller: _listNameController,
          label: 'Nome da Lista (Opcional)',
          hint: 'Ex: Meus Canais de Casa',
        ),
        const SizedBox(height: 20),
        if (_selectedIptvConfig == 0)
          _FocusableTextField(
            controller: _m3uUrlController,
            label: 'URL da Lista M3U',
            hint: 'http://exemplo.com/lista.m3u',
          )
        else
          Column(
            children: [
              _FocusableTextField(
                controller: _xtreamDnsController,
                label: 'DNS (URL)',
                hint: 'http://dns-do-servidor.com:porta',
              ),
              const SizedBox(height: 12),
              _FocusableTextField(
                controller: _xtreamUserController,
                label: 'Usuário',
              ),
              const SizedBox(height: 12),
              _FocusableTextField(
                controller: _xtreamPasswordController,
                label: 'Senha',
                obscureText: true,
              ),
            ],
          ),
        const SizedBox(height: 20),
        FocusableItem(
          onSelected: _isSaving ? () {} : _saveAndProcessIptvConfig,
          child: (isFocused) => ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveAndProcessIptvConfig,
            icon: _isSaving
                ? Container(
                    width: 24,
                    height: 24,
                    padding: const EdgeInsets.all(2.0),
                    child: const CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save),
            label: Text(_isSaving ? 'Processando...' : 'Salvar e Processar'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                side: isFocused
                    ? BorderSide(color: Colors.white, width: 2)
                    : BorderSide.none,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSoundSelector(ThemeProvider themeProvider) {
    final List<String> soundNames = [
      'Padrão',
      'Clique',
      'Beep',
      'Pop',
      'Digital',
    ];
    final isLightTheme = themeProvider.currentAppTheme.name == 'Branco';
    final textColor = isLightTheme ? Colors.black87 : Colors.white;

    return Column(
      children: [
        FocusableItem(
          onSelected: () => setState(() => _soundEnabled = !_soundEnabled),
          child: (isFocused) => SwitchListTile(
            title: Text('Ativar sons', style: TextStyle(color: textColor)),
            value: _soundEnabled,
            onChanged: (value) => setState(() => _soundEnabled = value),
            activeColor: themeProvider.currentAppTheme.primaryColor,
            tileColor: isFocused
                ? themeProvider.currentAppTheme.primaryColor.withAlpha(50)
                : Colors.transparent,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (_soundEnabled)
          Row(
            children: [
              Expanded(
                child: FocusableItem(
                  onSelected: () {},
                  child: (isFocused) => DropdownButtonFormField<int>(
                    value: _selectedSound,
                    items: List.generate(
                      soundNames.length,
                      (index) => DropdownMenuItem(
                        value: index,
                        child: Text(soundNames[index]),
                      ),
                    ),
                    onChanged: (value) =>
                        setState(() => _selectedSound = value!),
                    decoration: _inputDecoration(
                      'Tipo de Som',
                      null,
                      isFocused,
                    ),
                    dropdownColor: themeProvider.currentGradient.last,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FocusableItem(
                onSelected: () async {
                  try {
                    await _audioPlayer.play(
                      AssetSource('audio/sound$_selectedSound.mp3'),
                    );
                  } catch (e) {
                    _showFeedback(
                      'Erro ao tocar o som. Verifique os assets.',
                      isError: true,
                    );
                  }
                },
                child: (isFocused) => IconButton(
                  icon: Icon(
                    Icons.play_circle_fill,
                    size: 30,
                    color: isFocused
                        ? Colors.white
                        : themeProvider.currentAppTheme.primaryColor,
                  ),
                  onPressed: () async {
                    try {
                      await _audioPlayer.play(
                        AssetSource('audio/sound$_selectedSound.mp3'),
                      );
                    } catch (e) {
                      _showFeedback(
                        'Erro ao tocar o som. Verifique os assets.',
                        isError: true,
                      );
                    }
                  },
                  tooltip: 'Reproduzir',
                ),
              ),
            ],
          ),
        const SizedBox(height: 16),
        FocusableItem(
          onSelected: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('sound_enabled', _soundEnabled);
            await prefs.setInt('selected_sound', _selectedSound);
            _showFeedback('Preferência de som salva!');
          },
          child: (isFocused) => ElevatedButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('sound_enabled', _soundEnabled);
              await prefs.setInt('selected_sound', _selectedSound);
              _showFeedback('Preferência de som salva!');
            },
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                side: isFocused
                    ? BorderSide(color: Colors.white, width: 2)
                    : BorderSide.none,
              ),
            ),
            child: const Text('Aplicar Sons'),
          ),
        ),
      ],
    );
  }
}

// NOVO HELPER WIDGET PARA CAMPOS DE TEXTO FOCÁVEIS
class _FocusableTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscureText;

  const _FocusableTextField({
    required this.controller,
    required this.label,
    this.hint,
    this.obscureText = false,
  });

  @override
  State<_FocusableTextField> createState() => __FocusableTextFieldState();
}

class __FocusableTextFieldState extends State<_FocusableTextField> {
  final _internalFocusNode = FocusNode();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _internalFocusNode.addListener(() {
      if (!_internalFocusNode.hasFocus && mounted) {
        setState(() {
          _isEditing = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _internalFocusNode.dispose();
    super.dispose();
  }

  InputDecoration _getInputDecoration(BuildContext context, bool isFocused) {
    final themeProvider = context.read<ThemeProvider>();
    final isLightTheme = themeProvider.currentAppTheme.name == 'Branco';
    final textColor = isLightTheme ? Colors.black87 : Colors.white;

    return InputDecoration(
      labelText: widget.label,
      hintText: widget.hint,
      labelStyle: TextStyle(color: textColor.withAlpha(200)),
      hintStyle: TextStyle(color: textColor.withAlpha(150)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      filled: true,
      fillColor: Colors.black.withAlpha(20),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: isFocused
            ? const BorderSide(color: Colors.white, width: 2)
            : BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: themeProvider.currentAppTheme.primaryColor,
          width: 2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      return TextFormField(
        controller: widget.controller,
        focusNode: _internalFocusNode,
        autofocus: true,
        obscureText: widget.obscureText,
        decoration: _getInputDecoration(context, true),
      );
    }

    return FocusableItem(
      onSelected: () {
        setState(() {
          _isEditing = true;
        });
        _internalFocusNode.requestFocus();
      },
      child: (isFocused) {
        return InkWell(
          onTap: () {
            setState(() {
              _isEditing = true;
            });
            _internalFocusNode.requestFocus();
          },
          child: InputDecorator(
            decoration: _getInputDecoration(context, isFocused),
            child: Text(
              widget.obscureText
                  ? ('•' * widget.controller.text.length)
                  : (widget.controller.text.isEmpty
                        ? (widget.hint ?? '')
                        : widget.controller.text),
              style: TextStyle(
                color:
                    context.watch<ThemeProvider>().currentAppTheme.name ==
                        'Branco'
                    ? Colors.black87
                    : Colors.white,
                fontSize: 16,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      },
    );
  }
}
