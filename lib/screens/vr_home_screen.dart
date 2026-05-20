import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/icons_compat.dart';
import '../models/jikan_models.dart';
import '../services/jikan_service.dart';
import '../services/gomang_service.dart';
import '../theme/app_colors.dart';
import '../widgets/shimmer_loading.dart';
import 'source_selection_screen.dart';
import 'manga_detail_screen.dart';
import 'search_screen.dart';
import 'downloads_screen.dart';
import 'settings_screen.dart';
import 'watchlist_screen.dart';

/// Tela principal imersiva para Meta Quest VR
/// Layout horizontal com navegação lateral e efeitos 3D
class VRHomeScreen extends StatefulWidget {
  const VRHomeScreen({super.key});

  @override
  State<VRHomeScreen> createState() => _VRHomeScreenState();
}

class _VRHomeScreenState extends State<VRHomeScreen>
    with TickerProviderStateMixin {
  final JikanService _jikanService = JikanService();
  final GomangService _gomangService = GomangService();
  final ScrollController _scrollController = ScrollController();

  // Animações
  late AnimationController _backgroundController;
  late AnimationController _cardHoverController;
  late Animation<double> _backgroundAnimation;

  // Estado
  int _selectedNavIndex = 0;
  int _hoveredCardIndex = -1;
  bool _isLoading = true;
  JikanAnime? _featuredAnime;

  // Dados
  List<JikanAnime> _trendingAnimes = [];
  List<JikanAnime> _topAnimes = [];
  List<JikanAnime> _actionAnimes = [];
  List<Map<String, dynamic>> _popularMangas = [];

  // Navegação lateral
  final List<_VRNavItem> _navItems = [
    _VRNavItem(icon: Ionicons.home, label: 'Início', color: AppColors.vrPrimary),
    _VRNavItem(icon: Ionicons.search, label: 'Buscar', color: AppColors.vrSecondary),
    _VRNavItem(icon: Ionicons.bookmark, label: 'Lista', color: AppColors.vrAccent),
    _VRNavItem(icon: Ionicons.download, label: 'Downloads', color: AppColors.vrPrimary),
    _VRNavItem(icon: Ionicons.settings, label: 'Config', color: AppColors.vrSecondary),
  ];

  @override
  void initState() {
    super.initState();

    // Animação do background (parallax sutil)
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
    _backgroundAnimation = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      _backgroundController,
    );

    // Animação de hover dos cards
    _cardHoverController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _loadData();
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _cardHoverController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _jikanService.getCurrentSeasonAnimes(limit: 15),
        _jikanService.getTopAnimes(limit: 15),
        _jikanService.getAnimesByGenre(1, limit: 15), // Action
        _gomangService.getPopular(source: 'mangalivre.blog'),
      ]);

      setState(() {
        _trendingAnimes = results[0] as List<JikanAnime>;
        _topAnimes = results[1] as List<JikanAnime>;
        _actionAnimes = results[2] as List<JikanAnime>;
        _popularMangas = results[3] as List<Map<String, dynamic>>;

        if (_trendingAnimes.isNotEmpty) {
          _featuredAnime = _trendingAnimes.first;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _onNavTap(int index) {
    if (index == _selectedNavIndex) return;

    if (index == 1) {
      // Buscar
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SearchScreen()),
      );
      return;
    }
    if (index == 2) {
      // Watchlist
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const WatchlistScreen()),
      );
      return;
    }
    if (index == 3) {
      // Downloads
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DownloadsScreen()),
      );
      return;
    }
    if (index == 4) {
      // Settings
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
      );
      return;
    }

    setState(() => _selectedNavIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      body: Stack(
        children: [
          // Background animado com gradientes
          _buildAnimatedBackground(),

          // Conteúdo principal
          Row(
            children: [
              // Navegação lateral 3D
              _buildSideNav(),

              // Área principal
              Expanded(
                child: _isLoading ? _buildLoadingState() : _buildMainContent(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Background com efeito de partículas e gradiente animado
  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _backgroundAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(
                math.cos(_backgroundAnimation.value) * 0.3,
                math.sin(_backgroundAnimation.value) * 0.3,
              ),
              radius: 1.5,
              colors: [
                AppColors.vrPrimary.withValues(alpha: 0.08),
                const Color(0xFF0A0A1A),
                AppColors.vrSecondary.withValues(alpha: 0.05),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: CustomPaint(
            painter: _StarfieldPainter(
              progress: _backgroundAnimation.value,
            ),
            size: Size.infinite,
          ),
        );
      },
    );
  }

  /// Navegação lateral estilo VR
  Widget _buildSideNav() {
    return Container(
      width: 120,
      margin: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: AppColors.vrGlow.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.vrGlow.withValues(alpha: 0.1),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Column(
          children: [
            const SizedBox(height: 24),
            // Logo
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: AppColors.vrHeroGradient,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.vrPrimary.withValues(alpha: 0.4),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: const Icon(
                Ionicons.play,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(height: 32),
            // Nav items
            Expanded(
              child: ListView.builder(
                itemCount: _navItems.length,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemBuilder: (context, index) {
                  final item = _navItems[index];
                  final isSelected = index == _selectedNavIndex;

                  return _VRNavButton(
                    item: item,
                    isSelected: isSelected,
                    onTap: () => _onNavTap(index),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              color: AppColors.vrPrimary,
              strokeWidth: 4,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Carregando experiência VR...',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        // Hero card em destaque
        if (_featuredAnime != null) _buildHeroCard(_featuredAnime!),

        const SizedBox(height: 32),

        // Carrosséis 3D
        Expanded(
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              _build3DCarousel(
                title: '🔥 Em Alta',
                items: _trendingAnimes,
                gradientColors: AppColors.vrHeroGradient,
              ),
              const SizedBox(height: 40),
              _build3DCarousel(
                title: '⭐ Top Animes',
                items: _topAnimes,
                gradientColors: AppColors.vrCardGradient,
              ),
              const SizedBox(height: 40),
              _build3DCarousel(
                title: '⚔️ Ação',
                items: _actionAnimes,
                gradientColors: AppColors.vrGlowGradient,
              ),
              const SizedBox(height: 40),
              _buildMangaCarousel(),
            ],
          ),
        ),
      ],
    );
  }

  /// Hero card grande em destaque
  Widget _buildHeroCard(JikanAnime anime) {
    return Container(
      height: 280,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // Imagem principal com efeito 3D
          Expanded(
            flex: 2,
            child: _VR3DCard(
              anime: anime,
              isHero: true,
              onTap: () => _navigateToAnime(anime),
            ),
          ),
          const SizedBox(width: 32),
          // Informações
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Badges
                Row(
                  children: [
                    _buildBadge('DESTAQUE', AppColors.vrPrimary),
                    const SizedBox(width: 12),
                    if (anime.score != null)
                      _buildBadge('⭐ ${anime.score}', AppColors.vrSecondary),
                  ],
                ),
                const SizedBox(height: 16),
                // Título
                Text(
                  anime.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                // Synopsis
                Text(
                  anime.synopsis ?? 'Sem descrição disponível',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 16,
                    height: 1.5,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 24),
                // Botões de ação
                Row(
                  children: [
                    _buildActionButton(
                      icon: Ionicons.play,
                      label: 'ASSISTIR',
                      isPrimary: true,
                      onTap: () => _navigateToAnime(anime),
                    ),
                    const SizedBox(width: 16),
                    _buildActionButton(
                      icon: Ionicons.bookmark_outline,
                      label: 'LISTA',
                      isPrimary: false,
                      onTap: () {},
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

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 12,
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        decoration: BoxDecoration(
          gradient: isPrimary
              ? LinearGradient(colors: AppColors.vrHeroGradient)
              : null,
          color: isPrimary ? null : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPrimary
                ? Colors.transparent
                : Colors.white.withValues(alpha: 0.2),
          ),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: AppColors.vrPrimary.withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Carrossel 3D com perspectiva
  Widget _build3DCarousel({
    required String title,
    required List<JikanAnime> items,
    required List<Color> gradientColors,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título da seção
        Padding(
          padding: const EdgeInsets.only(left: 24, bottom: 20),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 28,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        // Cards horizontais com efeito 3D
        SizedBox(
          height: 320,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: items.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 24),
                child: _VR3DCard(
                  anime: items[index],
                  index: index,
                  gradientColors: gradientColors,
                  onTap: () => _navigateToAnime(items[index]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMangaCarousel() {
    if (_popularMangas.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 24, bottom: 20),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 28,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.vrAccent, AppColors.vrSecondary],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                '📚 Mangás Populares',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 320,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: _popularMangas.length,
            itemBuilder: (context, index) {
              final manga = _popularMangas[index];
              return Padding(
                padding: const EdgeInsets.only(right: 24),
                child: _VR3DMangaCard(
                  manga: manga,
                  index: index,
                  onTap: () => _navigateToManga(manga),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _navigateToAnime(JikanAnime anime) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SourceSelectionScreen(
          animeTitle: anime.title,
          imageUrl: anime.largImageUrl ?? anime.imageUrl,
          myAnimeListUrl: 'https://myanimelist.net/anime/${anime.malId}',
        ),
      ),
    );
  }

  void _navigateToManga(Map<String, dynamic> manga) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MangaDetailScreen(manga: manga),
      ),
    );
  }
}

// ============ Widgets auxiliares ============

class _VRNavItem {
  final IconData icon;
  final String label;
  final Color color;

  _VRNavItem({required this.icon, required this.label, required this.color});
}

class _VRNavButton extends StatefulWidget {
  final _VRNavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _VRNavButton({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_VRNavButton> createState() => _VRNavButtonState();
}

class _VRNavButtonState extends State<_VRNavButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? widget.item.color.withValues(alpha: 0.2)
                : (_isHovered ? Colors.white.withValues(alpha: 0.05) : Colors.transparent),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.isSelected
                  ? widget.item.color.withValues(alpha: 0.5)
                  : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: widget.item.color.withValues(alpha: 0.3),
                      blurRadius: 16,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.item.icon,
                color: widget.isSelected ? widget.item.color : Colors.white54,
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                widget.item.label,
                style: TextStyle(
                  color: widget.isSelected ? widget.item.color : Colors.white54,
                  fontSize: 12,
                  fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card 3D com efeito de perspectiva e hover
class _VR3DCard extends StatefulWidget {
  final JikanAnime anime;
  final int index;
  final bool isHero;
  final List<Color>? gradientColors;
  final VoidCallback onTap;

  const _VR3DCard({
    required this.anime,
    this.index = 0,
    this.isHero = false,
    this.gradientColors,
    required this.onTap,
  });

  @override
  State<_VR3DCard> createState() => _VR3DCardState();
}

class _VR3DCardState extends State<_VR3DCard> {
  bool _isHovered = false;
  Offset _hoverOffset = Offset.zero;

  void _onHover(PointerEvent event, BoxConstraints constraints) {
    final center = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);
    final offset = event.localPosition - center;
    setState(() {
      _hoverOffset = Offset(
        offset.dx / constraints.maxWidth * 0.1,
        offset.dy / constraints.maxHeight * 0.1,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = widget.isHero ? 200.0 : 180.0;
    final height = widget.isHero ? 280.0 : 260.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTap: widget.onTap,
          child: MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) {
              setState(() {
                _isHovered = false;
                _hoverOffset = Offset.zero;
              });
            },
            onHover: (event) => _onHover(event, BoxConstraints(maxWidth: width, maxHeight: height)),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: width,
              height: height,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(_hoverOffset.dx)
                ..rotateX(-_hoverOffset.dy)
                ..scale(_isHovered ? 1.05 : 1.0),
              transformAlignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: (widget.gradientColors?.first ?? AppColors.vrPrimary)
                        .withValues(alpha: _isHovered ? 0.5 : 0.2),
                    blurRadius: _isHovered ? 32 : 16,
                    spreadRadius: _isHovered ? 4 : 0,
                    offset: Offset(
                      _hoverOffset.dx * 20,
                      _hoverOffset.dy * 20 + 8,
                    ),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Imagem
                    CachedNetworkImage(
                      imageUrl: widget.anime.largImageUrl ?? widget.anime.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: AppColors.vrSurface,
                        child: const ShimmerLoading(width: 180, height: 260),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: AppColors.vrSurface,
                        child: const Icon(Icons.error, color: Colors.white54),
                      ),
                    ),
                    // Gradiente inferior
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.8),
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                    ),
                    // Borda luminosa no hover
                    if (_isHovered)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: (widget.gradientColors?.first ?? AppColors.vrPrimary)
                                  .withValues(alpha: 0.6),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    // Score
                    if (widget.anime.score != null)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.vrGlow.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                widget.anime.score!.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // Título
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: Text(
                        widget.anime.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black,
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Ícone de play no hover
                    if (_isHovered)
                      Center(
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppColors.vrPrimary.withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.vrPrimary.withValues(alpha: 0.5),
                                blurRadius: 24,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Ionicons.play,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Card 3D para manga
class _VR3DMangaCard extends StatefulWidget {
  final Map<String, dynamic> manga;
  final int index;
  final VoidCallback onTap;

  const _VR3DMangaCard({
    required this.manga,
    required this.index,
    required this.onTap,
  });

  @override
  State<_VR3DMangaCard> createState() => _VR3DMangaCardState();
}

class _VR3DMangaCardState extends State<_VR3DMangaCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 180,
          height: 260,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..scale(_isHovered ? 1.05 : 1.0),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.vrSecondary.withValues(alpha: _isHovered ? 0.5 : 0.2),
                blurRadius: _isHovered ? 32 : 16,
                spreadRadius: _isHovered ? 4 : 0,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: widget.manga['image'] ?? '',
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: AppColors.vrSurface,
                    child: const ShimmerLoading(width: 180, height: 260),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: AppColors.vrSurface,
                    child: const Icon(Icons.error, color: Colors.white54),
                  ),
                ),
                // Gradiente
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.8),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),
                // Borda no hover
                if (_isHovered)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppColors.vrSecondary.withValues(alpha: 0.6),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                // Título
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Text(
                    widget.manga['title'] ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(color: Colors.black, blurRadius: 10),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Ícone de ler no hover
                if (_isHovered)
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.vrSecondary.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.vrSecondary.withValues(alpha: 0.5),
                            blurRadius: 24,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.menu_book,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Painter para o efeito de estrelas no background
class _StarfieldPainter extends CustomPainter {
  final double progress;
  final List<Offset> _stars = [];
  final List<double> _starSizes = [];

  _StarfieldPainter({required this.progress}) {
    // Gerar estrelas estáticas
    final random = math.Random(42);
    for (int i = 0; i < 100; i++) {
      _stars.add(Offset(random.nextDouble(), random.nextDouble()));
      _starSizes.add(random.nextDouble() * 2 + 0.5);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < _stars.length; i++) {
      final star = _stars[i];
      final starSize = _starSizes[i];
      
      // Animação sutil de brilho
      final twinkle = (math.sin(progress * 2 + i) + 1) / 2;
      paint.color = Colors.white.withValues(alpha: 0.2 + twinkle * 0.3);
      
      canvas.drawCircle(
        Offset(star.dx * size.width, star.dy * size.height),
        starSize * (0.8 + twinkle * 0.4),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StarfieldPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
