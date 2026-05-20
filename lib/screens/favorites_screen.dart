import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../services/favorites_notifier.dart';
import '../models/favorite_item.dart';
import '../theme/app_colors.dart';
import 'manga_detail_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Carregar favoritos ao abrir a tela
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FavoritesNotifier>().loadFavorites();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Meus Favoritos'),
        backgroundColor: AppColors.background,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.white54,
          tabs: [
            Consumer<FavoritesNotifier>(
              builder: (context, notifier, _) =>
                  Tab(text: 'Todos (${notifier.totalCount})'),
            ),
            Consumer<FavoritesNotifier>(
              builder: (context, notifier, _) =>
                  Tab(text: 'Animes (${notifier.animeCount})'),
            ),
            Consumer<FavoritesNotifier>(
              builder: (context, notifier, _) =>
                  Tab(text: 'Mangás (${notifier.mangaCount})'),
            ),
          ],
        ),
      ),
      body: Consumer<FavoritesNotifier>(
        builder: (context, notifier, _) {
          if (notifier.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildFavoritesList(notifier.favorites),
              _buildFavoritesList(notifier.animes),
              _buildFavoritesList(notifier.mangas),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFavoritesList(List<FavoriteItem> items) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.favorite_border,
              size: 80,
              color: Colors.white.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            const Text(
              'Nenhum favorito ainda',
              style: TextStyle(color: Colors.white54, fontSize: 18),
            ),
            const SizedBox(height: 8),
            const Text(
              'Adicione animes e mangás aos favoritos\npara vê-los aqui',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.6,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return _buildFavoriteCard(items[index]);
      },
    );
  }

  Widget _buildFavoriteCard(FavoriteItem item) {
    return GestureDetector(
      onTap: () => _openItem(item),
      onLongPress: () => _showRemoveDialog(item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: item.coverImage,
                    fit: BoxFit.cover,
                    memCacheWidth: 400,
                    memCacheHeight: 560,
                    maxWidthDiskCache: 800,
                    maxHeightDiskCache: 1120,
                    filterQuality: FilterQuality.high,
                    errorWidget: (c, u, e) => Container(
                      color: AppColors.surface,
                      child: const Icon(
                        Icons.broken_image,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                ),
                // Badge do tipo
                Positioned(
                  top: 4,
                  left: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: item.type == FavoriteType.anime
                          ? Colors.blue.withValues(alpha: 0.8)
                          : Colors.purple.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.type == FavoriteType.anime ? 'Anime' : 'Mangá',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                // Source badge para mangás
                if (item.source != null && item.source!.isNotEmpty)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.source!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 8,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                // Overlay de gradiente para título
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.8),
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      item.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openItem(FavoriteItem item) {
    if (item.type == FavoriteType.manga) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MangaDetailScreen(
            manga: {
              'id': item.itemId,
              'title': item.title,
              'image': item.coverImage,
              'url': item.url,
              'source': item.source,
              'genres': item.genres,
            },
          ),
        ),
      );
    } else {
      // TODO: Implementar navegação para anime
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Navegação para anime em desenvolvimento'),
        ),
      );
    }
  }

  void _showRemoveDialog(FavoriteItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Remover dos favoritos?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Deseja remover "${item.title}" dos seus favoritos?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<FavoritesNotifier>().removeFromFavorites(
                item.itemId,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${item.title} removido dos favoritos')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }
}
