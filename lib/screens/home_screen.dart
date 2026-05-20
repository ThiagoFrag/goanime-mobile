import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ionicons/ionicons.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/jikan_models.dart';
import '../services/jikan_service.dart';
import '../services/gomang_service.dart';
import '../services/adult_mode_service.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../main.dart';
import '../utils/responsive.dart';
import '../widgets/shimmer_loading.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'genre_animes_screen.dart';
import 'source_selection_screen.dart';
import 'episode_list_screen.dart';
import 'manga_detail_screen.dart';
import 'manga_browse_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final JikanService _jikanService = JikanService();
  final ScrollController _scrollController = ScrollController();
  final GomangService _gomangService = GomangService();

  late AnimationController _fabAnimationController;

  bool _showFab = false;
  double _headerOpacity = 1.0;
  bool _dataLoaded = false;
  bool _isLoading = true;
  bool _isMangaMode = false;

  // Mangas (quando em modo manga) - diferentes categorias
  List<dynamic> _popularMangas = [];
  List<dynamic> _actionMangas = [];
  List<dynamic> _romanceMangas = [];
  List<dynamic> _fantasyMangas = [];
  List<dynamic> _recentMangas = [];
  List<dynamic> _mangalivreToMangas = [];

  // Listas de animes
  List<JikanAnime> _seasonAnimes = [];
  List<JikanAnime> _topAnimes = [];
  List<JikanAnime> _actionAnimes = [];
  List<JikanAnime> _romanceAnimes = [];
  List<JikanAnime> _comedyAnimes = [];
  List<JikanAnime> _fantasyAnimes = [];

  // Índice do banner atual
  int _currentBannerIndex = 0;
  late PageController _bannerPageController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _bannerPageController = PageController();

    _scrollController.addListener(_onScroll);
    if (!_dataLoaded) {
      _loadAllData();
    }
    // não inicia carregamento de manga automaticamente
    _startBannerRotation();
    // Pre-fetch popular mangas in background so UI shows them quickly when toggled
    _loadMangaData();
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    _scrollController.dispose();
    _bannerPageController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final offset = _scrollController.offset;

    if (offset > 300 && !_showFab) {
      setState(() => _showFab = true);
      _fabAnimationController.forward();
    } else if (offset <= 300 && _showFab) {
      setState(() => _showFab = false);
      _fabAnimationController.reverse();
    }

    final newOpacity = offset > 0 ? 1.0 : 0.0;
    if ((newOpacity - _headerOpacity).abs() > 0.01) {
      setState(() {
        _headerOpacity = newOpacity;
      });
    }
  }

  void _startBannerRotation() {
    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted || !_bannerPageController.hasClients) return;
      final items = _isMangaMode ? _popularMangas : _seasonAnimes;
      if (items.isEmpty) return;
      final length = items.length.clamp(0, 5);
      final nextIndex = (_currentBannerIndex + 1) % length;
      _bannerPageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
      _startBannerRotation();
    });
  }

  /// Carrega TODOS os dados de uma vez usando o método otimizado
  Future<void> _loadAllData({bool forceRefresh = false}) async {
    _dataLoaded = true;

    if (!forceRefresh && _seasonAnimes.isNotEmpty) {
      // Já tem dados, não precisa recarregar
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Carrega tudo de uma vez com o novo método paralelo
      final homeData = await _jikanService.loadHomeData(
        forceRefresh: forceRefresh,
      );

      if (mounted) {
        setState(() {
          _seasonAnimes = homeData.seasonAnimes;
          _topAnimes = homeData.topAnimes;
          _actionAnimes = homeData.actionAnimes;
          _romanceAnimes = homeData.romanceAnimes;
          _comedyAnimes = homeData.comedyAnimes;
          _fantasyAnimes = homeData.fantasyAnimes;
          _isLoading = false;
        });

        // Pre-cache das imagens do banner para transições suaves
        _precacheBannerImages();
      }
    } catch (e) {
      debugPrint('Error loading home data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMangaData({bool forceRefresh = false}) async {
    debugPrint('[MangaLoad] ====== LOADING MANGA DATA ======');
    debugPrint('[MangaLoad] forceRefresh: $forceRefresh, popularMangas.isNotEmpty: ${_popularMangas.isNotEmpty}');
    if (!forceRefresh && _popularMangas.isNotEmpty) {
      debugPrint('[MangaLoad] Skipping - already has data');
      return;
    }
    setState(() => _isLoading = true);
    try {
      debugPrint('[MangaLoad] Starting API calls...');
      // Carrega mangás de forma resiliente - cada chamada trata seus próprios erros
      final popularFuture = _gomangService.getPopular().catchError((e) {
        debugPrint('[MangaLoad] Popular failed: $e');
        return <dynamic>[];
      });
      
      final latestFuture = _gomangService.getLatestUpdates().catchError((e) {
        debugPrint('[MangaLoad] Latest failed: $e');
        return <dynamic>[];
      });
      
      final page2Future = _gomangService.getMangasPage(2).catchError((e) {
        debugPrint('[MangaLoad] Page 2 failed: $e');
        return <dynamic>[];
      });
      
      final page3Future = _gomangService.getMangasPage(3).catchError((e) {
        debugPrint('[MangaLoad] Page 3 failed: $e');
        return <dynamic>[];
      });

      final results = await Future.wait([
        popularFuture,
        latestFuture, 
        page2Future,
        page3Future,
      ]);

      debugPrint('[MangaLoad] All futures completed');
      debugPrint('[MangaLoad] Results count: ${results.length}');

      if (mounted) {
        final popular = results[0];
        final latest = results[1];
        final page2 = results[2];
        final page3 = results[3];
        
        debugPrint('[MangaLoad] Popular: ${popular.length}, Latest: ${latest.length}, Page2: ${page2.length}, Page3: ${page3.length}');
        
        // Criar categorias a partir dos resultados disponíveis
        // Usar shuffles e slices para simular diferentes categorias
        final allMangas = [...popular, ...page2, ...page3];
        final uniqueMangas = <String, dynamic>{};
        for (final m in allMangas) {
          final id = (m as Map<String, dynamic>)['id'] ?? m['url'] ?? '';
          if (!uniqueMangas.containsKey(id)) {
            uniqueMangas[id] = m;
          }
        }
        final mangaList = uniqueMangas.values.toList();
        
        // Distribuir mangás entre categorias
        final midPoint = mangaList.length ~/ 2;
        final quarter = mangaList.length ~/ 4;
        
        setState(() {
          _popularMangas = popular.isNotEmpty ? popular : mangaList.take(10).toList();
          _mangalivreToMangas = mangaList.length > quarter 
              ? mangaList.sublist(0, quarter).toList()
              : mangaList.take(5).toList();
          _actionMangas = mangaList.length > midPoint 
              ? mangaList.sublist(quarter, midPoint).toList()
              : mangaList.skip(5).take(5).toList();
          _romanceMangas = mangaList.length > (midPoint + quarter)
              ? mangaList.sublist(midPoint, midPoint + quarter).toList()
              : mangaList.skip(10).take(5).toList();
          _fantasyMangas = mangaList.length > midPoint + quarter
              ? mangaList.sublist(midPoint + quarter).toList()
              : mangaList.skip(15).take(5).toList();
          _recentMangas = latest.isNotEmpty ? latest : mangaList.reversed.take(10).toList();
          _isLoading = false;
        });
        // Pre-cache first banner images for smooth transitions
        _precacheBannerImages();
      }
    } catch (e, st) {
      debugPrint('Error loading mangas: $e\n$st');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro carregando mangas: $e')));
      }
    }
  }

  /// Pre-carrega imagens do banner para transições mais suaves
  void _precacheBannerImages() {
    final items = _isMangaMode ? _popularMangas.take(5) : _seasonAnimes.take(5);
    for (final item in items) {
      String? imageUrl;
      if (_isMangaMode) {
        final m = item as Map<String, dynamic>;
        imageUrl = m['image'] as String?;
      } else {
        final anime = item as JikanAnime;
        imageUrl = anime.largImageUrl ?? anime.imageUrl;
      }
      if (imageUrl != null && imageUrl.isNotEmpty) {
        precacheImage(CachedNetworkImageProvider(imageUrl), context);
      }
    }
  }

  void _onAnimeTap(JikanAnime anime) {
    _openAnimeDirectly(anime);
  }

  Future<void> _openAnimeDirectly(JikanAnime anime) async {
    // Try to auto-find the best source and open episodes directly.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final results = await AnimeService.searchAnime(anime.title);

      if (!mounted) return;

      // Prefer AnimeFire, then first available result
      Anime? selected;
      final fireMatches = results
          .where((a) => a.source == AnimeSource.animeFire)
          .toList();
      if (fireMatches.isNotEmpty) {
        selected = fireMatches.first;
      } else if (results.isNotEmpty) {
        selected = results.first;
      } else {
        selected = null;
      }

      if (selected == null) {
        if (!mounted) return;
        Navigator.pop(context); // close progress
        // fallback to selection screen
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
        return;
      }

      await AnimeService.enrichAnimeWithAniList(selected);
      if (!mounted) return;
      Navigator.pop(context); // close progress
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ModernEpisodeListScreen(anime: selected!),
        ),
      );
    } catch (e) {
      Navigator.pop(context); // close progress
      debugPrint('Auto-open anime failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível abrir o anime: $e')),
        );
      }
    }
  }

  /// Filtra mangás usando o serviço de modo adulto
  List<dynamic> _filterMangaList(List<dynamic> mangas) {
    final adultService = Provider.of<AdultModeService>(context, listen: false);
    final filtered = adultService.filterMangaList(mangas);
    // Debug log para ver quantos mangás foram filtrados
    if (mangas.length != filtered.length) {
      debugPrint(
        '[AdultFilter] Filtrou ${mangas.length - filtered.length} mangás adultos de ${mangas.length}',
      );
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Requerido por AutomaticKeepAliveClientMixin
    final l10n = AppLocalizations.of(context);
    // Watch adult mode changes to rebuild
    context.watch<AdultModeService>();

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: () => _isMangaMode
            ? _loadMangaData(forceRefresh: true)
            : _loadAllData(forceRefresh: true),
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Banner Hero com Parallax
            if (_isMangaMode
                ? _popularMangas.isNotEmpty
                : _seasonAnimes.isNotEmpty)
              SliverToBoxAdapter(child: _buildHeroBannerCarousel()),

            // Conteúdo principal
            SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: 24),

                  // Seção principal (anime ou manga)
                  if (!_isMangaMode)
                    _buildModernSection(
                      title: l10n.seasonHighlights,
                      icon: Ionicons.trending_up_outline,
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.secondary],
                      ),
                      animes: _seasonAnimes,
                      isLoading: _isLoading && _seasonAnimes.isEmpty,
                      sectionId: 'season',
                      genreId: null,
                    )
                  else
                    _buildModernMangaSection(
                      title: '🔥 Destaques',
                      icon: Ionicons.trending_up_outline,
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.secondary],
                      ),
                      mangas: _filterMangaList(_popularMangas),
                      isLoading: _isLoading && _popularMangas.isEmpty,
                      sectionId: 'popular',
                    ),

                  // Sections: show anime lists in anime mode, or manga lists in manga mode
                  // Seção: Top / Em Alta
                  _isMangaMode
                      ? _buildModernMangaSection(
                          title: '⭐ Em Alta',
                          icon: LucideIcons.trophy,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFD93D), Color(0xFFFFA500)],
                          ),
                          mangas: _filterMangaList(_mangalivreToMangas),
                          isLoading: _isLoading && _mangalivreToMangas.isEmpty,
                          sectionId: 'top',
                        )
                      : _buildModernSection(
                          title: l10n.topAnime,
                          icon: LucideIcons.trophy,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFD93D), Color(0xFFFFA500)],
                          ),
                          animes: _topAnimes,
                          isLoading: _isLoading && _topAnimes.isEmpty,
                          sectionId: 'top',
                          genreId: null,
                        ),

                  // Seção: Ação
                  _isMangaMode
                      ? _buildModernMangaSection(
                          title: '⚔️ Ação',
                          icon: LucideIcons.swords,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                          ),
                          mangas: _filterMangaList(_actionMangas),
                          isLoading: _isLoading && _actionMangas.isEmpty,
                          sectionId: 'action',
                        )
                      : _buildModernSection(
                          title: l10n.action,
                          icon: LucideIcons.swords,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                          ),
                          animes: _actionAnimes,
                          isLoading: _isLoading && _actionAnimes.isEmpty,
                          sectionId: 'action',
                          genreId: JikanGenreIds.action,
                        ),

                  // Seção: Romance
                  _isMangaMode
                      ? _buildModernMangaSection(
                          title: '💕 Romance',
                          icon: LucideIcons.heart,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF6B9D), Color(0xFFC44569)],
                          ),
                          mangas: _filterMangaList(_romanceMangas),
                          isLoading: _isLoading && _romanceMangas.isEmpty,
                          sectionId: 'romance',
                        )
                      : _buildModernSection(
                          title: l10n.romance,
                          icon: LucideIcons.heart,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF6B9D), Color(0xFFC44569)],
                          ),
                          animes: _romanceAnimes,
                          isLoading: _isLoading && _romanceAnimes.isEmpty,
                          sectionId: 'romance',
                          genreId: JikanGenreIds.romance,
                        ),

                  // Seção: Recentes / Comédia
                  _isMangaMode
                      ? _buildModernMangaSection(
                          title: '📚 Recentes',
                          icon: LucideIcons.clock,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00D2FF), Color(0xFF3A7BD5)],
                          ),
                          mangas: _filterMangaList(_recentMangas),
                          isLoading: _isLoading && _recentMangas.isEmpty,
                          sectionId: 'recent',
                        )
                      : _buildModernSection(
                          title: l10n.comedy,
                          icon: LucideIcons.laugh,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00D2FF), Color(0xFF3A7BD5)],
                          ),
                          animes: _comedyAnimes,
                          isLoading: _isLoading && _comedyAnimes.isEmpty,
                          sectionId: 'comedy',
                          genreId: JikanGenreIds.comedy,
                        ),

                  // Seção: Fantasia
                  _isMangaMode
                      ? _buildModernMangaSection(
                          title: '✨ Fantasia',
                          icon: LucideIcons.wand2,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                          ),
                          mangas: _filterMangaList(_fantasyMangas),
                          isLoading: _isLoading && _fantasyMangas.isEmpty,
                          sectionId: 'fantasy',
                        )
                      : _buildModernSection(
                          title: l10n.fantasy,
                          icon: LucideIcons.wand2,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                          ),
                          animes: _fantasyAnimes,
                          isLoading: _isLoading && _fantasyAnimes.isEmpty,
                          sectionId: 'fantasy',
                          genreId: JikanGenreIds.fantasy,
                        ),

                  const SizedBox(height: 48),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _showFab
          ? ScaleTransition(
              scale: _fabAnimationController,
              child: FloatingActionButton(
                onPressed: () {
                  _scrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                  );
                },
                backgroundColor: AppColors.primary,
                child: const Icon(Icons.arrow_upward, color: Colors.white),
              ),
            )
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _headerOpacity > 0
          ? AppColors.background.withValues(alpha: 0.95)
          : Colors.transparent,
      elevation: 0,
      toolbarHeight: 64,
      flexibleSpace: _headerOpacity > 0
          ? Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.background,
                    AppColors.background.withValues(alpha: 0.0),
                  ],
                ),
              ),
            )
          : null,
      title: GestureDetector(
        onTap: () {
          // Toggle entre modo anime e manga
          setState(() {
            _isMangaMode = !_isMangaMode;
            _isLoading = true;
          });
          if (_isMangaMode) {
            _loadMangaData(forceRefresh: true);
          } else {
            _loadAllData(forceRefresh: false);
          }
        },
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _isMangaMode
                  ? [
                      const Color(0xFF6C5CE7),
                      const Color(0xFFA29BFE),
                    ] // Roxo para manga
                  : [
                      AppColors.primary,
                      AppColors.primaryDark,
                    ], // Azul para anime
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color:
                    (_isMangaMode ? const Color(0xFF6C5CE7) : AppColors.primary)
                        .withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            _isMangaMode ? Icons.menu_book : Icons.play_circle_filled,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
      centerTitle: true,
      actions: [
        // Browse extensions button - only in manga mode
        if (_isMangaMode)
          IconButton(
            icon: const Icon(Icons.extension, color: Colors.white, size: 24),
            tooltip: 'Extensões',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MangaBrowseScreen(),
                ),
              );
            },
          ),
        IconButton(
          icon: const Icon(Icons.search, color: Colors.white, size: 24),
          tooltip: 'Search',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SearchScreen(isMangaMode: _isMangaMode),
              ),
            );
          },
        ),
        IconButton(
          icon: const Icon(
            Icons.settings_outlined,
            color: Colors.white,
            size: 24,
          ),
          tooltip: 'Settings',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            );
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildHeroBannerCarousel() {
    final bannerItems = _isMangaMode
        ? _filterMangaList(_popularMangas).take(5).toList()
        : _seasonAnimes.take(5).toList();

    return AnimatedOpacity(
      opacity: bannerItems.isEmpty ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 500),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Responsive banner height
          final bannerHeight = Responsive.getBannerHeight(context);
          final padding = Responsive.getHorizontalPadding(context);

          // Ajuste para diferentes dispositivos
          final bannerTopMargin = Responsive.value(
            context,
            phone: 106.0,
            tablet: 100.0,
            quest: 90.0,
          );

          return Container(
            height: bannerHeight,
            margin: EdgeInsets.only(top: bannerTopMargin, bottom: 12),
            child: Stack(
              children: [
                // PageView with rounded corners
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: padding),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        Responsive.value(
                          context,
                          phone: 20.0,
                          tablet: 24.0,
                          quest: 28.0,
                        ),
                      ),
                      child: PageView.builder(
                        controller: _bannerPageController,
                        onPageChanged: (index) {
                          setState(() {
                            _currentBannerIndex = index;
                          });
                        },
                        itemCount: bannerItems.length,
                        itemBuilder: (context, index) {
                          if (_isMangaMode) {
                            final m =
                                bannerItems[index] as Map<String, dynamic>;
                            return _buildMangaBannerItem(m);
                          }
                          final anime = bannerItems[index] as JikanAnime;
                          return _buildBannerItem(anime);
                        },
                      ),
                    ),
                  ),
                ),

                // Dot indicators
                Positioned(
                  bottom: 12,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      bannerItems.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: _currentBannerIndex == index ? 20 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _currentBannerIndex == index
                              ? AppColors.primary
                              : Colors.white.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: _currentBannerIndex == index
                              ? [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.5,
                                    ),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMangaBannerItem(Map<String, dynamic> manga) {
    final latestChapter = manga['latestChapter'] ?? '';
    final author = manga['author'] ?? '';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MangaDetailScreen(manga: manga),
          ),
        );
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: manga['image'] ?? '',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              memCacheWidth: 1200,
              memCacheHeight: 1600,
              placeholder: (context, url) => Container(
                color: AppColors.surface,
                child: const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: AppColors.surface,
                child: const Icon(Icons.error, color: Colors.white54),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.3),
                    Colors.black.withValues(alpha: 0.8),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          // Badge de capítulo (top-left)
          if (latestChapter.toString().isNotEmpty)
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.secondary],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.book, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      latestChapter.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Informações do manga (bottom)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Título
                Text(
                  manga['title'] ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        offset: Offset(0, 2),
                        blurRadius: 8,
                        color: Colors.black54,
                      ),
                    ],
                    letterSpacing: 0.3,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                // Autor e botão ler
                Row(
                  children: [
                    if (author.toString().isNotEmpty)
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(
                              Icons.person,
                              color: Colors.white70,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                author.toString(),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.menu_book,
                            color: AppColors.primary,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Ler',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerItem(JikanAnime anime) {
    return GestureDetector(
      onTap: () => _onAnimeTap(anime),
      child: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: anime.largImageUrl ?? anime.imageUrl,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              memCacheWidth: 1200,
              memCacheHeight: 1600,
              maxWidthDiskCache: 1200,
              maxHeightDiskCache: 1600,
              placeholder: (context, url) => Container(
                color: AppColors.surface,
                child: const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: AppColors.surface,
                child: const Icon(Icons.error, color: Colors.white54),
              ),
            ),
          ),

          // Subtle gradient overlay (Apple-style - more subtle)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.2),
                    Colors.black.withValues(alpha: 0.6),
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),
          ),

          // Title overlay
          Positioned(
            bottom: 10,
            left: 12,
            right: 12,
            child: Text(
              anime.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                shadows: [
                  Shadow(
                    offset: Offset(0, 1),
                    blurRadius: 4,
                    color: Colors.black45,
                  ),
                ],
                letterSpacing: 0.2,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernSection({
    required String title,
    required IconData icon,
    required Gradient gradient,
    required List<JikanAnime> animes,
    required bool isLoading,
    String? sectionId,
    int? genreId,
  }) {
    final l10n = AppLocalizations.of(context);
    final horizontalPadding = Responsive.getHorizontalPadding(context);
    final sectionHeight = Responsive.getSectionHeight(context);
    final titleSize = Responsive.getSectionTitleSize(context);

    return AnimatedOpacity(
      opacity: isLoading ? 0.6 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        margin: const EdgeInsets.only(bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho da seção (simplificado para performance)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Row(
                children: [
                  // Ícone da seção (simplificado para performance)
                  Container(
                    padding: EdgeInsets.all(
                      Responsive.value(context, phone: 9.0, tablet: 11.0),
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          gradient.colors.first.withValues(alpha: 0.3),
                          gradient.colors.last.withValues(alpha: 0.2),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: gradient.colors.first.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      icon,
                      color: Colors.white,
                      size: Responsive.value(
                        context,
                        phone: 19.0,
                        tablet: 22.0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: titleSize,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Botão "Ver todos" simplificado
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GenreAnimesScreen(
                              title: title,
                              icon: icon,
                              gradient: gradient,
                              genreId: genreId,
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.seeAll,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.arrow_forward_ios,
                              color: AppColors.primary,
                              size: 11,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Lista de animes (otimizada - responsiva)
            SizedBox(
              height: sectionHeight,
              child: isLoading
                  ? _buildLoadingCards()
                  : animes.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                      ),
                      itemCount: animes.length,
                      cacheExtent: 500, // Pre-render cards para scroll suave
                      itemBuilder: (context, index) {
                        return _buildModernAnimeCard(
                          animes[index],
                          gradient,
                          sectionId ?? title,
                          index,
                          showScore: sectionId != 'season',
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernAnimeCard(
    JikanAnime anime,
    Gradient gradient,
    String sectionId,
    int index, {
    bool showScore = true,
  }) {
    final cardWidth = Responsive.getHorizontalListItemWidth(context);
    final cardHeight = Responsive.getCardHeight(context);
    final spacing = Responsive.getCardSpacing(context);

    return _AnimatedAnimeCard(
      anime: anime,
      cardWidth: cardWidth,
      cardHeight: cardHeight,
      spacing: spacing,
      sectionId: sectionId,
      index: index,
      showScore: showScore,
      onTap: () => _onAnimeTap(anime),
    );
  }

  /// Seção moderna de mangás - espelhando o visual de anime
  Widget _buildModernMangaSection({
    required String title,
    required IconData icon,
    required Gradient gradient,
    required List<dynamic> mangas,
    required bool isLoading,
    required String sectionId,
  }) {
    final horizontalPadding = Responsive.getHorizontalPadding(context);
    final sectionHeight = Responsive.getSectionHeight(context);
    final titleSize = Responsive.getSectionTitleSize(context);

    return AnimatedOpacity(
      opacity: isLoading ? 0.6 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        margin: const EdgeInsets.only(bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho da seção (estilo moderno igual ao anime)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Row(
                children: [
                  // Ícone da seção
                  Container(
                    padding: EdgeInsets.all(
                      Responsive.value(context, phone: 9.0, tablet: 11.0),
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          gradient.colors.first.withValues(alpha: 0.3),
                          gradient.colors.last.withValues(alpha: 0.2),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: gradient.colors.first.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      icon,
                      color: Colors.white,
                      size: Responsive.value(
                        context,
                        phone: 19.0,
                        tablet: 22.0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: titleSize,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Badge com quantidade
                  if (mangas.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        gradient: gradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: gradient.colors.first.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '${mangas.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Lista de mangás
            SizedBox(
              height: sectionHeight,
              child: isLoading
                  ? _buildLoadingCards()
                  : mangas.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                      ),
                      itemCount: mangas.length,
                      cacheExtent: 500,
                      itemBuilder: (context, index) {
                        final m = mangas[index] as Map<String, dynamic>;
                        return _buildModernMangaCard(
                          m,
                          gradient,
                          index,
                          sectionId,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Card moderno de manga com animação
  Widget _buildModernMangaCard(
    Map<String, dynamic> manga,
    Gradient gradient,
    int index,
    String sectionId,
  ) {
    final cardWidth = Responsive.getHorizontalListItemWidth(context);
    final cardHeight = Responsive.getCardHeight(context);
    final spacing = Responsive.getCardSpacing(context);

    return _AnimatedMangaCard(
      manga: manga,
      cardWidth: cardWidth,
      cardHeight: cardHeight,
      spacing: spacing,
      gradient: gradient,
      index: index,
      sectionId: sectionId,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MangaDetailScreen(manga: manga),
          ),
        );
      },
    );
  }

  Widget _buildLoadingCards() {
    final cardWidth = Responsive.getHorizontalListItemWidth(context);
    final cardHeight = Responsive.getCardHeight(context);
    final spacing = Responsive.getCardSpacing(context);
    final padding = Responsive.getHorizontalPadding(context);

    return ShimmerAnimeList(
      itemWidth: cardWidth,
      itemHeight: cardHeight,
      spacing: spacing,
      padding: EdgeInsets.symmetric(horizontal: padding),
    );
  }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Text(
        l10n.noAnimeFound,
        style: const TextStyle(color: Colors.white54),
      ),
    );
  }
}

/// Card de anime com animação suave e moderna
class _AnimatedAnimeCard extends StatefulWidget {
  final JikanAnime anime;
  final double cardWidth;
  final double cardHeight;
  final double spacing;
  final String sectionId;
  final int index;
  final bool showScore;
  final VoidCallback onTap;

  const _AnimatedAnimeCard({
    required this.anime,
    required this.cardWidth,
    required this.cardHeight,
    required this.spacing,
    required this.sectionId,
    required this.index,
    required this.showScore,
    required this.onTap,
  });

  @override
  State<_AnimatedAnimeCard> createState() => _AnimatedAnimeCardState();
}

class _AnimatedAnimeCardState extends State<_AnimatedAnimeCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isPressed = false;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // VR responsive values
    final isVR = Responsive.isQuest(context);
    final borderRadius = Responsive.getBorderRadius(context);
    final primaryColor = isVR ? AppColors.vrPrimary : AppColors.primary;
    final surfaceColor = isVR ? AppColors.vrSurface : AppColors.surface;

    // RepaintBoundary isola o card para evitar repaint de toda a lista
    return RepaintBoundary(
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) {
          setState(() => _isPressed = true);
          _scaleController.forward();
        },
        onTapUp: (_) {
          setState(() => _isPressed = false);
          _scaleController.reverse();
        },
        onTapCancel: () {
          setState(() => _isPressed = false);
          _scaleController.reverse();
        },
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) => Transform.scale(
              scale: _isPressed ? _scaleAnimation.value : (_isHovered ? 1.03 : 1.0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                width: widget.cardWidth,
                margin: EdgeInsets.only(right: widget.spacing),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Card com imagem (otimizado)
                Hero(
                  tag:
                      'anime_${widget.sectionId}_${widget.anime.malId}_${widget.index}',
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: widget.cardHeight,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(borderRadius),
                      border: isVR && _isHovered
                          ? Border.all(
                              color: AppColors.vrGlow.withValues(alpha: 0.5),
                              width: 2,
                            )
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: _isHovered
                              ? primaryColor.withValues(alpha: isVR ? 0.5 : 0.35)
                              : Colors.black.withValues(alpha: 0.3),
                          blurRadius: _isHovered ? (isVR ? 20 : 14) : 8,
                          spreadRadius: isVR && _isHovered ? 2 : 0,
                          offset: Offset(0, _isHovered ? 6 : 4),
                        ),
                        // VR glow effect
                        if (isVR && _isHovered)
                          BoxShadow(
                            color: AppColors.vrGlow.withValues(alpha: 0.2),
                            blurRadius: 24,
                            spreadRadius: 4,
                          ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Imagem (cache otimizado 2x para retina)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(borderRadius),
                          child: CachedNetworkImage(
                            imageUrl:
                                widget.anime.largImageUrl ??
                                widget.anime.imageUrl,
                            width: widget.cardWidth,
                            height: widget.cardHeight,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.high,
                            memCacheWidth: (widget.cardWidth * 3).toInt(),
                            memCacheHeight: (widget.cardHeight * 3).toInt(),
                            placeholder: (context, url) => Container(
                              color: surfaceColor,
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: primaryColor,
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: surfaceColor,
                              child: const Icon(
                                Icons.error,
                                color: Colors.white54,
                              ),
                            ),
                          ),
                        ),

                        // Gradient overlay simples (sem blur)
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(borderRadius),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.7),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Score badge simples (sem blur para performance)
                        if (widget.showScore && widget.anime.score != null)
                          Positioned(
                            top: isVR ? 12 : 8,
                            right: isVR ? 12 : 8,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isVR ? 12 : 8,
                                vertical: isVR ? 6 : 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(isVR ? 16 : 12),
                                border: Border.all(
                                  color: isVR
                                      ? AppColors.vrGlow.withValues(alpha: 0.3)
                                      : Colors.white.withValues(alpha: 0.2),
                                  width: 1,
                                ),
                                boxShadow: isVR
                                    ? [
                                        BoxShadow(
                                          color: AppColors.vrGlow.withValues(alpha: 0.2),
                                          blurRadius: 8,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.star,
                                    color: Colors.amber,
                                    size: isVR ? 16 : 12,
                                  ),
                                  SizedBox(width: isVR ? 4 : 2),
                                  Text(
                                    widget.anime.score!.toStringAsFixed(1),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: isVR ? 14 : 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // Hover overlay
                        if (_isHovered)
                          Positioned.fill(
                            child: AnimatedOpacity(
                              opacity: _isHovered ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 150),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(borderRadius),
                                  border: Border.all(
                                    color: primaryColor.withValues(
                                      alpha: 0.5,
                                    ),
                                    width: isVR ? 3 : 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        // Quick view button (makes the card action obvious)
                        Positioned(
                          top: isVR ? 12 : 8,
                          left: isVR ? 12 : 8,
                          child: Material(
                            color: Colors.black.withValues(alpha: 0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(isVR ? 12 : 8),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(isVR ? 12 : 8),
                              onTap: widget.onTap,
                              child: Padding(
                                padding: EdgeInsets.all(isVR ? 10.0 : 6.0),
                                child: Icon(
                                  Icons.play_arrow,
                                  color: Colors.white,
                                  size: isVR ? 28 : 18,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: isVR ? 12 : 8),

                // Título
                Text(
                  widget.anime.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isVR 
                        ? 18.0 
                        : Responsive.value(
                            context,
                            phone: 13.0,
                            tablet: 14.0,
                          ),
                    fontWeight: isVR ? FontWeight.w700 : FontWeight.w600,
                    height: 1.3,
                    letterSpacing: isVR ? 0.3 : 0,
                  ),
                ),
              ],
            ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Card de manga com animação suave e moderna (espelha anime)
class _AnimatedMangaCard extends StatefulWidget {
  final Map<String, dynamic> manga;
  final double cardWidth;
  final double cardHeight;
  final double spacing;
  final Gradient gradient;
  final int index;
  final String sectionId;
  final VoidCallback onTap;

  const _AnimatedMangaCard({
    required this.manga,
    required this.cardWidth,
    required this.cardHeight,
    required this.spacing,
    required this.gradient,
    required this.index,
    required this.sectionId,
    required this.onTap,
  });

  @override
  State<_AnimatedMangaCard> createState() => _AnimatedMangaCardState();
}

class _AnimatedMangaCardState extends State<_AnimatedMangaCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isPressed = false;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final latestChapter = widget.manga['latestChapter'] ?? '';
    final source = widget.manga['source'] ?? '';

    // VR responsive values
    final isVR = Responsive.isQuest(context);
    final borderRadius = Responsive.getBorderRadius(context);
    final primaryColor = isVR ? AppColors.vrPrimary : AppColors.primary;
    final surfaceColor = isVR ? AppColors.vrSurface : AppColors.surface;

    return RepaintBoundary(
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) {
          setState(() => _isPressed = true);
          _scaleController.forward();
        },
        onTapUp: (_) {
          setState(() => _isPressed = false);
          _scaleController.reverse();
        },
        onTapCancel: () {
          setState(() => _isPressed = false);
          _scaleController.reverse();
        },
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) => Transform.scale(
              scale: _isPressed ? _scaleAnimation.value : (_isHovered ? 1.03 : 1.0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                width: widget.cardWidth,
                margin: EdgeInsets.only(right: widget.spacing),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Card com imagem
                    Hero(
                      tag:
                      'manga_${widget.sectionId}_${widget.manga['id'] ?? widget.index}_${widget.index}',
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: widget.cardHeight,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(borderRadius),
                      border: isVR && _isHovered
                          ? Border.all(
                              color: AppColors.vrGlow.withValues(alpha: 0.5),
                              width: 2,
                            )
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: _isHovered
                              ? (isVR ? AppColors.vrSecondary : widget.gradient.colors.first)
                                  .withValues(alpha: isVR ? 0.5 : 0.35)
                              : Colors.black.withValues(alpha: 0.3),
                          blurRadius: _isHovered ? (isVR ? 20 : 14) : 8,
                          spreadRadius: isVR && _isHovered ? 2 : 0,
                          offset: Offset(0, _isHovered ? 6 : 4),
                        ),
                        if (isVR && _isHovered)
                          BoxShadow(
                            color: AppColors.vrSecondary.withValues(alpha: 0.2),
                            blurRadius: 24,
                            spreadRadius: 4,
                          ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Imagem
                        ClipRRect(
                          borderRadius: BorderRadius.circular(borderRadius),
                          child: CachedNetworkImage(
                            imageUrl: widget.manga['image'] ?? '',
                            width: widget.cardWidth,
                            height: widget.cardHeight,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.high,
                            memCacheWidth: (widget.cardWidth * 3).toInt(),
                            memCacheHeight: (widget.cardHeight * 3).toInt(),
                            placeholder: (context, url) => Container(
                              color: surfaceColor,
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: primaryColor,
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: surfaceColor,
                              child: const Icon(
                                Icons.broken_image,
                                color: Colors.white54,
                              ),
                            ),
                          ),
                        ),

                        // Gradient overlay
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(borderRadius),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.7),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Latest chapter badge (top-left)
                        if (latestChapter.toString().isNotEmpty)
                          Positioned(
                            top: isVR ? 12 : 8,
                            left: isVR ? 12 : 8,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isVR ? 12 : 8,
                                vertical: isVR ? 6 : 4,
                              ),
                              decoration: BoxDecoration(
                                gradient: isVR
                                    ? LinearGradient(colors: AppColors.vrCardGradient)
                                    : widget.gradient,
                                borderRadius: BorderRadius.circular(isVR ? 14 : 10),
                                boxShadow: [
                                  BoxShadow(
                                    color: (isVR ? AppColors.vrSecondary : widget.gradient.colors.first)
                                        .withValues(alpha: 0.4),
                                    blurRadius: isVR ? 8 : 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                latestChapter.toString(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isVR ? 13 : 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),

                        // Source badge (top-right)
                        if (source.toString().isNotEmpty)
                          Positioned(
                            top: isVR ? 12 : 8,
                            right: isVR ? 12 : 8,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isVR ? 12 : 8,
                                vertical: isVR ? 6 : 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(isVR ? 14 : 10),
                                border: Border.all(
                                  color: isVR
                                      ? AppColors.vrGlow.withValues(alpha: 0.3)
                                      : Colors.white.withValues(alpha: 0.2),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                source.toString().replaceAll('mangalivre.', ''),
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: isVR ? 12 : 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),

                        // Hover overlay
                        if (_isHovered)
                          Positioned.fill(
                            child: AnimatedOpacity(
                              opacity: _isHovered ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 150),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: widget.gradient.colors.first
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: widget.gradient.colors.first
                                        .withValues(alpha: 0.5),
                                    width: isVR ? 3 : 2,
                                  ),
                                ),
                              ),
                            ),
                          ),

                        // Read button
                        Positioned(
                          bottom: isVR ? 12 : 8,
                          right: isVR ? 12 : 8,
                          child: Material(
                            color: (isVR ? AppColors.vrSecondary : widget.gradient.colors.first)
                                .withValues(alpha: 0.8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(isVR ? 12 : 8),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(isVR ? 12 : 8),
                              onTap: widget.onTap,
                              child: Padding(
                                padding: EdgeInsets.all(isVR ? 10.0 : 6.0),
                                child: Icon(
                                  Icons.menu_book,
                                  color: Colors.white,
                                  size: isVR ? 24 : 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: isVR ? 12 : 8),

                // Título
                Text(
                  widget.manga['title'] ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isVR 
                        ? 18.0 
                        : Responsive.value(
                            context,
                            phone: 13.0,
                            tablet: 14.0,
                          ),
                    fontWeight: isVR ? FontWeight.w700 : FontWeight.w600,
                    height: 1.3,
                    letterSpacing: isVR ? 0.3 : 0,
                  ),
                ),
              ],
            ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
