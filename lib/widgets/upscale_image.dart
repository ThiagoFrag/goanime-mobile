import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/upscale_service.dart';
import '../theme/app_colors.dart';

/// Widget de imagem com upscale automático via IA
/// 
/// Mostra a imagem original enquanto processa o upscale,
/// depois faz transição suave para a versão melhorada.
class UpscaleImage extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final bool showProgress;
  final bool autoUpscale;
  final int? scale;
  final Widget? placeholder;
  final Widget? errorWidget;

  const UpscaleImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.showProgress = true,
    this.autoUpscale = true,
    this.scale,
    this.placeholder,
    this.errorWidget,
  });

  @override
  State<UpscaleImage> createState() => _UpscaleImageState();
}

class _UpscaleImageState extends State<UpscaleImage>
    with SingleTickerProviderStateMixin {
  final UpscaleService _upscaleService = UpscaleService();
  
  String? _upscaledUrl;
  bool _isUpscaling = false;
  double _progress = 0.0;
  bool _upscaleComplete = false;
  
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    
    if (widget.autoUpscale && _upscaleService.isEnabled) {
      _startUpscale();
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _startUpscale() async {
    if (_isUpscaling || _upscaleComplete) return;
    
    setState(() => _isUpscaling = true);
    
    try {
      final result = await _upscaleService.upscaleImageUrl(
        widget.imageUrl,
        scale: widget.scale,
        onProgress: (progress) {
          if (mounted) {
            setState(() => _progress = progress);
          }
        },
      );
      
      if (mounted && result != widget.imageUrl) {
        setState(() {
          _upscaledUrl = result;
          _isUpscaling = false;
          _upscaleComplete = true;
        });
        _fadeController.forward();
      } else {
        setState(() => _isUpscaling = false);
      }
    } catch (e) {
      debugPrint('[UpscaleImage] Error: $e');
      if (mounted) {
        setState(() => _isUpscaling = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.zero,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Imagem original
            CachedNetworkImage(
              imageUrl: widget.imageUrl,
              fit: widget.fit,
              placeholder: (_, __) => widget.placeholder ?? _buildPlaceholder(),
              errorWidget: (_, __, ___) => widget.errorWidget ?? _buildError(),
            ),
            
            // Imagem upscalada (com fade in)
            if (_upscaledUrl != null)
              FadeTransition(
                opacity: _fadeAnimation,
                child: CachedNetworkImage(
                  imageUrl: _upscaledUrl!,
                  fit: widget.fit,
                  placeholder: (_, __) => const SizedBox.shrink(),
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            
            // Indicador de progresso
            if (_isUpscaling && widget.showProgress)
              Positioned(
                right: 8,
                bottom: 8,
                child: _buildProgressIndicator(),
              ),
            
            // Badge de upscale completo
            if (_upscaleComplete && widget.showProgress)
              Positioned(
                right: 8,
                bottom: 8,
                child: _buildCompleteBadge(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.surface,
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      color: AppColors.surface,
      child: const Center(
        child: Icon(
          Icons.broken_image,
          color: Colors.white38,
          size: 32,
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              value: _progress > 0 ? _progress : null,
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'AI ${(_progress * 100).toInt()}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompleteBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.secondary],
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome,
            color: Colors.white,
            size: 12,
          ),
          SizedBox(width: 4),
          Text(
            'AI Enhanced',
            style: TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Versão simplificada para listas (sem indicadores)
class UpscaleImageSimple extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const UpscaleImageSimple({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return UpscaleImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      borderRadius: borderRadius,
      showProgress: false,
    );
  }
}
