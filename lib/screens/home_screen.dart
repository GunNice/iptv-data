// lib/screens/home_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/channel_model.dart';
import '../models/movie_model.dart';
import '../models/series_model.dart';
import '../models/category_model.dart';
import '../providers/theme_provider.dart';
import '../services/iptv_service.dart';
import '../widgets/focusable_item.dart';
import 'settings_screen.dart';
import 'player_screen.dart';
import 'vod_details_screen.dart';
import 'football_guide_screen.dart'; // <-- 1. IMPORTAÇÃO ADICIONADA

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedTabIndex = 0;
  final IptvService iptvService = IptvService();

  late Future<List<Channel>> futureLiveTv;
  late Future<List<Movie>> futureMovies;
  late Future<List<Series>> futureSeries;
  late Future<List<Category>> futureLiveCategories;
  late Future<List<Category>> futureVodCategories;
  late Future<List<Category>> futureSeriesCategories;

  int _selectedCategoryIndex = 0;

  final FocusNode _categoryListFocusNode = FocusNode();
  final Map<int, FocusNode> _gridFocusNodes = {};
  // 2. LISTA DE FOCO DAS ABAS ATUALIZADA
  final List<FocusNode> _tabFocusNodes = [
    FocusNode(),
    FocusNode(),
    FocusNode(),
    FocusNode(), // Para a aba Futebol
    FocusNode(), // Para o ícone de perfil
  ];
  final List<FocusNode> _sideBarFocusNodes = [
    FocusNode(),
    FocusNode(),
    FocusNode(),
    FocusNode(),
  ];

  @override
  void initState() {
    super.initState();
    _loadAllData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _categoryListFocusNode.requestFocus();
    });
  }

  void _loadAllData() {
    setState(() {
      futureLiveTv = iptvService.fetchLiveChannels();
      futureMovies = iptvService.fetchMovies();
      futureSeries = iptvService.fetchSeries();
      futureLiveCategories = iptvService.fetchLiveCategories();
      futureVodCategories = iptvService.fetchVodCategories();
      futureSeriesCategories = iptvService.fetchSeriesCategories();
    });
  }

  void _refreshAllData() {
    setState(() {
      print("Recarregando todos os dados do cache...");
      _selectedCategoryIndex = 0;
      _gridFocusNodes.clear();
      _loadAllData();
      _tabFocusNodes[_selectedTabIndex].requestFocus();
    });
  }

  @override
  void dispose() {
    _categoryListFocusNode.dispose();
    for (var node in _gridFocusNodes.values) {
      node.dispose();
    }
    for (var node in _tabFocusNodes) {
      node.dispose();
    }
    for (var node in _sideBarFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isLightTheme = themeProvider.currentAppTheme.name == 'Branco';
    final textColor = isLightTheme ? Colors.black87 : Colors.white;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: themeProvider.currentGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 20.0,
                horizontal: 16.0,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24.0),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 25.0, sigmaY: 25.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: themeProvider.currentGlassColor,
                      borderRadius: BorderRadius.circular(24.0),
                      border: Border.all(color: Colors.white.withAlpha(30)),
                    ),
                    child: Row(
                      children: [
                        _buildSideNavBar(context, textColor),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                            child: Column(
                              children: [
                                _buildTopBar(textColor),
                                const SizedBox(height: 24),
                                Expanded(child: _buildContent(textColor)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 3. MÉTODO DE CONTEÚDO ATUALIZADO
  Widget _buildContent(Color textColor) {
    switch (_selectedTabIndex) {
      case 0:
        return _buildSectionLayout(
          futureLiveCategories,
          futureLiveTv,
          textColor,
        );
      case 1:
        return _buildSectionLayout(
          futureVodCategories,
          futureMovies,
          textColor,
        );
      case 2:
        return _buildSectionLayout(
          futureSeriesCategories,
          futureSeries,
          textColor,
        );
      case 3:
        return const FootballGuideScreen(); // Adicionada a nova tela
      default:
        return Container();
    }
  }

  Widget _buildSectionLayout<T>(
    Future<List<Category>> futureCategories,
    Future<List<T>> futureItems,
    Color textColor,
  ) {
    return FutureBuilder<List<Category>>(
      future: futureCategories,
      builder: (context, categorySnapshot) {
        if (categorySnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!categorySnapshot.hasData || categorySnapshot.data!.isEmpty) {
          return Center(
            child: Text(
              'Nenhuma categoria encontrada.',
              style: TextStyle(color: textColor),
            ),
          );
        }

        final categories = categorySnapshot.data!;
        categories.sort(
          (a, b) => a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          ),
        );

        if (_selectedCategoryIndex >= categories.length) {
          _selectedCategoryIndex = 0;
        }

        final selectedCategory = categories.isNotEmpty
            ? categories[_selectedCategoryIndex]
            : null;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 150,
              child: _buildCategoryList(categories, textColor),
            ),
            const VerticalDivider(width: 1, color: Colors.white24),
            const SizedBox(width: 16),
            Expanded(
              child: selectedCategory == null
                  ? const Center(child: Text('Selecione uma categoria'))
                  : _buildItemView<T>(futureItems, selectedCategory, textColor),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryList(List<Category> categories, Color textColor) {
    return Focus(
      focusNode: _categoryListFocusNode,
      child: ListView.builder(
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return FocusableItem(
            onSelected: () => _gridFocusNodes[0]?.requestFocus(),
            onArrowRight: () => _gridFocusNodes[0]?.requestFocus(),
            onArrowUp: (index == 0)
                ? () => _tabFocusNodes[_selectedTabIndex].requestFocus()
                : null,
            autofocus: index == 0,
            child: (bool isFocused) {
              final isSelected = index == _selectedCategoryIndex;
              if (isFocused && !isSelected) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _selectedCategoryIndex = index);
                });
              }
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? context
                            .read<ThemeProvider>()
                            .currentAppTheme
                            .primaryColor
                            .withAlpha(80)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: isFocused
                      ? Border.all(
                          color: context
                              .read<ThemeProvider>()
                              .currentAppTheme
                              .primaryColor,
                          width: 2,
                        )
                      : null,
                ),
                child: Text(
                  category.displayName,
                  style: GoogleFonts.poppins(
                    color: textColor,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildItemView<T>(
    Future<List<T>> future,
    Category selectedCategory,
    Color textColor,
  ) {
    return FutureBuilder<List<T>>(
      future: future,
      builder: (context, itemSnapshot) {
        if (itemSnapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (!itemSnapshot.hasData || itemSnapshot.data!.isEmpty)
          return Center(
            child: Text(
              'Nenhum item encontrado.',
              style: TextStyle(color: textColor),
            ),
          );

        final List<dynamic> filteredItems = itemSnapshot.data!.where((item) {
          if (item is Channel)
            return item.category == selectedCategory.displayName;
          if (item is Movie)
            return item.categoryId == selectedCategory.displayName;
          if (item is Series)
            return item.categoryId == selectedCategory.displayName;
          return false;
        }).toList();

        if (filteredItems.isEmpty)
          return Center(
            child: Text(
              'Nenhum item nesta categoria.',
              style: TextStyle(color: textColor),
            ),
          );

        return _buildItemGrid(filteredItems, textColor);
      },
    );
  }

  Widget _buildItemGrid(List<dynamic> items, Color textColor) {
    final isLiveTv = items.isNotEmpty && items.first is Channel;
    final crossAxisCount = isLiveTv ? 7 : 5;

    return GridView.builder(
      padding: const EdgeInsets.only(top: 4),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: isLiveTv ? 1.0 : 0.7,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        _gridFocusNodes.putIfAbsent(index, () => FocusNode());

        final item = items[index];
        String name = '';
        String posterUrl = '';

        if (item is Channel) {
          name = item.name;
          posterUrl = item.logoUrl;
        } else if (item is Movie) {
          name = item.name;
          posterUrl = item.icon;
        } else if (item is Series) {
          name = item.name;
          posterUrl = item.cover;
        }

        final doNavigation = () {
          if (item is Channel) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PlayerScreen(channel: item),
              ),
            );
          } else if (item is Movie || item is Series) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VodDetailsScreen(vodItem: item),
              ),
            );
          }
        };

        return FocusableItem(
          focusNode: _gridFocusNodes[index],
          onSelected: doNavigation,
          onArrowLeft: (index % crossAxisCount == 0)
              ? () => _categoryListFocusNode.requestFocus()
              : null,
          onArrowUp: (index < crossAxisCount)
              ? () => _tabFocusNodes[_selectedTabIndex].requestFocus()
              : null,
          autofocus: index == 0,
          child: (bool isFocused) {
            return Column(
              children: [
                Expanded(
                  child: Card(
                    color: Colors.black.withAlpha(100),
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: isFocused
                          ? BorderSide(
                              color: context
                                  .read<ThemeProvider>()
                                  .currentAppTheme
                                  .primaryColor,
                              width: 3,
                            )
                          : BorderSide.none,
                    ),
                    child: InkWell(
                      onTap: doNavigation,
                      child: posterUrl.isNotEmpty
                          ? Ink.image(
                              image: NetworkImage(posterUrl),
                              fit: isLiveTv ? BoxFit.contain : BoxFit.cover,
                              padding: isLiveTv
                                  ? const EdgeInsets.all(6)
                                  : EdgeInsets.zero,
                              child: Image.network(
                                posterUrl,
                                errorBuilder: (context, error, stackTrace) =>
                                    Center(
                                      child: Icon(
                                        isLiveTv
                                            ? Icons.tv_off_rounded
                                            : Icons.movie_creation_outlined,
                                        color: Colors.white54,
                                        size: 20,
                                      ),
                                    ),
                              ),
                            )
                          : Center(
                              child: Icon(
                                isLiveTv ? Icons.tv_rounded : Icons.movie,
                                color: Colors.white54,
                                size: 20,
                              ),
                            ),
                    ),
                  ),
                ),
                if (isLiveTv) ...[
                  const SizedBox(height: 4),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 9, color: textColor),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSideNavBar(BuildContext context, Color iconColor) {
    return Container(
      width: 60,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          FocusableItem(
            focusNode: _sideBarFocusNodes[0],
            onSelected: _refreshAllData,
            child: (isFocused) => IconButton(
              onPressed: _refreshAllData,
              icon: Icon(
                Icons.refresh,
                color: isFocused
                    ? context.read<ThemeProvider>().currentAppTheme.primaryColor
                    : iconColor.withAlpha(180),
                size: 28,
              ),
              tooltip: 'Recarregar do Cache',
            ),
          ),
          const Spacer(),
          FocusableItem(
            focusNode: _sideBarFocusNodes[1],
            onSelected: () {},
            child: (isFocused) => IconButton(
              onPressed: () {},
              icon: Icon(
                Icons.search,
                color: isFocused
                    ? context.read<ThemeProvider>().currentAppTheme.primaryColor
                    : iconColor.withAlpha(180),
                size: 28,
              ),
            ),
          ),
          const SizedBox(height: 20),
          FocusableItem(
            focusNode: _sideBarFocusNodes[2],
            onSelected: () {},
            child: (isFocused) => IconButton(
              onPressed: () {},
              icon: Icon(
                Icons.favorite_border,
                color: isFocused
                    ? context.read<ThemeProvider>().currentAppTheme.primaryColor
                    : iconColor.withAlpha(180),
                size: 28,
              ),
            ),
          ),
          const Spacer(),
          FocusableItem(
            focusNode: _sideBarFocusNodes[3],
            onSelected: () async {
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
              if (result == true) {
                _refreshAllData();
              }
            },
            child: (isFocused) => IconButton(
              onPressed: () async {
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
                if (result == true) {
                  _refreshAllData();
                }
              },
              icon: Icon(
                Icons.settings,
                color: isFocused
                    ? context.read<ThemeProvider>().currentAppTheme.primaryColor
                    : iconColor.withAlpha(180),
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            _buildTab("Live TV", 0, textColor),
            const SizedBox(width: 20),
            _buildTab("Movies", 1, textColor),
            const SizedBox(width: 20),
            _buildTab("Séries", 2, textColor),
            const SizedBox(width: 20),
            _buildTab("Futebol", 3, textColor),
          ],
        ),
        FocusableItem(
          focusNode: _tabFocusNodes[4],
          onSelected: () {},
          child: (isFocused) => Icon(
            Icons.person_outline,
            color: isFocused
                ? context.read<ThemeProvider>().currentAppTheme.primaryColor
                : textColor,
            size: 28,
          ),
        ),
      ],
    );
  }

  Widget _buildTab(String title, int index, Color textColor) {
    final themeProvider = context.read<ThemeProvider>();
    final isSelected = _selectedTabIndex == index;

    final action = () {
      setState(() {
        _selectedTabIndex = index;
        _selectedCategoryIndex = 0;
        _gridFocusNodes.clear();
        _categoryListFocusNode.requestFocus();
      });
    };

    return FocusableItem(
      focusNode: _tabFocusNodes[index],
      onSelected: action,
      onArrowDown: () => _categoryListFocusNode.requestFocus(),
      child: (bool isFocused) {
        return GestureDetector(
          onTap: action,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isSelected || isFocused
                      ? textColor
                      : textColor.withAlpha(150),
                ),
              ),
              if (isSelected)
                Container(
                  margin: const EdgeInsets.only(top: 4.0),
                  height: 3,
                  width: 20,
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
  }
}
