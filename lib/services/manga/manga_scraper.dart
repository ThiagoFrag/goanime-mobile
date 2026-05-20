import 'base_source.dart';
import 'mangadex_source.dart';
import 'mangalivre_blog_source.dart';
import 'models.dart';

/// Main manga scraper that manages multiple sources
class MangaScraper {
  final Map<String, MangaSource> _sources = {};
  final List<String> _sourceOrder = [];

  MangaScraper() {
    // Register default sources. Ordem importa: a primeira é a default
    // quando o usuário não escolhe explicitamente.
    registerSource(MangaLivreBlogSource());
    registerSource(MangaDexSource(language: 'pt-br'));
  }

  /// Register a new source
  void registerSource(MangaSource source) {
    _sources[source.name] = source;
    _sourceOrder.add(source.name);
  }

  /// Get list of available source names
  List<String> get sources => List.unmodifiable(_sourceOrder);

  /// Get information about all sources
  List<SourceInfo> get sourceInfo => _sourceOrder
      .where((name) => _sources.containsKey(name))
      .map((name) => _sources[name]!.info)
      .toList();

  /// Get a specific source by name
  MangaSource? getSource(String name) => _sources[name];

  /// Detect source from URL
  String detectSourceFromUrl(String url) {
    final lowerUrl = url.toLowerCase();

    if (lowerUrl.contains('mangadex.org') || lowerUrl.contains('mangadex.io')) {
      return 'mangadex';
    }
    if (lowerUrl.contains('mangalivre.blog')) {
      return 'mangalivre.blog';
    }
    if (lowerUrl.contains('mangalivre.to')) {
      return 'mangalivre.to';
    }

    // Default to first source
    return _sourceOrder.isNotEmpty ? _sourceOrder.first : '';
  }

  /// Get all mangas from a specific source with pagination
  Future<List<Manga>> getAllMangas(String sourceName, int page) async {
    final source = _sources[sourceName];
    if (source == null) {
      throw Exception('Source not found: $sourceName');
    }
    return source.getAllMangas(page);
  }

  /// Get popular mangas from a specific source
  Future<List<Manga>> getPopularMangas(String sourceName) async {
    final source = _sources[sourceName];
    if (source == null) {
      throw Exception('Source not found: $sourceName');
    }
    return source.getPopularMangas();
  }

  /// Get latest updates from a specific source
  Future<List<Manga>> getLatestUpdates(String sourceName) async {
    final source = _sources[sourceName];
    if (source == null) {
      throw Exception('Source not found: $sourceName');
    }
    return source.getLatestUpdates();
  }

  /// Search manga in a specific source
  Future<List<Manga>> searchManga(String sourceName, String query) async {
    final source = _sources[sourceName];
    if (source == null) {
      throw Exception('Source not found: $sourceName');
    }
    return source.searchManga(query);
  }

  /// Search across all sources
  Future<List<SearchResult>> searchAllSources(String query) async {
    final results = <SearchResult>[];

    await Future.wait(_sourceOrder.map((sourceName) async {
      final source = _sources[sourceName];
      if (source == null) return;

      try {
        final mangas = await source.searchManga(query);
        results.add(SearchResult(mangas: mangas, source: sourceName));
      } catch (e) {
        results.add(SearchResult(
          mangas: [],
          source: sourceName,
          error: e.toString(),
        ));
      }
    }));

    return results;
  }

  /// Get manga details (auto-detect source from URL)
  Future<Manga?> getMangaDetails(String mangaUrl) async {
    final sourceName = detectSourceFromUrl(mangaUrl);
    final source = _sources[sourceName];
    if (source == null) {
      throw Exception('Source not found for URL: $mangaUrl');
    }
    return source.getMangaDetails(mangaUrl);
  }

  /// Get chapters (auto-detect source from URL)
  Future<List<Chapter>> getChapters(String mangaUrl) async {
    final sourceName = detectSourceFromUrl(mangaUrl);
    final source = _sources[sourceName];
    if (source == null) {
      throw Exception('Source not found for URL: $mangaUrl');
    }
    return source.getChapters(mangaUrl);
  }

  /// Get chapter pages (auto-detect source from URL)
  Future<List<MangaPage>> getChapterPages(String chapterUrl) async {
    final sourceName = detectSourceFromUrl(chapterUrl);
    final source = _sources[sourceName];
    if (source == null) {
      throw Exception('Source not found for URL: $chapterUrl');
    }
    return source.getChapterPages(chapterUrl);
  }

  /// Get mangas by genre from a specific source
  Future<List<Manga>> getMangasByGenre(String sourceName, String genre) async {
    final source = _sources[sourceName];
    if (source == null) {
      throw Exception('Source not found: $sourceName');
    }
    return source.getMangasByGenre(genre);
  }

  /// Get genres from a specific source
  Future<List<String>> getGenres(String sourceName) async {
    final source = _sources[sourceName];
    if (source == null) {
      throw Exception('Source not found: $sourceName');
    }
    return source.getGenres();
  }

  /// Get all genres from all sources (deduplicated)
  Future<List<String>> getAllGenres() async {
    final allGenres = <String>{};

    for (final sourceName in _sourceOrder) {
      final source = _sources[sourceName];
      if (source == null) continue;

      try {
        final genres = await source.getGenres();
        allGenres.addAll(genres);
      } catch (_) {
        // Continue with other sources
      }
    }

    return allGenres.toList()..sort();
  }

  /// Dispose all sources
  void dispose() {
    for (final source in _sources.values) {
      if (source is BaseMangaSource) {
        source.dispose();
      }
    }
    _sources.clear();
    _sourceOrder.clear();
  }
}
