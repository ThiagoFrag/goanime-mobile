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

/// Navegação Principal - Design Minimalista
/// 
/// Features:
/// - Sidebar colapsável para tablets/VR
/// - Bottom nav para mobile
/// - Transições suaves
/// - Visual clean e moderno
class MinimalNavigationScreen extends StatefulWidget {
  const MinimalNavigationScreen({super.key});

  @override
  State<MinimalNavigationScreen> createState() => _MinimalNavigationScreenState();
}

class _MinimalNavigationScreenState extends State<MinimalNavigationScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isSidebarExpanded = false;
  
  late AnimationController _sidebarController;
  late Animation<double> _sidebarAnimation;

  final List<_NavItem> _navItems = const [
    _NavItem(
      icon: LucideIcons.home,
      label: 'Home',
    ),
    _NavItem(
      icon: LucideIcons.search,
      label: 'Buscar',
    ),
    _NavItem(
      icon: LucideIcons.bookmark,
      label: 'Favoritos',
    ),
    _NavItem(
      icon: LucideIcons.download,
      label: 'Downloads',
    ),
    _NavItem(
      icon: LucideIcons.settings,
      label: 'Ajustes',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _sidebarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _sidebarAnimation = CurvedAnimation(
      parent: _sidebarController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _sidebarController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (index == _currentIndex) return;
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
  }

  void _toggleSidebar() {
    setState(() => _isSidebarExpanded = !_isSidebarExpanded);
    if (_isSidebarExpanded) {
      _sidebarController.forward();
    } else {
      _sidebarController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = Responsive.isTablet(context);
    final isVR = Responsive.isQuest(context);
    final usesSidebar = isTablet || isVR;

    final screens = [
      const HomeScreen(),
      SearchScreen(onBackPressed: () => _onItemTapped(0)),
      const WatchlistScreen(),
      const DownloadsScreen(),
      SettingsScreen(onBackPressed: () => _onItemTapped(0)),
    ];

    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentIndex != 0) {
          _onItemTapped(0);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0F),
        body: Row(
          children: [
            // Sidebar para tablet/VR
            if (usesSidebar) _buildSidebar(),
            
            // Main content
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: screens,
              ),
            ),
          ],
        ),
        // Bottom nav para mobile
        bottomNavigationBar: usesSidebar ? null : _buildBottomNav(),
      ),
    );
  }

  Widget _buildSidebar() {
    return AnimatedBuilder(
      animation: _sidebarAnimation,
      builder: (context, _) {
        final width = 72.0 + (_sidebarAnimation.value * 128);
        
        return Container(
          width: width,
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F14),
            border: Border(
              right: BorderSide(
                color: Colors.white.withOpacity(0.05),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 16),
                
                // Logo / Toggle
                GestureDetector(
                  onTap: _toggleSidebar,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.primary, AppColors.primaryDark],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      LucideIcons.play,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Nav items
                Expanded(
                  child: Column(
                    children: List.generate(_navItems.length, (index) {
                      final item = _navItems[index];
                      final isSelected = _currentIndex == index;
                      
                      return _SidebarItem(
                        icon: item.icon,
                        label: item.label,
                        isSelected: isSelected,
                        isExpanded: _sidebarAnimation.value > 0.5,
                        onTap: () => _onItemTapped(index),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F14),
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.05),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_navItems.length, (index) {
              final item = _navItems[index];
              final isSelected = _currentIndex == index;
              
              return _BottomNavItem(
                icon: item.icon,
                label: item.label,
                isSelected: isSelected,
                onTap: () => _onItemTapped(index),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.label,
  });
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isExpanded;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: isExpanded ? 12 : 14,
        ),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppColors.primary.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(
                  color: AppColors.primary.withOpacity(0.3),
                  width: 1,
                )
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : Colors.white38,
              size: 20,
            ),
            if (isExpanded) ...[
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? AppColors.primary : Colors.white54,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppColors.primary.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : Colors.white38,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.primary : Colors.white38,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
