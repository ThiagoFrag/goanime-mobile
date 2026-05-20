import 'package:flutter/material.dart';
import 'dart:io' show Platform;

/// Tipos de dispositivo baseados no tamanho da tela
enum DeviceType { phone, tablet, quest }

/// Classe utilitária para layouts responsivos
/// Suporta: Phone, Tablet, Meta Quest (VR)
class Responsive {
  static const double phoneMaxWidth = 600;
  static const double tabletMaxWidth = 1200;
  
  // Meta Quest 2/3 tem resolução de 1832x1920 por olho
  // Em modo 2D (overlay) geralmente é exibido em ~1280-1920 de largura
  static const double questMinWidth = 1200;
  
  /// Detecta se está rodando em dispositivo VR (Meta Quest)
  static bool _isQuestDevice() {
    try {
      if (Platform.isAndroid) {
        // Meta Quest roda Android, detectamos por resolução alta
        return true; // Será verificado pelo tamanho da tela
      }
    } catch (_) {}
    return false;
  }
  
  /// Detecta o tipo de dispositivo
  static DeviceType getDeviceType(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final height = size.height;
    
    // Meta Quest geralmente tem aspect ratio próximo de 1:1 ou ligeiramente wide
    // E resolução alta (>1200 width)
    final aspectRatio = width / height;
    final isWideScreen = aspectRatio > 1.5;
    
    if (width >= questMinWidth || (width >= 1000 && isWideScreen)) {
      return DeviceType.quest;
    }
    if (width >= phoneMaxWidth) return DeviceType.tablet;
    return DeviceType.phone;
  }

  /// Retorna true se for phone
  static bool isPhone(BuildContext context) => 
      getDeviceType(context) == DeviceType.phone;

  /// Retorna true se for tablet
  static bool isTablet(BuildContext context) => 
      getDeviceType(context) == DeviceType.tablet;

  /// Retorna true se for Quest ou tela grande
  static bool isQuest(BuildContext context) => 
      getDeviceType(context) == DeviceType.quest;

  /// Retorna true se for tablet ou maior
  static bool isTabletOrLarger(BuildContext context) => 
      MediaQuery.of(context).size.width >= phoneMaxWidth;

  /// Número de colunas para grids baseado no dispositivo
  static int getGridColumns(BuildContext context) {
    switch (getDeviceType(context)) {
      case DeviceType.phone:
        return 2;
      case DeviceType.tablet:
        return 4;
      case DeviceType.quest:
        return 5; // Menos colunas para cards maiores em VR
    }
  }

  /// Número de itens visíveis em listas horizontais
  static double getHorizontalListItemWidth(BuildContext context) {
    switch (getDeviceType(context)) {
      case DeviceType.phone:
        return 140;
      case DeviceType.tablet:
        return 170;
      case DeviceType.quest:
        return 220; // Cards maiores para VR
    }
  }

  /// Altura do card baseada no dispositivo
  static double getCardHeight(BuildContext context) {
    switch (getDeviceType(context)) {
      case DeviceType.phone:
        return 200;
      case DeviceType.tablet:
        return 250;
      case DeviceType.quest:
        return 320; // Cards mais altos em VR para melhor visualização
    }
  }

  /// Altura da seção (lista horizontal)
  static double getSectionHeight(BuildContext context) {
    switch (getDeviceType(context)) {
      case DeviceType.phone:
        return 260;
      case DeviceType.tablet:
        return 310;
      case DeviceType.quest:
        return 400; // Seções maiores em VR
    }
  }

  /// Altura do banner hero
  static double getBannerHeight(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    switch (getDeviceType(context)) {
      case DeviceType.phone:
        return (width * 0.6).clamp(200.0, 280.0);
      case DeviceType.tablet:
        return (width * 0.4).clamp(280.0, 400.0);
      case DeviceType.quest:
        return (width * 0.4).clamp(380.0, 550.0); // Banner maior em VR
    }
  }

  /// Padding horizontal baseado no dispositivo
  static double getHorizontalPadding(BuildContext context) {
    switch (getDeviceType(context)) {
      case DeviceType.phone:
        return 16;
      case DeviceType.tablet:
        return 32;
      case DeviceType.quest:
        return 64; // Mais padding em VR para conforto visual
    }
  }

  /// Tamanho da fonte para títulos de seção
  static double getSectionTitleSize(BuildContext context) {
    switch (getDeviceType(context)) {
      case DeviceType.phone:
        return 18;
      case DeviceType.tablet:
        return 22;
      case DeviceType.quest:
        return 28; // Textos maiores em VR
    }
  }

  /// Espaçamento entre cards
  static double getCardSpacing(BuildContext context) {
    switch (getDeviceType(context)) {
      case DeviceType.phone:
        return 12;
      case DeviceType.tablet:
        return 16;
      case DeviceType.quest:
        return 24; // Mais espaçamento em VR
    }
  }

  /// Tamanho mínimo de toque (maior em VR para controles)
  static double getMinTouchTarget(BuildContext context) {
    switch (getDeviceType(context)) {
      case DeviceType.phone:
        return 44;
      case DeviceType.tablet:
        return 48;
      case DeviceType.quest:
        return 64; // Alvos de toque maiores para controles VR
    }
  }

  /// Tamanho de ícones
  static double getIconSize(BuildContext context) {
    switch (getDeviceType(context)) {
      case DeviceType.phone:
        return 24;
      case DeviceType.tablet:
        return 28;
      case DeviceType.quest:
        return 36; // Ícones maiores em VR
    }
  }

  /// Tamanho de fonte padrão
  static double getFontSize(BuildContext context) {
    switch (getDeviceType(context)) {
      case DeviceType.phone:
        return 14;
      case DeviceType.tablet:
        return 16;
      case DeviceType.quest:
        return 18; // Fonte maior em VR para legibilidade
    }
  }

  /// Tamanho de fonte de título
  static double getTitleFontSize(BuildContext context) {
    switch (getDeviceType(context)) {
      case DeviceType.phone:
        return 20;
      case DeviceType.tablet:
        return 24;
      case DeviceType.quest:
        return 32; // Títulos bem maiores em VR
    }
  }

  /// Border radius para cards
  static double getBorderRadius(BuildContext context) {
    switch (getDeviceType(context)) {
      case DeviceType.phone:
        return 16;
      case DeviceType.tablet:
        return 20;
      case DeviceType.quest:
        return 28; // Cantos mais arredondados em VR
    }
  }

  /// Altura da navbar
  static double getNavBarHeight(BuildContext context) {
    switch (getDeviceType(context)) {
      case DeviceType.phone:
        return 64;
      case DeviceType.tablet:
        return 72;
      case DeviceType.quest:
        return 88; // Navbar maior em VR
    }
  }

  /// Valor responsivo genérico
  static T value<T>(
    BuildContext context, {
    required T phone,
    T? tablet,
    T? quest,
  }) {
    switch (getDeviceType(context)) {
      case DeviceType.phone:
        return phone;
      case DeviceType.tablet:
        return tablet ?? phone;
      case DeviceType.quest:
        return quest ?? tablet ?? phone;
    }
  }
}

/// Extensão para facilitar o uso de responsividade
extension ResponsiveExtension on BuildContext {
  DeviceType get deviceType => Responsive.getDeviceType(this);
  bool get isPhone => Responsive.isPhone(this);
  bool get isTablet => Responsive.isTablet(this);
  bool get isQuest => Responsive.isQuest(this);
  double get horizontalPadding => Responsive.getHorizontalPadding(this);
  double get cardHeight => Responsive.getCardHeight(this);
  double get borderRadius => Responsive.getBorderRadius(this);
  double get iconSize => Responsive.getIconSize(this);
  double get fontSize => Responsive.getFontSize(this);
  double get titleFontSize => Responsive.getTitleFontSize(this);
  double get minTouchTarget => Responsive.getMinTouchTarget(this);
}

/// Widget que reconstrói baseado no tamanho da tela
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, DeviceType deviceType) builder;

  const ResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return builder(context, Responsive.getDeviceType(context));
      },
    );
  }
}

/// Widget que mostra diferentes layouts baseado no dispositivo
class ResponsiveLayout extends StatelessWidget {
  final Widget phone;
  final Widget? tablet;
  final Widget? quest;

  const ResponsiveLayout({
    super.key,
    required this.phone,
    this.tablet,
    this.quest,
  });

  @override
  Widget build(BuildContext context) {
    switch (Responsive.getDeviceType(context)) {
      case DeviceType.phone:
        return phone;
      case DeviceType.tablet:
        return tablet ?? phone;
      case DeviceType.quest:
        return quest ?? tablet ?? phone;
    }
  }
}
