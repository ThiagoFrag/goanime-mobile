import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'shimmer_loading.dart';

/// Tamanhos canônicos para imagens de anime/manga.
///
/// O `memCacheWidth` final é calculado em pixels físicos a partir do DPR do
/// device, então o cache fica do tamanho que vai ser pintado — nem maior
/// (desperdício de memória) nem menor (perda de nitidez).
enum AnimeImageSize {
  /// 48-64dp — avatares, mini-cards
  tiny,

  /// 96-160dp — list tiles
  small,

  /// 180-260dp — cards em carrosséis
  medium,

  /// 320-600dp — hero/banner
  large,

  /// 800dp+ — detail screens
  xlarge,
}

extension on AnimeImageSize {
  /// Largura lógica máxima esperada em dp para a categoria.
  int get logicalCap {
    switch (this) {
      case AnimeImageSize.tiny:
        return 80;
      case AnimeImageSize.small:
        return 200;
      case AnimeImageSize.medium:
        return 320;
      case AnimeImageSize.large:
        return 720;
      case AnimeImageSize.xlarge:
        return 1080;
    }
  }
}

/// Resolve a URL ideal entre cover small/large oferecidos por Jikan/AniList,
/// pra evitar baixar 1.2MB quando o card vai pintar 96px.
///
/// Heurística: se a categoria for [AnimeImageSize.tiny] ou [small], prefere a
/// imageUrl menor; caso contrário, prefere large.
String selectAnimeImageUrl({
  required String? smallUrl,
  required String? largeUrl,
  required AnimeImageSize size,
}) {
  final preferSmall =
      size == AnimeImageSize.tiny || size == AnimeImageSize.small;
  if (preferSmall) {
    return (smallUrl != null && smallUrl.isNotEmpty)
        ? smallUrl
        : (largeUrl ?? '');
  }
  return (largeUrl != null && largeUrl.isNotEmpty)
      ? largeUrl
      : (smallUrl ?? '');
}

/// Imagem de anime/manga padronizada do app.
///
/// Substitui `CachedNetworkImage` direto. Aplica DPR-aware mem cache,
/// shimmer placeholder, fade-in e error widget consistente.
class OptimizedAnimeImage extends StatelessWidget {
  final String imageUrl;
  final double width;
  final double height;
  final AnimeImageSize size;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final bool fadeIn;

  const OptimizedAnimeImage({
    super.key,
    required this.imageUrl,
    required this.width,
    required this.height,
    this.size = AnimeImageSize.medium,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.fadeIn = true,
  });

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.0;
    // Resolve o cache em pixels físicos, limitado pela categoria. Evita
    // hardcodar `width * 3` que cresce muito em devices com DPR=4.
    final cappedWidthDp = math.min(width.toInt(), size.logicalCap);
    final cappedHeightDp = math.min(height.toInt(), (size.logicalCap * 1.5).toInt());
    final cacheW = (cappedWidthDp * dpr).round().clamp(64, 1600);
    final cacheH = (cappedHeightDp * dpr).round().clamp(64, 2400);

    final image = CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      filterQuality: FilterQuality.medium,
      memCacheWidth: cacheW,
      memCacheHeight: cacheH,
      maxWidthDiskCache: cacheW,
      maxHeightDiskCache: cacheH,
      fadeInDuration:
          fadeIn ? const Duration(milliseconds: 220) : Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholderFadeInDuration: const Duration(milliseconds: 120),
      placeholder: (context, _) => ShimmerLoading(
        width: width,
        height: height,
        borderRadius: borderRadius ?? BorderRadius.circular(8),
        enablePulse: false,
      ),
      errorWidget: (context, _, __) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: borderRadius ?? BorderRadius.circular(8),
        ),
        child: const Icon(Icons.broken_image_outlined, color: Colors.white38),
      ),
    );

    if (borderRadius == null) return image;
    return ClipRRect(borderRadius: borderRadius!, child: image);
  }
}
