import 'package:flutter/material.dart';
import '../models/jikan_models.dart';
import 'optimized_anime_image.dart';

class AnimeCard extends StatelessWidget {
  final JikanAnime anime;
  final VoidCallback? onTap;
  final double width;
  final double height;
  final bool showTitle;
  final bool showScore;

  const AnimeCard({
    super.key,
    required this.anime,
    this.onTap,
    this.width = 120,
    this.height = 180,
    this.showTitle = true,
    this.showScore = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagem do anime
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  OptimizedAnimeImage(
                    imageUrl: selectAnimeImageUrl(
                      smallUrl: anime.imageUrl,
                      largeUrl: anime.largImageUrl,
                      size: AnimeImageSize.medium,
                    ),
                    width: width,
                    height: height,
                    size: AnimeImageSize.medium,
                  ),
                  // Score badge
                  if (showScore && anime.score != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(4),
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
            // Título do anime
            if (showTitle) ...[
              const SizedBox(height: 8),
              Text(
                anime.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AnimeCardLarge extends StatelessWidget {
  final JikanAnime anime;
  final VoidCallback? onTap;

  const AnimeCardLarge({super.key, required this.anime, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Imagem
            OptimizedAnimeImage(
              imageUrl: selectAnimeImageUrl(
                smallUrl: anime.imageUrl,
                largeUrl: anime.largImageUrl,
                size: AnimeImageSize.small,
              ),
              width: 100,
              height: 140,
              size: AnimeImageSize.small,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
            ),
            // Informações
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      anime.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (anime.synopsis != null)
                      Text(
                        anime.synopsis!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (anime.score != null) ...[
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            anime.score!.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (anime.episodes != null) ...[
                          Icon(Icons.tv, color: Colors.grey[400], size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '${anime.episodes} eps',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
