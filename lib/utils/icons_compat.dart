import 'package:flutter/material.dart';

/// Drop-in replacement para `lucide_icons` e `ionicons`.
///
/// Os pacotes originais estendiam [IconData], o que não é mais permitido a
/// partir do Flutter 3.27 ("IconData can't be extended outside of its library
/// because it's a final class"). Aqui mapeamos cada símbolo usado no app para
/// um [IconData] equivalente do Material/Cupertino ou criado via
/// [_materialIcon] com o ponto de código adequado.
///
/// Para adicionar um novo símbolo, basta acrescentar uma `static const`.
class LucideIcons {
  LucideIcons._();

  static const IconData home = Icons.home_outlined;
  static const IconData search = Icons.search;
  static const IconData bookmark = Icons.bookmark_outline;
  static const IconData download = Icons.download_outlined;
  static const IconData settings = Icons.settings_outlined;
  static const IconData play = Icons.play_arrow_rounded;
  static const IconData bookOpen = Icons.menu_book_outlined;
  static const IconData bell = Icons.notifications_outlined;
  static const IconData sparkles = Icons.auto_awesome_outlined;
  static const IconData info = Icons.info_outline;
  static const IconData wand2 = Icons.auto_fix_high_outlined;
  static const IconData key = Icons.vpn_key_outlined;
  static const IconData trophy = Icons.emoji_events_outlined;
  static const IconData swords = Icons.sports_kabaddi_outlined;
  static const IconData heart = Icons.favorite_outline;
  static const IconData clock = Icons.schedule_outlined;
  static const IconData laugh = Icons.sentiment_very_satisfied_outlined;
  static const IconData eye = Icons.visibility_outlined;
  static const IconData eyeOff = Icons.visibility_off_outlined;
  static const IconData trash2 = Icons.delete_outline;
  static const IconData externalLink = Icons.open_in_new;
}

class Ionicons {
  Ionicons._();

  static const IconData home = Icons.home;
  static const IconData home_outline = Icons.home_outlined;
  static const IconData search = Icons.search;
  static const IconData search_outline = Icons.search_outlined;
  static const IconData bookmark = Icons.bookmark;
  static const IconData bookmark_outline = Icons.bookmark_outline;
  static const IconData download = Icons.download;
  static const IconData download_outline = Icons.download_outlined;
  static const IconData settings = Icons.settings;
  static const IconData settings_outline = Icons.settings_outlined;
  static const IconData trending_up = Icons.trending_up;
  static const IconData trending_up_outline = Icons.trending_up;
  static const IconData play = Icons.play_arrow;
  static const IconData play_outline = Icons.play_arrow_outlined;
}
