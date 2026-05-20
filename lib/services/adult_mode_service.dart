import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Serviço para gerenciar o modo +18
class AdultModeService extends ChangeNotifier {
  static const String _key = 'adult_mode_enabled';
  bool _isEnabled = false;

  bool get isEnabled => _isEnabled;

  AdultModeService() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool(_key) ?? false;
    notifyListeners();
  }

  Future<void> toggle() async {
    _isEnabled = !_isEnabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, _isEnabled);
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    _isEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, _isEnabled);
    notifyListeners();
  }

  /// Palavras-chave para identificar conteúdo +18
  static const adultKeywords = [
    'hentai', 'ecchi', 'adult', 'mature', 'nsfw', '+18', '18+',
    'erotico', 'erótico', 'sexual', 'porn', 'xxx', 'yaoi', 'yuri',
    'smut', 'lewd', 'nude', 'naked', 'sex', 'doujin', 'doujinshi',
    'ero', 'r18', 'r-18', 'explicit', 'uncensored', 'adulto',
    'shotacon', 'lolicon', 'incest', 'incesto',
    'rape', 'estupro', 'tentacle', 'tentáculo', 'bondage', 'bdsm',
    'orgy', 'orgia', 'gangbang', 'futanari', 'futa', 'milf', 'netorare',
    'ntr', 'cheating', 'traição', 'prostituta', 'prostitute', 'sexo',
    'vadia', 'putaria', 'safada', 'safado', 'gostosa', 'tesao', 'tesão',
    'punheta', 'masturbação', 'masturbacao', 'stripper', 'striptease',
    'seios', 'peitos', 'buceta', 'piroca', 'rola', 'pica', 'foder',
    'transar', 'orgasmo', 'gozo', 'gozar', 'creampie', 'anal',
    // Palavras adicionais
    'peitudas', 'peituda', 'gostosas', 'gostoso', 'bunduda', 'bundudas',
    'virgindade', 'perdendo a virgindade',
    'madrasta', 'stepmother', 'stepmom',
  ];

  /// Títulos específicos que são conteúdo adulto (quando o nome não tem keywords óbvias)
  static const adultTitles = [
    'madrasta vadia',
    'inside the tentacle cave',
    'secret class',
    'sweet guy',
    'fitness',
    'boarding diary',
    'close as neighbors',
    'drug candy',
    'h-mate',
    'perfect half',
    'the good manager',
    'lucky guy',
    'queen bee',
    'silent war',
    'circles',
    'maidens in-law',
    'stepmother friends',
    'touch to unlock',
    'solmi',
    'private tutor',
    'who did you do it with',
    'love parameter',
    'sexercise',
    'household affairs',
    'keep it a secret',
    'redemption camp',
    'should i study at noryangjin',
    'his place',
    'under the oak tree',  // versão adulta
    'excuse me this is my room',
    'wonderful new world',
    'my stepmom',
    'is there an empty room',
    'she is young',
    'sports girl',
    'partner swap',
    'my girlfriend is a villain',
    'the newlywed',
    'one in a hundred',
    'a perverts daily life',
    'pervert daily',
    'learning the hard way',
    // Títulos em português
    'essas duas gostosas',
    'minha vida em uma pensão',
    'minha vida em uma pensao',
    'a amiga da minha mãe',
    'a amiga da minha mae',
    'otagal',
    'a lua de mel',
    'colorist',
    'love icha',
  ];

  /// Verifica se um manga é conteúdo adulto
  static bool isAdultContent(dynamic mangaData) {
    if (mangaData == null) return false;
    
    // Converte para Map se necessário
    Map<String, dynamic> manga;
    if (mangaData is Map<String, dynamic>) {
      manga = mangaData;
    } else if (mangaData is Map) {
      manga = Map<String, dynamic>.from(mangaData);
    } else {
      return false;
    }
    
    final title = (manga['title'] ?? manga['name'] ?? '').toString().toLowerCase();
    final id = (manga['id'] ?? '').toString().toLowerCase();
    final url = (manga['url'] ?? '').toString().toLowerCase();
    final genres = manga['genres'] ?? manga['genre'] ?? manga['tags'];
    final description = (manga['description'] ?? manga['synopsis'] ?? manga['summary'] ?? '').toString().toLowerCase();
    final source = (manga['source'] ?? '').toString().toLowerCase();
    final category = (manga['category'] ?? '').toString().toLowerCase();
    final type = (manga['type'] ?? '').toString().toLowerCase();
    
    // Verifica títulos específicos conhecidos
    for (final adultTitle in adultTitles) {
      if (title.contains(adultTitle)) return true;
    }
    
    // Verifica no título
    for (final keyword in adultKeywords) {
      if (title.contains(keyword)) return true;
    }
    
    // Verifica no ID/slug (ex: "madrasta-vadia")
    for (final keyword in adultKeywords) {
      if (id.contains(keyword)) return true;
    }
    
    // Verifica na URL
    for (final keyword in adultKeywords) {
      if (url.contains(keyword)) return true;
    }
    
    // Verifica na descrição
    for (final keyword in adultKeywords) {
      if (description.contains(keyword)) return true;
    }
    
    // Verifica na categoria/tipo
    for (final keyword in adultKeywords) {
      if (category.contains(keyword) || type.contains(keyword)) return true;
    }
    
    // Verifica nos gêneros (pode ser lista ou string)
    if (genres != null) {
      if (genres is List) {
        for (final genre in genres) {
          final genreName = genre.toString().toLowerCase();
          for (final keyword in adultKeywords) {
            if (genreName.contains(keyword)) return true;
          }
        }
      } else if (genres is String) {
        final genreStr = genres.toLowerCase();
        for (final keyword in adultKeywords) {
          if (genreStr.contains(keyword)) return true;
        }
      }
    }

    // Algumas fontes são específicas de conteúdo adulto
    if (source.contains('hentai') || source.contains('nhentai') || source.contains('hanime')) {
      return true;
    }
    
    return false;
  }

  /// Filtra lista de mangás removendo conteúdo adulto se não estiver no modo +18
  List<dynamic> filterMangaList(List<dynamic> mangas) {
    if (_isEnabled) return mangas; // Mostra tudo no modo +18
    return mangas.where((m) => !isAdultContent(m)).toList();
  }
}
