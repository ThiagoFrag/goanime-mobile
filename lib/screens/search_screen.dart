import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/jikan_models.dart';
import '../services/jikan_service.dart';
import '../services/gomang_service.dart';
import '../services/search_history_service.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../utils/responsive.dart';
import 'source_selection_screen.dart';
import 'manga_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  final VoidCallback? onBackPressed;
  final bool isMangaMode;

  const SearchScreen({super.key, this.onBackPressed, this.isMangaMode = false});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final JikanService _jikanService = JikanService();
  final GomangService _gomangService = GomangService();
  final FocusNode _searchFocusNode = FocusNode();

  late AnimationController _animationController;
  Timer? _debounce;

  List<String> _searchHistory = [];
  List<String> _suggestions = [];
  List<JikanAnime> _trendingAnimes = [];
  List<JikanAnime> _searchResults = [];
  List<JikanAnime> _recentSearchResults = [];
  List<Map<String, dynamic>> _mangaResults = [];
  List<Map<String, dynamic>> _trendingMangas = [];

  bool _isLoadingTrending = true;
  bool _isSearching = false;
  bool _showHistory = true;

  // Filtros
  int? _selectedGenre;

  List<Map<String, dynamic>> _getGenres() {
    final l10n = AppLocalizations.of(context);
    return [
      {'id': JikanGenreIds.action, 'name': l10n.action, 'icon': Icons.flash_on},
      {
        'id': JikanGenreIds.adventure,
        'name': l10n.adventure,
        'icon': Icons.explore,
      },
      {
        'id': JikanGenreIds.comedy,
        'name': l10n.comedy,
        'icon': Icons.emoji_emotions,
      },
      {
        'id': JikanGenreIds.drama,
        'name': l10n.drama,
        'icon': Icons.theater_comedy,
      },
      {
        'id': JikanGenreIds.fantasy,
        'name': l10n.fantasy,
        'icon': Icons.auto_awesome,
      },
      {
        'id': JikanGenreIds.horror,
        'name': l10n.horror,
        'icon': Icons.dark_mode,
      },
      {'id': JikanGenreIds.mystery, 'name': l10n.mystery, 'icon': Icons.search},
      {
        'id': JikanGenreIds.romance,
        'name': l10n.romance,
        'icon': Icons.favorite,
      },
      {
        'id': JikanGenreIds.sciFi,
        'name': l10n.sciFi,
        'icon': Icons.rocket_launch,
      },
      {
        'id': JikanGenreIds.sliceOfLife,
        'name': l10n.sliceOfLife,
        'icon': Icons.wb_sunny,
      },
      {
        'id': JikanGenreIds.sports,
        'name': l10n.sports,
        'icon': Icons.sports_soccer,
      },
      {
        'id': JikanGenreIds.supernatural,
        'name': l10n.supernatural,
        'icon': Icons.auto_fix_high,
      },
    ];
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animationController.forward();

    _loadSearchHistory();
    if (widget.isMangaMode) {
      _loadTrendingMangas();
    } else {
      _loadTrendingAnimes();
      _loadRecentSearches();
    }

    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    final query = _searchController.text.trim();

    if (query.isEmpty) {
      setState(() {
        _showHistory = true;
        _suggestions = [];
        _searchResults = [];
        _mangaResults = [];
      });
      return;
    }

    setState(() => _showHistory = false);

    // Busca sugestões no histórico
    _loadSuggestions(query);

    // Debounce para busca na API
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _loadSearchHistory() async {
    final history = await SearchHistoryService.getSearchHistory();
    setState(() => _searchHistory = history);
  }

  Future<void> _loadSuggestions(String query) async {
    final suggestions = await SearchHistoryService.getSuggestions(query);
    setState(() => _suggestions = suggestions);
  }

  Future<void> _loadTrendingAnimes() async {
    setState(() => _isLoadingTrending = true);
    try {
      final animes = await _jikanService.getCurrentSeasonAnimes(limit: 12);
      if (mounted) {
        setState(() {
          _trendingAnimes = animes;
          _isLoadingTrending = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading trending animes: $e');
      if (mounted) setState(() => _isLoadingTrending = false);
    }
  }

  Future<void> _loadTrendingMangas() async {
    setState(() => _isLoadingTrending = true);
    try {
      final mangas = await _gomangService.getPopular();
      if (mounted) {
        setState(() {
          _trendingMangas = mangas.cast<Map<String, dynamic>>();
          _isLoadingTrending = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading trending mangas: $e');
      if (mounted) setState(() => _isLoadingTrending = false);
    }
  }

  Future<void> _loadRecentSearches() async {
    final history = await SearchHistoryService.getSearchHistory();
    if (history.isEmpty) return;

    // Busca os últimos 3 animes do histórico
    final recentSearches = history.take(3).toList();
    final List<JikanAnime> results = [];

    for (final query in recentSearches) {
      try {
        await Future.delayed(const Duration(milliseconds: 400)); // Rate limit
        final searchResults = await _jikanService.searchAnimes(query, limit: 1);
        if (searchResults.isNotEmpty) {
          results.add(searchResults.first);
        }
      } catch (e) {
        debugPrint('Error loading recent search: $e');
      }
    }

    if (mounted) {
      setState(() => _recentSearchResults = results);
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) return;

    setState(() => _isSearching = true);

    try {
      if (widget.isMangaMode) {
        // Busca de mangás
        final results = await _gomangService.search(query);
        if (mounted) {
          setState(() {
            _mangaResults = results.cast<Map<String, dynamic>>();
            _isSearching = false;
          });
        }
      } else {
        // Busca de animes
        List<JikanAnime> results;
        if (_selectedGenre != null) {
          results = await _jikanService.searchAnimes(query, limit: 20);
          results = results.where((anime) {
            return anime.genres.any((genre) => genre.malId == _selectedGenre);
          }).toList();
        } else {
          results = await _jikanService.searchAnimes(query, limit: 20);
        }
        if (mounted) {
          setState(() {
            _searchResults = results;
            _isSearching = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error searching: $e');
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _selectSearchQuery(String query) async {
    _searchController.text = query;
    _searchFocusNode.unfocus();

    // Salva no histórico
    await SearchHistoryService.saveSearch(query);
    await _loadSearchHistory();

    // Realiza a busca
    _performSearch(query);
  }

  Future<void> _removeHistoryItem(String query) async {
    await SearchHistoryService.removeSearchItem(query);
    await _loadSearchHistory();
  }

  Future<void> _clearHistory() async {
    await SearchHistoryService.clearHistory();
    await _loadSearchHistory();
    setState(() => _recentSearchResults = []);
  }

  void _selectGenre(int? genreId) {
    setState(() {
      _selectedGenre = genreId;
    });

    if (_searchController.text.isNotEmpty) {
      _performSearch(_searchController.text);
    }
  }

  Future<void> _onAnimeTap(JikanAnime anime) async {
    // Salva no histórico
    await SearchHistoryService.saveSearch(anime.title);

    // Navega para tela de seleção de fonte
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SourceSelectionScreen(
          animeTitle: anime.title,
          imageUrl: anime.imageUrl,
          myAnimeListUrl: 'https://myanimelist.net/anime/${anime.malId}',
        ),
      ),
    );
  }

  void _onMangaTap(Map<String, dynamic> manga) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MangaDetailScreen(manga: manga),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Search Header
            _buildSearchHeader(canPop),

            // Genre Filters (only for anime mode)
            if (!_showHistory && !widget.isMangaMode) _buildGenreFilters(),

            // Content
            Expanded(
              child: _showHistory
                  ? _buildHistoryAndTrending()
                  : _buildSearchResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchHeader(bool canPop) {
    final isVR = Responsive.isQuest(context);
    final horizontalPadding = Responsive.getHorizontalPadding(context);
    final borderRadius = Responsive.getBorderRadius(context);
    final iconSize = Responsive.getIconSize(context);
    final fontSize = Responsive.getFontSize(context);
    final primaryColor = isVR ? AppColors.vrPrimary : AppColors.primary;
    final surfaceColor = isVR ? AppColors.vrSurface : AppColors.surface;
    
    return Container(
      padding: EdgeInsets.all(isVR ? 24 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isVR 
              ? [AppColors.vrSurface, AppColors.vrSurfaceLight]
              : [AppColors.background, AppColors.backgroundLight],
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Back button
              Container(
                decoration: isVR
                    ? BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(borderRadius / 2),
                        border: Border.all(
                          color: AppColors.vrGlow.withValues(alpha: 0.2),
                        ),
                      )
                    : null,
                child: IconButton(
                  icon: Icon(Icons.arrow_back, color: Colors.white, size: iconSize),
                  padding: EdgeInsets.all(isVR ? 12 : 8),
                  onPressed: () {
                    if (canPop) {
                      Navigator.pop(context);
                    } else if (widget.onBackPressed != null) {
                      widget.onBackPressed!();
                    }
                  },
                ),
              ),
              SizedBox(width: isVR ? 16 : 8),

              // Search field (otimizado - sem BackdropFilter)
              Expanded(
                child: Container(
                  constraints: BoxConstraints(minHeight: isVR ? 64 : 48),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(borderRadius),
                    border: Border.all(
                      color: isVR
                          ? AppColors.vrGlow.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.1),
                      width: isVR ? 1.5 : 1,
                    ),
                    boxShadow: isVR
                        ? [
                            BoxShadow(
                              color: AppColors.vrGlow.withValues(alpha: 0.1),
                              blurRadius: 12,
                            ),
                          ]
                        : null,
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    autofocus: true,
                    style: TextStyle(color: Colors.white, fontSize: fontSize),
                    decoration: InputDecoration(
                      hintText: widget.isMangaMode ? 'Buscar mangás...' : 'Search animes...',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: fontSize,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: primaryColor,
                        size: iconSize,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: Colors.white70,
                                size: iconSize,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _showHistory = true;
                                  _searchResults = [];
                                  _mangaResults = [];
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: isVR ? 24 : 16,
                        vertical: isVR ? 18 : 14,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Suggestions
          if (_suggestions.isNotEmpty) ...[
            SizedBox(height: isVR ? 16 : 12),
            SizedBox(
              height: isVR ? 56 : 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _suggestions.length,
                itemBuilder: (context, index) {
                  final suggestion = _suggestions[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(suggestion),
                      labelStyle: const TextStyle(color: Colors.white),
                      backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                      side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.5),
                      ),
                      onPressed: () => _selectSearchQuery(suggestion),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGenreFilters() {
    final l10n = AppLocalizations.of(context);
    final genres = _getGenres();

    return Container(
      height: 50,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: genres.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(l10n.allGenres),
                labelStyle: TextStyle(
                  color: _selectedGenre == null ? Colors.white : Colors.white70,
                  fontWeight: _selectedGenre == null
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
                selected: _selectedGenre == null,
                selectedColor: AppColors.primary,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                onSelected: (_) => _selectGenre(null),
              ),
            );
          }

          final genre = genres[index - 1];
          final isSelected = _selectedGenre == genre['id'];

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              avatar: Icon(
                genre['icon'] as IconData,
                color: isSelected ? Colors.white : Colors.white70,
                size: 18,
              ),
              label: Text(genre['name'] as String),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              selected: isSelected,
              selectedColor: AppColors.primary,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              onSelected: (_) => _selectGenre(genre['id'] as int),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHistoryAndTrending() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Recent Searches (with results) - only for anime mode
        if (!widget.isMangaMode && _recentSearchResults.isNotEmpty) ...[
          _buildSectionHeader('Recent Searches', Icons.history),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _recentSearchResults.length,
              itemBuilder: (context, index) {
                return _buildAnimeCard(_recentSearchResults[index]);
              },
            ),
          ),
          const SizedBox(height: 32),
        ],

        // Search History
        if (_searchHistory.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionHeader('History', Icons.schedule),
              TextButton(
                onPressed: _clearHistory,
                child: const Text(
                  'Clear',
                  style: TextStyle(color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._searchHistory.take(8).map((query) {
            return ListTile(
              leading: const Icon(Icons.history, color: AppColors.primary),
              title: Text(query, style: const TextStyle(color: Colors.white)),
              trailing: IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: () => _removeHistoryItem(query),
              ),
              onTap: () => _selectSearchQuery(query),
            );
          }),
          const SizedBox(height: 32),
        ],

        // Trending
        _buildSectionHeader(
          widget.isMangaMode ? 'Mangás Populares' : 'Trending Now',
          Icons.local_fire_department,
        ),
        const SizedBox(height: 16),
        if (_isLoadingTrending)
          const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          )
        else if (widget.isMangaMode)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: Responsive.getGridColumns(context),
              childAspectRatio: 0.6,
              crossAxisSpacing: Responsive.getCardSpacing(context),
              mainAxisSpacing: Responsive.getCardSpacing(context),
            ),
            itemCount: _trendingMangas.length,
            itemBuilder: (context, index) {
              return _buildGridMangaCard(_trendingMangas[index]);
            },
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: Responsive.getGridColumns(context),
              childAspectRatio: 0.6,
              crossAxisSpacing: Responsive.getCardSpacing(context),
              mainAxisSpacing: Responsive.getCardSpacing(context),
            ),
            itemCount: _trendingAnimes.length,
            itemBuilder: (context, index) {
              return _buildGridAnimeCard(_trendingAnimes[index]);
            },
          ),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (widget.isMangaMode) {
      if (_mangaResults.isEmpty) {
        final l10n = AppLocalizations.of(context);
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 64,
                color: Colors.white.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.noResultsFound,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        );
      }
      return GridView.builder(
        padding: EdgeInsets.all(Responsive.getHorizontalPadding(context)),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: Responsive.getGridColumns(context),
          childAspectRatio: 0.6,
          crossAxisSpacing: Responsive.getCardSpacing(context),
          mainAxisSpacing: Responsive.getCardSpacing(context),
        ),
        itemCount: _mangaResults.length,
        itemBuilder: (context, index) {
          return _buildGridMangaCard(_mangaResults[index]);
        },
      );
    }

    if (_searchResults.isEmpty) {
      final l10n = AppLocalizations.of(context);
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noResultsFound,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.all(Responsive.getHorizontalPadding(context)),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: Responsive.getGridColumns(context),
        childAspectRatio: 0.6,
        crossAxisSpacing: Responsive.getCardSpacing(context),
        mainAxisSpacing: Responsive.getCardSpacing(context),
      ),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        return _buildGridAnimeCard(_searchResults[index]);
      },
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildAnimeCard(JikanAnime anime) {
    return GestureDetector(
      onTap: () => _onAnimeTap(anime),
      child: Container(
        width: 130,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: anime.largImageUrl ?? anime.imageUrl,
                    width: 130,
                    height: 160,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                    memCacheWidth: 390,
                    memCacheHeight: 480,
                    placeholder: (context, url) => Container(
                      color: AppColors.surface,
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  if (anime.score != null)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 12,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              anime.score!.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              anime.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridAnimeCard(JikanAnime anime) {
    return GestureDetector(
      onTap: () => _onAnimeTap(anime),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: anime.largImageUrl ?? anime.imageUrl,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                    memCacheWidth: 450,
                    memCacheHeight: 600,
                    placeholder: (context, url) => Container(
                      color: AppColors.surface,
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  if (anime.score != null)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 10,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              anime.score!.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            anime.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridMangaCard(Map<String, dynamic> manga) {
    return GestureDetector(
      onTap: () => _onMangaTap(manga),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: manga['image'] ?? '',
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                memCacheWidth: 450,
                memCacheHeight: 600,
                placeholder: (context, url) => Container(
                  color: AppColors.surface,
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: AppColors.surface,
                  child: const Icon(Icons.broken_image, color: Colors.white54),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            manga['title'] ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
