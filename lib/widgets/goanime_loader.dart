import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Loader animado com o texto "GoAnime" usando efeito de fade e glow
class GoAnimeLoader extends StatefulWidget {
  final double size;
  final Color? primaryColor;
  final Color? secondaryColor;
  
  const GoAnimeLoader({
    super.key,
    this.size = 280,
    this.primaryColor,
    this.secondaryColor,
  });

  @override
  State<GoAnimeLoader> createState() => _GoAnimeLoaderState();
}

class _GoAnimeLoaderState extends State<GoAnimeLoader>
    with TickerProviderStateMixin {
  late AnimationController _letterController;
  late AnimationController _glowController;
  late AnimationController _pulseController;
  
  late Animation<double> _glowAnimation;
  late Animation<double> _pulseAnimation;
  
  final List<Animation<double>> _letterAnimations = [];

  @override
  void initState() {
    super.initState();
    
    // Controller para animar cada letra sequencialmente
    _letterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    
    // Criar animações staggered para cada letra (7 letras: G-o-A-n-i-m-e)
    for (int i = 0; i < 7; i++) {
      final start = i * 0.12;
      final end = math.min(start + 0.25, 1.0);
      
      _letterAnimations.add(
        Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(
            parent: _letterController,
            curve: Interval(start, end, curve: Curves.easeOut),
          ),
        ),
      );
    }
    
    // Glow animation
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    
    // Pulse animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    // Start animations
    _letterController.forward();
    
    _letterController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _glowController.repeat(reverse: true);
        _pulseController.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _letterController.dispose();
    _glowController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.primaryColor ?? const Color(0xFFE91E63);
    final secondaryColor = widget.secondaryColor ?? const Color(0xFF9C27B0);
    
    return SizedBox(
      width: widget.size,
      height: widget.size * 0.5,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _letterController,
          _glowController,
          _pulseController,
        ]),
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [primaryColor, secondaryColor, primaryColor],
                stops: const [0.0, 0.5, 1.0],
              ).createShader(bounds),
              blendMode: BlendMode.srcIn,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildLetter('G', 0, primaryColor),
                  _buildLetter('o', 1, primaryColor),
                  _buildLetter('A', 2, primaryColor),
                  _buildLetter('n', 3, primaryColor),
                  _buildLetter('i', 4, primaryColor),
                  _buildLetter('m', 5, primaryColor),
                  _buildLetter('e', 6, primaryColor),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildLetter(String letter, int index, Color color) {
    final animation = _letterAnimations[index];
    
    return Opacity(
      opacity: animation.value,
      child: Transform.translate(
        offset: Offset(0, 20 * (1 - animation.value)),
        child: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.5 * _glowAnimation.value * animation.value),
                blurRadius: 20 * _glowAnimation.value,
                spreadRadius: 5 * _glowAnimation.value,
              ),
            ],
          ),
          child: Text(
            letter,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: widget.size * 0.18,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: color.withValues(alpha: _glowAnimation.value),
                  blurRadius: 30,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Versão simplificada do loader com círculo pulsante
class GoAnimeLoaderSimple extends StatefulWidget {
  final double size;
  final Color? primaryColor;
  final Color? secondaryColor;

  const GoAnimeLoaderSimple({
    super.key,
    this.size = 200,
    this.primaryColor,
    this.secondaryColor,
  });

  @override
  State<GoAnimeLoaderSimple> createState() => _GoAnimeLoaderSimpleState();
}

class _GoAnimeLoaderSimpleState extends State<GoAnimeLoaderSimple>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _rotationAnimation = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.primaryColor ?? const Color(0xFFE91E63);
    final secondaryColor = widget.secondaryColor ?? const Color(0xFF9C27B0);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Círculo rotativo com gradiente
              Transform.rotate(
                angle: _rotationAnimation.value,
                child: Container(
                  width: widget.size * 0.7,
                  height: widget.size * 0.7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        primaryColor.withValues(alpha: 0),
                        primaryColor,
                        secondaryColor,
                        primaryColor.withValues(alpha: 0),
                      ],
                      stops: const [0, 0.3, 0.7, 1],
                    ),
                  ),
                ),
              ),
              // Círculo interno (background)
              Container(
                width: widget.size * 0.6,
                height: widget.size * 0.6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).scaffoldBackgroundColor,
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
              ),
              // Texto "Go"
              Transform.scale(
                scale: _scaleAnimation.value,
                child: ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [primaryColor, secondaryColor],
                  ).createShader(bounds),
                  blendMode: BlendMode.srcIn,
                  child: Text(
                    'Go',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: widget.size * 0.25,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
