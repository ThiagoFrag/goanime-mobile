import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';

import '../models/jikan_models.dart';
import '../services/jikan_service.dart';
import '../services/gomang_service.dart';
import '../services/adult_mode_service.dart';
import '../theme/app_colors.dart';
import '../utils/responsive.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'manga_detail_screen.dart';
import 'manga_browse_screen.dart';
import '../main.dart';

/// Home Screen Minimalista
/// Design clean e focado no conteúdo
class MinimalHomeScreen extends StatefulWidget {
  const MinimalHomeScreen({super.key});

  @override
  State<MinimalHomeScreen> createState() => _MinimalHomeScreenState();
}

class _MinimalHomeScreenState extends State<MinimalHomeScreen>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  
  // Services
  final JikanService _jikanService = JikanService();
  final GomangService _mangaService = GomangService();
  
  // Data
  List<JikanAnime> _trendingAnimes = [];
  List<JikanAnime> _topAnimes = [];
  List<Map<String, dynamic>> _popularMangas = [];
  List<Map<String, dynamic>> _recentMangas = [];
  
  // State
  bool _isLoading = true;
  bool _isMangaMode = false;
  int _selectedNavIndex = 0;
  
  // Controllers
  final ScrollController _scrollController = ScrollController();
  late AnimationController _fadeController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    
    try {
      if (_isMangaMode) {
        await _loadMangaData();
      } else {
        await _loadAnimeData();
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    }
    
    if (mounted) {
      setState(() => _isLoading = false);
      _fadeController.forward();
    }
  }

  Future<void> _loadAnimeData() async {
    try {
      final trending = await _jikanService.getCurrentSeasonAnimes(limit: 10);
      final top = await _jikanService.getTopAnimes(limit: 15);
      
      if (mounted) {
        setState(() {
          _trendingAnimes = trending;
          _topAnimes = top;
        });
      }
    } catch (e) {
      debugPrint('Error loading anime: $e');
    }
  }

  Future<void> _loadMangaData() async {
    try {
      final popular = await _mangaService.getPopular();
      final recent = await _mangaService.getLatestUpdates();
      
      if (mounted) {
        setState(() {
          _popularMangas = popular.cast<Map<String, dynamic>>();
          _recentMangas = recent.cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      debugPrint('Error loading manga: $e');
    }
  }

  void _toggleMode() {
    setState(() {
      _isMangaMode = !_isMangaMode;
      _fadeController.reset();
    });
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    context.watch<AdultModeService>();
    
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: Row(
          children: [
            // Side Navigation - Minimalista
            _buildSideNav(),
            
            // Main Content
            Expanded(
              child: _buildMainContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSideNav() {
    return Container(
      width: 72,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F14),
        border: Border(
          right: BorderSide(
            color: Colors.white.withOpacity(0.05),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Logo/Mode Toggle
          GestureDetector(
            onTap: _toggleMode,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _isMangaMode
                      ? [const Color(0xFF8B5CF6), const Color(0xFF6D28D9)]
                      : [AppColors.primary, AppColors.primaryDark],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _isMangaMode ? LucideIcons.bookOpen : LucideIcons.play,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Nav Items
          _buildNavItem(0, LucideIcons.home, 'Home'),
          _buildNavItem(1, LucideIcons.search, 'Buscar'),
          _buildNavItem(2, LucideIcons.bookmark, 'Salvos'),
          _buildNavItem(3, LucideIcons.download, 'Downloads'),
          
          const Spacer(),
          
          // Settings
          _buildNavItem(4, LucideIcons.settings, 'Config'),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String tooltip) {
    final isSelected = _selectedNavIndex == index;
    
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedNavIndex = index);
          _handleNavTap(index);
        },
        child: Container(
          width: 44,
          height: 44,
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: isSelected 
                ? AppColors.primary.withOpacity(0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: isSelected ? AppColors.primary : Colors.white38,
            size: 20,
          ),
        ),
      ),
    );
  }

  void _handleNavTap(int index) {
    switch (index) {
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SearchScreen(isMangaMode: _isMangaMode),
          ),
        );
        break;
      case 4:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        );
        break;
    }
  }

  Widget _buildMainContent() {
    return RefreshIndicator(
      onRefresh: () => _loadData(forceRefresh: true),
      color: AppColors.primary,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Header minimalista
          SliverToBoxAdapter(child: _buildHeader()),
          
          // Featured
          if (_isLoading)
            const SliverToBoxAdapter(child: _LoadingPlaceholder())
          else
            SliverToBoxAdapter(child: _buildFeatured()),
          
          // Content Grid
          if (!_isLoading)
            SliverToBoxAdapter(child: _buildContentSection()),
          
          // Bottom spacing
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isMangaMode ? 'Mangás' : 'Animes',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isMangaMode 
                      ? 'Leia seus mangás favoritos'
                      : 'Assista agora em alta qualidade',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          // Quick actions
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              LucideIcons.bell,
              color: Colors.white.withOpacity(0.6),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatured() {
    final items = _isMangaMode ? _popularMangas : _trendingAnimes;
    if (items.isEmpty) return const SizedBox.shrink();
    
    final featured = _isMangaMode 
        ? items.first as Map<String, dynamic>
        : items.first as JikanAnime;
    
    return Container(
      height: 220,
      margin: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background
            CachedNetworkImage(
              imageUrl: _isMangaMode 
                  ? (featured as Map<String, dynamic>)['image'] ?? ''
                  : (featured as JikanAnime).imageUrl ?? '',
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: const Color(0xFF1A1A2E)),
              errorWidget: (_, __, ___) => Container(color: const Color(0xFF1A1A2E)),
            ),
            
            // Gradient Overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.8),
                  ],
                  stops: const [0.3, 1.0],
                ),
              ),
            ),
            
            // Content
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _isMangaMode ? 'DESTAQUE' : 'EM ALTA',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Title
                  Text(
                    _isMangaMode 
                        ? (featured as Map<String, dynamic>)['title'] ?? ''
                        : (featured as JikanAnime).title ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Action Button
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isMangaMode ? LucideIcons.bookOpen : LucideIcons.play,
                          color: Colors.black,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isMangaMode ? 'Ler Agora' : 'Assistir',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Row(
            children: [
              Text(
                _isMangaMode ? 'Populares' : 'Top Animes',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                'Ver todos',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        
        // Content Grid
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _isMangaMode ? _recentMangas.length : _topAnimes.length,
            itemBuilder: (context, index) {
              if (_isMangaMode) {
                return _buildMangaCard(_recentMangas[index]);
              }
              return _buildAnimeCard(_topAnimes[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAnimeCard(JikanAnime anime) {
    return GestureDetector(
      onTap: () {
        // Navigate to anime detail
      },
      child: Container(
        width: 130,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: anime.imageUrl ?? '',
                  fit: BoxFit.cover,
                  width: double.infinity,
                  placeholder: (_, __) => Container(
                    color: const Color(0xFF1A1A2E),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: const Color(0xFF1A1A2E),
                    child: const Icon(Icons.image, color: Colors.white24),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            
            // Title
            Text(
              anime.title ?? '',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            
            // Score
            if (anime.score != null)
              Row(
                children: [
                  const Icon(
                    Icons.star,
                    color: Color(0xFFFFD700),
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    anime.score!.toStringAsFixed(1),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMangaCard(Map<String, dynamic> manga) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MangaDetailScreen(manga: manga),
          ),
        );
      },
      child: Container(
        width: 130,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: manga['image'] ?? '',
                  fit: BoxFit.cover,
                  width: double.infinity,
                  placeholder: (_, __) => Container(
                    color: const Color(0xFF1A1A2E),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: const Color(0xFF1A1A2E),
                    child: const Icon(Icons.image, color: Colors.white24),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            
            // Title
            Text(
              manga['title'] ?? '',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            
            // Chapter
            if (manga['latestChapter'] != null)
              Text(
                manga['latestChapter'].toString(),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 11,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LoadingPlaceholder extends StatelessWidget {
  const _LoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      margin: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 2,
        ),
      ),
    );
  }
}
