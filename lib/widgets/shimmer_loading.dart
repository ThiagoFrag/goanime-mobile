import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Widget de loading com efeito shimmer premium
/// Animação suave com gradiente deslizante e efeito de brilho
class ShimmerLoading extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;
  final bool enablePulse;

  const ShimmerLoading({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
    this.enablePulse = true,
  });

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late Animation<double> _slideAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // Slide animation - wave effect
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat();
    
    _slideAnimation = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeInOutCubic),
    );
    
    // Pulse animation - breathing effect
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.4, end: 0.7).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _slideController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_slideAnimation, _pulseAnimation]),
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment(_slideAnimation.value - 1, -0.3),
              end: Alignment(_slideAnimation.value + 1, 0.3),
              colors: [
                AppColors.surface,
                Color.lerp(
                  AppColors.surfaceLight,
                  AppColors.primary.withValues(alpha: 0.15),
                  widget.enablePulse ? _pulseAnimation.value : 0.5,
                )!,
                AppColors.surface,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(
                  alpha: widget.enablePulse ? _pulseAnimation.value * 0.1 : 0.05,
                ),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Card de loading com shimmer para listas de animes
class ShimmerAnimeCard extends StatelessWidget {
  final double width;
  final double height;

  const ShimmerAnimeCard({
    super.key,
    this.width = 140,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShimmerLoading(
          width: width,
          height: height,
          borderRadius: BorderRadius.circular(16),
        ),
        const SizedBox(height: 8),
        ShimmerLoading(
          width: width * 0.8,
          height: 12,
          borderRadius: BorderRadius.circular(6),
        ),
        const SizedBox(height: 4),
        ShimmerLoading(
          width: width * 0.5,
          height: 10,
          borderRadius: BorderRadius.circular(5),
        ),
      ],
    );
  }
}

/// Lista horizontal de shimmer cards
class ShimmerAnimeList extends StatelessWidget {
  final double itemWidth;
  final double itemHeight;
  final int itemCount;
  final double spacing;
  final EdgeInsets padding;

  const ShimmerAnimeList({
    super.key,
    this.itemWidth = 140,
    this.itemHeight = 200,
    this.itemCount = 5,
    this.spacing = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: itemHeight + 40, // Extra space for title
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: itemCount,
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.only(right: spacing),
            child: ShimmerAnimeCard(
              width: itemWidth,
              height: itemHeight,
            ),
          );
        },
      ),
    );
  }
}

/// Grid de shimmer cards
class ShimmerAnimeGrid extends StatelessWidget {
  final int crossAxisCount;
  final double childAspectRatio;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final int itemCount;
  final EdgeInsets padding;

  const ShimmerAnimeGrid({
    super.key,
    this.crossAxisCount = 3,
    this.childAspectRatio = 0.6,
    this.crossAxisSpacing = 12,
    this.mainAxisSpacing = 12,
    this.itemCount = 6,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: padding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: mainAxisSpacing,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ShimmerLoading(
                width: double.infinity,
                height: double.infinity,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 6),
            ShimmerLoading(
              width: double.infinity,
              height: 11,
              borderRadius: BorderRadius.circular(5),
            ),
          ],
        );
      },
    );
  }
}
