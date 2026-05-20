import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/icons_compat.dart';
import '../theme/app_colors.dart';
import '../utils/responsive.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'watchlist_screen.dart';
import 'downloads_screen.dart';
import 'settings_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  int _previousIndex = 0;

  // Animation controllers
  late AnimationController _slideController;
  late AnimationController _glowController;
  late AnimationController _bounceController;
  late AnimationController _rippleController;

  // Animations
  late Animation<double> _slideAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _bounceAnimation;

  // Nav items configuration
  final List<_NavItemData> _navItems = [
    _NavItemData(
      icon: Ionicons.home_outline,
      activeIcon: Ionicons.home,
      label: 'Home',
      color: AppColors.primary,
      vrColor: AppColors.vrPrimary,
    ),
    _NavItemData(
      icon: Ionicons.search_outline,
      activeIcon: Ionicons.search,
      label: 'Buscar',
      color: AppColors.primaryLight,
      vrColor: AppColors.vrSecondary,
    ),
    _NavItemData(
      icon: Ionicons.bookmark_outline,
      activeIcon: Ionicons.bookmark,
      label: 'Lista',
      color: AppColors.secondary,
      vrColor: AppColors.vrAccent,
    ),
    _NavItemData(
      icon: Ionicons.download_outline,
      activeIcon: Ionicons.download,
      label: 'Downloads',
      color: AppColors.accent,
      vrColor: AppColors.vrPrimary,
    ),
    _NavItemData(
      icon: Ionicons.settings_outline,
      activeIcon: Ionicons.settings,
      label: 'Config',
      color: AppColors.secondaryLight,
      vrColor: AppColors.vrSecondary,
    ),
  ];

  @override
  void initState() {
    super.initState();

    // Slide indicator animation
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _slideAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    );

    // Glow pulse animation (loops)
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Bounce animation for icon
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _bounceAnimation =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 30),
          TweenSequenceItem(tween: Tween(begin: 1.3, end: 0.9), weight: 20),
          TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.1), weight: 25),
          TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0), weight: 25),
        ]).animate(
          CurvedAnimation(parent: _bounceController, curve: Curves.easeOut),
        );

    // Ripple effect animation
    _rippleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    // _rippleAnimation is set up but used indirectly by _rippleController
  }

  @override
  void dispose() {
    _slideController.dispose();
    _glowController.dispose();
    _bounceController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  void _navigateToHome() {
    _onItemTapped(0);
  }

  void _onItemTapped(int index) {
    if (index == _currentIndex) return;

    HapticFeedback.lightImpact();

    setState(() {
      _previousIndex = _currentIndex;
      _currentIndex = index;
    });

    // Reset and play animations
    _slideController.forward(from: 0);
    _bounceController.forward(from: 0);
    _rippleController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    // Responsive VR values
    final isVR = Responsive.isQuest(context);
    final navBarHeight = Responsive.getNavBarHeight(context);
    final horizontalPadding = Responsive.getHorizontalPadding(context);
    final borderRadius = Responsive.getBorderRadius(context);

    final List<Widget> screens = [
      const HomeScreen(),
      SearchScreen(onBackPressed: _navigateToHome),
      const WatchlistScreen(),
      const DownloadsScreen(),
      SettingsScreen(onBackPressed: _navigateToHome),
    ];

    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentIndex != 0) {
          _onItemTapped(0);
        }
      },
      child: Scaffold(
        backgroundColor: isVR ? AppColors.vrSurface : AppColors.background,
        body: IndexedStack(index: _currentIndex, children: screens),
        bottomNavigationBar: SafeArea(
          child: Container(
            margin: EdgeInsets.only(
              left: horizontalPadding,
              right: horizontalPadding,
              bottom: MediaQuery.of(context).padding.bottom > 0 ? 8 : (isVR ? 24 : 16),
            ),
            height: navBarHeight,
            decoration: BoxDecoration(
              color: isVR ? AppColors.vrSurface : AppColors.surface,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: isVR
                    ? AppColors.vrGlow.withValues(alpha: 0.25)
                    : _navItems[_currentIndex].color.withValues(alpha: 0.15),
                width: isVR ? 1.5 : 1,
              ),
              boxShadow: [
                if (isVR)
                  BoxShadow(
                    color: AppColors.vrGlow.withValues(alpha: 0.15),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                BoxShadow(
                  color: (isVR ? _navItems[_currentIndex].vrColor : _navItems[_currentIndex].color)
                      .withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, -2),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: isVR ? 0.6 : 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: Stack(
                children: [
                  // Animated indicator
                  AnimatedBuilder(
                    animation: Listenable.merge([
                      _slideAnimation,
                      _glowAnimation,
                    ]),
                    builder: (context, _) {
                      return CustomPaint(
                        size: Size(double.infinity, navBarHeight),
                        painter: _IndicatorPainter(
                          selectedIndex: _currentIndex,
                          previousIndex: _previousIndex,
                          slideProgress: _slideAnimation.value,
                          glowIntensity: _glowAnimation.value,
                          itemCount: _navItems.length,
                          selectedColor: isVR
                              ? _navItems[_currentIndex].vrColor
                              : _navItems[_currentIndex].color,
                          isVR: isVR,
                        ),
                      );
                    },
                  ),
                  // Nav items
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(_navItems.length, (index) {
                      return _AnimatedNavItem(
                        data: _navItems[index],
                        isSelected: _currentIndex == index,
                        bounceAnimation: _bounceAnimation,
                        onTap: () => _onItemTapped(index),
                        isVR: isVR,
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Navigation item data model
class _NavItemData {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Color color;
  final Color vrColor;

  const _NavItemData({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.color,
    required this.vrColor,
  });
}

// Animated navigation item widget
class _AnimatedNavItem extends StatefulWidget {
  final _NavItemData data;
  final bool isSelected;
  final Animation<double> bounceAnimation;
  final VoidCallback onTap;
  final bool isVR;

  const _AnimatedNavItem({
    required this.data,
    required this.isSelected,
    required this.bounceAnimation,
    required this.onTap,
    required this.isVR,
  });

  @override
  State<_AnimatedNavItem> createState() => _AnimatedNavItemState();
}

class _AnimatedNavItemState extends State<_AnimatedNavItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;
  late Animation<double> _hoverAnimation;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _hoverAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(parent: _hoverController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isHovering = true);
        _hoverController.forward();
      },
      onTapUp: (_) {
        setState(() => _isHovering = false);
        _hoverController.reverse();
        widget.onTap();
      },
      onTapCancel: () {
        setState(() => _isHovering = false);
        _hoverController.reverse();
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([widget.bounceAnimation, _hoverAnimation]),
        builder: (context, child) {
          final scale = widget.isSelected
              ? (0.95 + (widget.bounceAnimation.value - 1.0) * 0.15 + 0.05)
              : (_isHovering ? 1.0 : 1.0);

          // VR responsive sizing
          final itemWidth = widget.isVR ? 100.0 : 60.0;
          final iconSize = widget.isVR ? 28.0 : 20.0;
          final fontSize = widget.isVR ? 13.0 : 9.0;
          final padding = widget.isVR ? 14.0 : 8.0;
          final activeColor = widget.isVR ? widget.data.vrColor : widget.data.color;

          return SizedBox(
            width: itemWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated icon container
                Transform.scale(
                  scale: scale.clamp(0.9, 1.15),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    padding: EdgeInsets.all(padding),
                    decoration: BoxDecoration(
                      color: widget.isSelected
                          ? activeColor.withValues(alpha: widget.isVR ? 0.2 : 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(widget.isVR ? 16 : 12),
                      boxShadow: widget.isSelected && widget.isVR
                          ? [
                              BoxShadow(
                                color: activeColor.withValues(alpha: 0.3),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      widget.isSelected
                          ? widget.data.activeIcon
                          : widget.data.icon,
                      color: widget.isSelected
                          ? activeColor
                          : Colors.grey.shade600,
                      size: iconSize,
                    ),
                  ),
                ),
                SizedBox(height: widget.isVR ? 6 : 2),
                // Label
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    color: widget.isSelected
                        ? activeColor
                        : Colors.grey.shade600,
                    fontSize: fontSize,
                    fontWeight: widget.isSelected
                        ? FontWeight.w700
                        : FontWeight.w500,
                    letterSpacing: widget.isVR ? 0.3 : 0,
                  ),
                  child: Text(
                    widget.data.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Simple indicator painter - only draws the sliding indicator line
class _IndicatorPainter extends CustomPainter {
  final int selectedIndex;
  final int previousIndex;
  final double slideProgress;
  final double glowIntensity;
  final int itemCount;
  final Color selectedColor;
  final bool isVR;

  _IndicatorPainter({
    required this.selectedIndex,
    required this.previousIndex,
    required this.slideProgress,
    required this.glowIntensity,
    required this.itemCount,
    required this.selectedColor,
    required this.isVR,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    // Calculate item positions
    final itemWidth = size.width / itemCount;
    final currentX = itemWidth * selectedIndex + itemWidth / 2;
    final previousX = itemWidth * previousIndex + itemWidth / 2;
    final animatedX = previousX + (currentX - previousX) * slideProgress;

    // Draw animated indicator line at bottom - larger for VR
    final indicatorWidth = isVR ? 48.0 : 32.0;
    final indicatorHeight = isVR ? 4.0 : 3.0;
    final bottomOffset = isVR ? 6.0 : 4.0;
    
    final indicatorRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(animatedX, size.height - bottomOffset),
        width: indicatorWidth,
        height: indicatorHeight,
      ),
      Radius.circular(isVR ? 3 : 2),
    );

    // Indicator glow - stronger for VR
    paint.style = PaintingStyle.fill;
    paint.maskFilter = MaskFilter.blur(BlurStyle.normal, (isVR ? 10 : 6) * glowIntensity);
    paint.color = selectedColor.withValues(alpha: (isVR ? 0.7 : 0.5) * glowIntensity);
    canvas.drawRRect(indicatorRect, paint);

    // Indicator solid
    paint.maskFilter = null;
    paint.color = selectedColor;
    canvas.drawRRect(indicatorRect, paint);
  }

  @override
  bool shouldRepaint(covariant _IndicatorPainter oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.slideProgress != slideProgress ||
        oldDelegate.glowIntensity != glowIntensity ||
        oldDelegate.isVR != isVR;
  }
}
