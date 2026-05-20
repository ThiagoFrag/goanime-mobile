import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/responsive.dart';

/// Widget de card otimizado para VR com efeitos de profundidade
class VRCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets? padding;
  final double? width;
  final double? height;
  final bool enableGlow;
  final Color? glowColor;
  final double elevation;

  const VRCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.width,
    this.height,
    this.enableGlow = true,
    this.glowColor,
    this.elevation = 8,
  });

  @override
  State<VRCard> createState() => _VRCardState();
}

class _VRCardState extends State<VRCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHover(bool hovering) {
    setState(() => _isHovered = hovering);
    if (hovering) {
      _controller.forward();
    } else if (!_isPressed) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVR = Responsive.isQuest(context);
    final borderRadius = Responsive.getBorderRadius(context);
    final glowColor = widget.glowColor ?? AppColors.vrGlow;

    return MouseRegion(
      onEnter: (_) => _onHover(true),
      onExit: (_) => _onHover(false),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _isPressed ? 0.95 : _scaleAnimation.value,
              child: Container(
                width: widget.width,
                height: widget.height,
                padding: widget.padding,
                decoration: BoxDecoration(
                  color: isVR ? AppColors.vrSurface : AppColors.surface,
                  borderRadius: BorderRadius.circular(borderRadius),
                  border: Border.all(
                    color: _isHovered
                        ? glowColor.withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.05),
                    width: isVR ? 2 : 1,
                  ),
                  boxShadow: [
                    // Sombra base
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: widget.elevation * 2,
                      offset: Offset(0, widget.elevation),
                    ),
                    // Glow effect (mais forte em VR)
                    if (widget.enableGlow && (_isHovered || isVR))
                      BoxShadow(
                        color: glowColor.withValues(
                          alpha: isVR
                              ? 0.2 + (_glowAnimation.value * 0.3)
                              : 0.1 + (_glowAnimation.value * 0.2),
                        ),
                        blurRadius: 20 + (_glowAnimation.value * 20),
                        spreadRadius: _glowAnimation.value * 5,
                      ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(borderRadius - 1),
                  child: widget.child,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Botão otimizado para VR com tamanho de toque maior
class VRButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final EdgeInsets? padding;
  final double? width;
  final double? height;
  final IconData? icon;
  final String? label;
  final bool isPrimary;

  const VRButton({
    super.key,
    this.child = const SizedBox.shrink(),
    this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.padding,
    this.width,
    this.height,
    this.icon,
    this.label,
    this.isPrimary = true,
  });

  @override
  State<VRButton> createState() => _VRButtonState();
}

class _VRButtonState extends State<VRButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVR = Responsive.isQuest(context);
    final minTouchTarget = Responsive.getMinTouchTarget(context);
    final iconSize = Responsive.getIconSize(context);
    final fontSize = Responsive.getFontSize(context);
    final borderRadius = Responsive.getBorderRadius(context);

    final bgColor = widget.backgroundColor ??
        (widget.isPrimary
            ? (isVR ? AppColors.vrPrimary : AppColors.primary)
            : AppColors.surface);
    final fgColor = widget.foregroundColor ?? Colors.white;

    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        _controller.forward();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _controller.reverse();
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) => Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: widget.width,
              height: widget.height ?? minTouchTarget,
              constraints: BoxConstraints(minHeight: minTouchTarget),
              padding: widget.padding ??
                  EdgeInsets.symmetric(
                    horizontal: isVR ? 32 : 24,
                    vertical: isVR ? 16 : 12,
                  ),
              decoration: BoxDecoration(
                gradient: widget.isPrimary
                    ? LinearGradient(
                        colors: isVR
                            ? [AppColors.vrPrimary, AppColors.vrSecondary]
                            : [AppColors.primary, AppColors.primaryDark],
                      )
                    : null,
                color: widget.isPrimary ? null : bgColor,
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(
                  color: _isHovered
                      ? AppColors.vrGlow.withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.1),
                  width: isVR ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (widget.isPrimary ? bgColor : AppColors.vrGlow)
                        .withValues(alpha: _isHovered ? 0.4 : 0.2),
                    blurRadius: _isHovered ? 20 : 10,
                    spreadRadius: _isHovered ? 2 : 0,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, color: fgColor, size: iconSize),
                    if (widget.label != null) SizedBox(width: isVR ? 12 : 8),
                  ],
                  if (widget.label != null)
                    Text(
                      widget.label!,
                      style: TextStyle(
                        color: fgColor,
                        fontSize: fontSize,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  if (widget.icon == null && widget.label == null) widget.child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Container com efeito de glow para VR
class VRGlowContainer extends StatelessWidget {
  final Widget child;
  final Color? glowColor;
  final double glowIntensity;
  final EdgeInsets? padding;
  final EdgeInsets? margin;

  const VRGlowContainer({
    super.key,
    required this.child,
    this.glowColor,
    this.glowIntensity = 0.3,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final isVR = Responsive.isQuest(context);
    final borderRadius = Responsive.getBorderRadius(context);
    final color = glowColor ?? AppColors.vrGlow;

    return Container(
      padding: padding,
      margin: margin,
      decoration: BoxDecoration(
        color: isVR ? AppColors.vrSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: color.withValues(alpha: isVR ? 0.3 : 0.1),
          width: isVR ? 1.5 : 1,
        ),
        boxShadow: isVR
            ? [
                BoxShadow(
                  color: color.withValues(alpha: glowIntensity),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: child,
    );
  }
}

/// Texto otimizado para VR com tamanho responsivo
class VRText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final bool isTitle;
  final bool isSubtitle;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  const VRText(
    this.text, {
    super.key,
    this.style,
    this.isTitle = false,
    this.isSubtitle = false,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    final isVR = Responsive.isQuest(context);
    
    double fontSize;
    FontWeight fontWeight;
    Color color;

    if (isTitle) {
      fontSize = Responsive.getTitleFontSize(context);
      fontWeight = FontWeight.bold;
      color = AppColors.textPrimary;
    } else if (isSubtitle) {
      fontSize = Responsive.getSectionTitleSize(context);
      fontWeight = FontWeight.w600;
      color = AppColors.textSecondary;
    } else {
      fontSize = Responsive.getFontSize(context);
      fontWeight = FontWeight.normal;
      color = AppColors.textPrimary;
    }

    // Aumentar ainda mais em VR para legibilidade
    if (isVR) {
      fontSize *= 1.1;
    }

    return Text(
      text,
      style: (style ?? const TextStyle()).copyWith(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: isVR ? 0.5 : 0.2,
        height: isVR ? 1.4 : 1.3,
      ),
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }
}

/// Ícone com glow para VR
class VRIcon extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double? size;
  final bool enableGlow;

  const VRIcon(
    this.icon, {
    super.key,
    this.color,
    this.size,
    this.enableGlow = false,
  });

  @override
  Widget build(BuildContext context) {
    final isVR = Responsive.isQuest(context);
    final iconSize = size ?? Responsive.getIconSize(context);
    final iconColor = color ?? (isVR ? AppColors.vrPrimary : AppColors.primary);

    if (!enableGlow || !isVR) {
      return Icon(icon, color: iconColor, size: iconSize);
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        // Glow effect
        Icon(
          icon,
          color: iconColor.withValues(alpha: 0.3),
          size: iconSize * 1.5,
        ),
        // Main icon
        Icon(icon, color: iconColor, size: iconSize),
      ],
    );
  }
}

/// Barra de navegação otimizada para VR
class VRNavigationBar extends StatelessWidget {
  final int currentIndex;
  final List<VRNavItem> items;
  final ValueChanged<int> onTap;

  const VRNavigationBar({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isVR = Responsive.isQuest(context);
    final navHeight = Responsive.getNavBarHeight(context);
    final horizontalPadding = Responsive.getHorizontalPadding(context);
    final borderRadius = Responsive.getBorderRadius(context);

    return SafeArea(
      child: Container(
        margin: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: isVR ? 16 : 8,
        ),
        height: navHeight,
        decoration: BoxDecoration(
          color: isVR ? AppColors.vrSurface : AppColors.surface,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: isVR
                ? AppColors.vrGlow.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.05),
            width: isVR ? 1.5 : 1,
          ),
          boxShadow: [
            if (isVR)
              BoxShadow(
                color: AppColors.vrGlow.withValues(alpha: 0.1),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
              items.length,
              (index) => _VRNavItemWidget(
                item: items[index],
                isSelected: index == currentIndex,
                onTap: () => onTap(index),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Item da navegação VR
class VRNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Color? color;

  const VRNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.color,
  });
}

class _VRNavItemWidget extends StatefulWidget {
  final VRNavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _VRNavItemWidget({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_VRNavItemWidget> createState() => _VRNavItemWidgetState();
}

class _VRNavItemWidgetState extends State<_VRNavItemWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_VRNavItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _controller.forward().then((_) => _controller.reverse());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVR = Responsive.isQuest(context);
    final iconSize = Responsive.getIconSize(context);
    final fontSize = Responsive.getFontSize(context) - 2;
    final minTouchTarget = Responsive.getMinTouchTarget(context);
    final color = widget.item.color ?? (isVR ? AppColors.vrPrimary : AppColors.primary);

    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        _controller.forward();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        if (!widget.isSelected) _controller.reverse();
      },
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) => Transform.scale(
            scale: widget.isSelected || _isHovered ? _scaleAnimation.value : 1.0,
            child: Container(
              constraints: BoxConstraints(minWidth: minTouchTarget * 1.5),
              padding: EdgeInsets.symmetric(
                horizontal: isVR ? 24 : 16,
                vertical: isVR ? 12 : 8,
              ),
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? color.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                boxShadow: widget.isSelected && isVR
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.3),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.isSelected ? widget.item.activeIcon : widget.item.icon,
                    color: widget.isSelected
                        ? color
                        : AppColors.textSecondary,
                    size: iconSize,
                  ),
                  SizedBox(height: isVR ? 8 : 4),
                  Text(
                    widget.item.label,
                    style: TextStyle(
                      color: widget.isSelected
                          ? color
                          : AppColors.textSecondary,
                      fontSize: fontSize,
                      fontWeight: widget.isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
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
