import 'package:flutter/foundation.dart';
import 'manga/manga.dart';

/// GomangService - Manga service that uses native Dart scraper
/// 
/// This service no longer requires an external server.
/// All scraping is done directly in the app.
class GomangService {
  final MangaScraper _scraper;
  static GomangService? _instance;

  GomangService._() : _scraper = MangaScraper();

  /// Get singleton instance
  factory GomangService() {
    _instance ??= GomangService._();
    return _instance!;
  }

  /// Get list of available sources
  List<String> get sources => _scraper.sources;

  /// Get source info
  List<SourceInfo> get sourceInfo => _scraper.sourceInfo;

  /// Get popular mangas (loads multiple pages for more results)
  Future<List<dynamic>> getPopular({String source = 'mangalivre.blog', int pages = 3}) async {
    debugPrint('[GomangService] getPopular called with source: $source, pages: $pages');
    try {
      final src = _scraper.getSource(source);
      debugPrint('[GomangService] Got source: ${src.runtimeType}');
      if (src is MangaLivreBlogSource) {
        debugPrint('[GomangService] Using MangaLivreBlogSource.getPopularMangasWithPages');
        final mangas = await src.getPopularMangasWithPages(pages);
        debugPrint('[GomangService] Got ${mangas.length} popular mangas');
        return mangas.map((m) => m.toJson()).toList();
      }
      final mangas = await _scraper.getPopularMangas(source);
      debugPrint('[GomangService] Got ${mangas.length} popular mangas (default)');
      return mangas.map((m) => m.toJson()).toList();
    } catch (e, st) {
      debugPrint('[GomangService] Error getting popular: $e');
      debugPrint('[GomangService] Stack: $st');
      rethrow;
    }
  }

  /// Get all mangas with pagination
  Future<List<dynamic>> getMangas({String source = 'mangalivre.blog', int page = 1}) async {
    try {
      final mangas = await _scraper.getAllMangas(source, page);
      return mangas.map((m) => m.toJson()).toList();
    } catch (e) {
      debugPrint('[GomangService] Error getting mangas: $e');
      rethrow;
    }
  }

  /// Get all mangas from multiple pages at once
  Future<List<dynamic>> getMangasMultiplePages({
    String source = 'mangalivre.blog', 
    int startPage = 1, 
    int endPage = 5,
  }) async {
    try {
      final allMangas = <Map<String, dynamic>>[];
      final seenIds = <String>{};
      
      for (int page = startPage; page <= endPage; page++) {
        final mangas = await _scraper.getAllMangas(source, page);
        for (final m in mangas) {
          if (!seenIds.contains(m.id)) {
            seenIds.add(m.id);
            allMangas.add(m.toJson());
          }
        }
      }
      return allMangas;
    } catch (e) {
      debugPrint('[GomangService] Error getting mangas multi-page: $e');
      rethrow;
    }
  }

  /// Search for mangas
  Future<List<dynamic>> search(String q, {String? source}) async {
    try {
      if (source != null) {
        // Search specific source
        final mangas = await _scraper.searchManga(source, q);
        return mangas.map((m) => m.toJson()).toList();
      } else {
        // Search all sources
        final results = await _scraper.searchAllSources(q);
        final allMangas = <Map<String, dynamic>>[];
        for (final result in results) {
          if (result.error == null) {
            allMangas.addAll(result.mangas.map((m) => m.toJson()));
          }
        }
        return allMangas;
      }
    } catch (e) {
      debugPrint('[GomangService] Error searching: $e');
      rethrow;
    }
  }

  /// Get list of chapters for a manga by its URL
  Future<List<dynamic>> getMangaChapters(String mangaUrl) async {
    try {
      final chapters = await _scraper.getChapters(mangaUrl);
      return chapters.map((c) => c.toJson()).toList();
    } catch (e) {
      debugPrint('[GomangService] Error getting chapters: $e');
      rethrow;
    }
  }

  /// Get pages (image URLs) for a chapter by its URL
  Future<List<dynamic>> getChapterPages(String chapterUrl) async {
    try {
      final pages = await _scraper.getChapterPages(chapterUrl);
      return pages.map((p) => p.toJson()).toList();
    } catch (e) {
      debugPrint('[GomangService] Error getting pages: $e');
      rethrow;
    }
  }

  /// Get manga details
  Future<Map<String, dynamic>?> getMangaDetails(String mangaUrl) async {
    try {
      final manga = await _scraper.getMangaDetails(mangaUrl);
      return manga?.toJson();
    } catch (e) {
      debugPrint('[GomangService] Error getting manga details: $e');
      rethrow;
    }
  }

  /// Get latest updates
  Future<List<dynamic>> getLatestUpdates({String source = 'mangalivre.blog'}) async {
    try {
      final mangas = await _scraper.getLatestUpdates(source);
      return mangas.map((m) => m.toJson()).toList();
    } catch (e) {
      debugPrint('[GomangService] Error getting latest updates: $e');
      rethrow;
    }
  }

  /// Get popular mangas from mangalivre.to
  @Deprecated('Use getPopular with source parameter instead')
  Future<List<dynamic>> getPopularMangalivreTo() async {
    // Since mangalivre.to is not implemented yet, return empty
    return [];
  }

  /// Search for mangas by genre/category
  Future<List<dynamic>> searchByGenre(String genre, {String source = 'mangalivre.blog'}) async {
    try {
      final mangas = await _scraper.getMangasByGenre(source, genre);
      return mangas.map((m) => m.toJson()).toList();
    } catch (e) {
      debugPrint('[GomangService] Error searching by genre: $e');
      return [];
    }
  }

  /// Get mangas from different pages (for variety)
  Future<List<dynamic>> getMangasPage(int page, {String source = 'mangalivre.blog'}) async {
    try {
      return await getMangas(source: source, page: page);
    } catch (_) {
      return [];
    }
  }

  /// Get available genres
  Future<List<String>> getGenres({String source = 'mangalivre.blog'}) async {
    try {
      return await _scraper.getGenres(source);
    } catch (e) {
      debugPrint('[GomangService] Error getting genres: $e');
      return [];
    }
  }

  /// Get all genres from all sources
  Future<List<String>> getAllGenres() async {
    try {
      return await _scraper.getAllGenres();
    } catch (e) {
      debugPrint('[GomangService] Error getting all genres: $e');
      return [];
    }
  }

  /// Dispose resources
  void dispose() {
    _scraper.dispose();
    _instance = null;
  }
}
