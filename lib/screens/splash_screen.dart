import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/goanime_loader.dart';
import '../theme/app_colors.dart';
import '../utils/responsive.dart';
import 'main_navigation_screen.dart';
import 'vr_home_screen.dart';

/// Tela de splash animada com o logo GoAnime
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> 
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    
    // Configura UI para splash
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
    
    // Animação de fade in
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    
    // Animação de scale
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack),
    );
    
    // Inicia animações
    _fadeController.forward();
    _scaleController.forward();
    
    // Inicializa o app e navega após delay
    _initializeAndNavigate();
  }

  Future<void> _initializeAndNavigate() async {
    // Tempo mínimo de splash para mostrar a animação
    await Future.delayed(const Duration(milliseconds: 3000));
    
    if (mounted && !_isInitialized) {
      _isInitialized = true;
      _navigateToHome();
    }
  }

  void _navigateToHome() {
    // Detecta se é VR/Quest baseado no tamanho da tela
    final size = MediaQuery.of(context).size;
    final isVR = size.width >= 1200 || 
                 (size.width >= 1000 && size.aspectRatio > 1.5);
    
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          // Usa VRHomeScreen para Quest, MainNavigationScreen para mobile
          return isVR ? const VRHomeScreen() : const MainNavigationScreen();
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.background,
              AppColors.surface,
              AppColors.background.withValues(alpha: 0.95),
            ],
          ),
        ),
        child: AnimatedBuilder(
          animation: Listenable.merge([_fadeAnimation, _scaleAnimation]),
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo animado
                      const GoAnimeLoader(
                        size: 280,
                        primaryColor: AppColors.primary,
                        secondaryColor: AppColors.secondary,
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // Subtítulo com animação
                      AnimatedOpacity(
                        opacity: _fadeAnimation.value,
                        duration: const Duration(milliseconds: 500),
                        child: Text(
                          'Seu portal de animes',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 60),
                      
                      // Indicador de loading sutil
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primary.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
