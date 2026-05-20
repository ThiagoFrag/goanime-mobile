import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import 'models.dart';

/// Abstract base class for manga sources
abstract class MangaSource {
  String get name;
  String get displayName;
  String get baseUrl;

  SourceInfo get info => SourceInfo(
        name: name,
        displayName: displayName,
        baseUrl: baseUrl,
      );

  Future<List<Manga>> getAllMangas(int page);
  Future<List<Manga>> getPopularMangas();
  Future<List<Manga>> getLatestUpdates();
  Future<List<Manga>> searchManga(String query);
  Future<Manga?> getMangaDetails(String mangaUrl);
  Future<List<Chapter>> getChapters(String mangaUrl);
  Future<List<MangaPage>> getChapterPages(String chapterUrl);
  Future<List<Manga>> getMangasByGenre(String genre);
  Future<List<String>> getGenres();
}

/// Base implementation with common HTTP/parsing utilities
abstract class BaseMangaSource implements MangaSource {
  final http.Client _client;
  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
  static const int _maxRetries = 3;
  static const Duration _timeout = Duration(seconds: 30);
  static const Duration _baseRetryDelay = Duration(milliseconds: 500);
  static const Duration _maxRetryDelay = Duration(seconds: 30);

  bool _disposed = false;

  BaseMangaSource({http.Client? client}) : _client = client ?? http.Client();

  @override
  String get name;

  @override
  String get displayName;

  @override
  String get baseUrl;

  @override
  SourceInfo get info => SourceInfo(
        name: name,
        displayName: displayName,
        baseUrl: baseUrl,
      );

  /// Make HTTP request with exponential backoff + Retry-After support.
  ///
  /// Honors `Retry-After` for 429/503. Backoff doubles each attempt, capped
  /// at [_maxRetryDelay], with jitter to avoid thundering herd.
  Future<http.Response> makeRequest(String url) async {
    if (_disposed) {
      throw StateError('MangaSource $name was disposed');
    }
    Exception? lastError;

    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final response = await _client
            .get(
              Uri.parse(url),
              headers: {
                'User-Agent': _userAgent,
                'Accept':
                    'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
                'Accept-Language': 'pt-BR,pt;q=0.9,en-US;q=0.8,en;q=0.7',
                'Referer': baseUrl,
                'Cache-Control': 'no-cache',
              },
            )
            .timeout(_timeout);

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return response;
        }

        lastError = Exception(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );

        // 4xx (exceto 408/429) não são retentáveis.
        final code = response.statusCode;
        final retryable = code == 408 ||
            code == 429 ||
            code == 425 ||
            (code >= 500 && code < 600);
        if (!retryable) break;

        if (attempt < _maxRetries) {
          await Future.delayed(
            _delayForAttempt(attempt, response.headers['retry-after']),
          );
        }
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        if (attempt < _maxRetries) {
          await Future.delayed(_delayForAttempt(attempt, null));
        }
      }
    }

    throw lastError ?? Exception('Max retries exceeded');
  }

  Duration _delayForAttempt(int attempt, String? retryAfterHeader) {
    if (retryAfterHeader != null && retryAfterHeader.isNotEmpty) {
      final asInt = int.tryParse(retryAfterHeader);
      if (asInt != null && asInt > 0) {
        final seconds = math.min(asInt, _maxRetryDelay.inSeconds);
        return Duration(seconds: seconds);
      }
    }
    final exp = _baseRetryDelay.inMilliseconds * math.pow(2, attempt);
    final capped = math.min(exp.toInt(), _maxRetryDelay.inMilliseconds);
    final jitter = math.Random().nextInt(250);
    return Duration(milliseconds: capped + jitter);
  }

  /// Fetch and parse HTML document
  Future<Document> fetchDocument(String url) async {
    final response = await makeRequest(url);
    return html_parser.parse(response.body);
  }

  /// Normalize URL to absolute
  String normalizeUrl(String url) {
    url = url.trim();
    if (url.isEmpty) return '';

    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    if (url.startsWith('//')) {
      return 'https:$url';
    }
    if (url.startsWith('/')) {
      return baseUrl.endsWith('/') ? '${baseUrl.substring(0, baseUrl.length - 1)}$url' : '$baseUrl$url';
    }
    return '$baseUrl/$url';
  }

  /// Get image source from multiple attributes
  String getImageSrc(Element? img) {
    if (img == null) return '';

    for (final attr in ['data-src', 'data-lazy-src', 'data-original', 'src']) {
      final src = img.attributes[attr]?.trim() ?? '';
      if (src.isNotEmpty && !src.startsWith('data:')) {
        return src;
      }
    }
    return '';
  }

  /// Extract manga ID from URL
  String extractMangaId(String mangaUrl) {
    // Remove trailing slash and query params
    var url = mangaUrl.split('?').first;
    url = url.endsWith('/') ? url.substring(0, url.length - 1) : url;

    // Get last meaningful part
    final parts = url.split('/');
    for (int i = parts.length - 1; i >= 0; i--) {
      final part = parts[i];
      if (part.isNotEmpty && part != 'manga') {
        return part;
      }
    }
    return '';
  }

  /// Check if image URL is valid manga image
  bool isValidMangaImage(String imgSrc) {
    final lower = imgSrc.toLowerCase();

    // Skip common non-manga images
    if (lower.contains('logo') ||
        lower.contains('icon') ||
        lower.contains('avatar') ||
        lower.contains('banner') ||
        lower.contains('gravatar') ||
        lower.contains('loading') ||
        lower.contains('placeholder') ||
        lower.contains('ads')) {
      return false;
    }

    // Prefer wp-content/uploads images
    if (lower.contains('wp-content/uploads')) {
      return true;
    }

    // Accept common image extensions
    return lower.endsWith('.webp') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png');
  }

  /// Format manga title from slug
  String formatMangaTitle(String slug) {
    final words = slug.replaceAll('-', ' ').split(' ');
    return words
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _client.close();
  }
}

/// Adult content keywords for filtering
const List<String> adultKeywords = [
  'hentai', 'ecchi', 'adult', 'mature', 'nsfw', '+18', '18+',
  'erotico', 'sexual', 'porn', 'xxx', 'yaoi', 'yuri',
  'smut', 'lewd', 'nude', 'naked', 'sex', 'doujin', 'doujinshi',
  'shotacon', 'lolicon', 'incest', 'incesto', 'rape', 'estupro',
  'tentacle', 'bondage', 'bdsm', 'orgy', 'orgia', 'gangbang',
  'futanari', 'futa', 'milf', 'netorare', 'ntr', 'vadia',
  'putaria', 'safada', 'gostosa', 'gostosas', 'peitudas',
  'virgindade', 'madrasta', 'stepmother', 'stepmom', 'erotica',
];

/// Check if content is adult based on title and genres
bool isAdultContent(String title, List<String> genres) {
  final lowerTitle = title.toLowerCase();
  for (final keyword in adultKeywords) {
    if (lowerTitle.contains(keyword)) return true;
  }
  for (final genre in genres) {
    final lowerGenre = genre.toLowerCase();
    for (final keyword in adultKeywords) {
      if (lowerGenre.contains(keyword)) return true;
    }
  }
  return false;
}

/// Extract genres from CSS class
List<String> extractGenresFromClass(String cssClass) {
  final genres = <String>[];
  final regex = RegExp(r'genre-([a-z0-9-]+)');
  final matches = regex.allMatches(cssClass);

  for (final match in matches) {
    if (match.groupCount >= 1) {
      var genre = match.group(1)!.replaceAll('-', ' ');
      // Title case
      genre = genre.split(' ').map((w) {
        if (w.isEmpty) return w;
        return w[0].toUpperCase() + w.substring(1);
      }).join(' ');
      genres.add(genre);
    }
  }
  return genres;
}
