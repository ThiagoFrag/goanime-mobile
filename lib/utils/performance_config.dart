import 'package:flutter/rendering.dart';

/// Configurações de performance para o app
/// Mantém o visual atual mas otimiza por baixo dos panos
class PerformanceConfig {
  PerformanceConfig._();

  /// Inicializa configurações de performance.
  ///
  /// Cache de imagens em memória é puxado bem alto porque o app escala muitos
  /// thumbnails de anime/manga simultâneos. Em devices low-end o GC força
  /// eviction de qualquer jeito, então o cap só evita pressão quando há
  /// memória disponível.
  static void init() {
    PaintingBinding.instance.imageCache.maximumSize = 800;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 256 << 20; // 256MB
  }

  /// Limpa cache de imagens se necessário (para liberar memória)
  static void clearImageCache() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

  /// Configurações de scroll otimizadas
  static const double scrollCacheExtent = 500.0;
  
  /// Duração padrão para animações rápidas
  static const Duration fastAnimation = Duration(milliseconds: 150);
  
  /// Duração padrão para animações médias
  static const Duration mediumAnimation = Duration(milliseconds: 250);
  
  /// Duração padrão para animações lentas
  static const Duration slowAnimation = Duration(milliseconds: 400);

  /// Configurações de imagem para diferentes contextos
  static const int thumbnailCacheMultiplier = 2;
  static const int bannerCacheMultiplier = 1; // Banners são grandes, cache menor
  
  /// Limites de memória para listas
  static const int maxVisibleCards = 10;
  static const int preloadCards = 3;
}
