import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'base_source.dart';
import 'models.dart';

/// Fonte MangaDex via API oficial (https://api.mangadex.org).
///
/// Vantagens vs scraping HTML:
/// - API estável, documentada
/// - Multi-idioma (pt-BR, en, es, etc) — escolhido via [language]
/// - Não há tokens CDN expirando: páginas vêm via /at-home/server
/// - Sem ratelimit punitivo para uso casual
///
/// Limitações:
/// - Conteúdo +18 exige `contentRating[]=erotica` e está OFF por padrão
/// - Algumas obras estão geo-bloqueadas (raro)
class MangaDexSource extends BaseMangaSource {
  /// Código BCP-47 para filtrar traduções (default pt-BR).
  final String language;

  /// Endpoint base oficial.
  static const String _apiBase = 'https://api.mangadex.org';
  static const String _coverBase = 'https://uploads.mangadex.org/covers';

  MangaDexSource({this.language = 'pt-br'});

  @override
  String get name => 'mangadex';

  @override
  String get displayName => 'MangaDex';

  @override
  String get baseUrl => 'https://mangadex.org';

  @override
  SourceInfo get info => SourceInfo(
        name: name,
        displayName: displayName,
        baseUrl: baseUrl,
        language: language,
        nsfw: false,
      );

  /// 20 por página (cap da API: 100).
  static const int _pageLimit = 20;

  Future<List<Manga>> _fetchMangaList({
    int offset = 0,
    String orderKey = 'followedCount',
    String orderDir = 'desc',
    String? title,
    List<String>? includedTags,
  }) async {
    final params = <String, String>{
      'limit': _pageLimit.toString(),
      'offset': offset.toString(),
      'availableTranslatedLanguage[]': language,
      'contentRating[]': 'safe',
      'order[$orderKey]': orderDir,
      'includes[]': 'cover_art',
    };
    if (title != null && title.isNotEmpty) {
      params['title'] = title;
    }
    if (includedTags != null && includedTags.isNotEmpty) {
      for (final tag in includedTags) {
        params.putIfAbsent('includedTags[]', () => tag);
      }
    }
    // contentRating é multi-valor — adiciona suggestive também por padrão
    final uri = Uri.parse('$_apiBase/manga').replace(queryParameters: {
      ...params,
      'contentRating[]': 'safe',
    });
    // Recria URL preservando multi-valor de contentRating manualmente porque
    // `replace(queryParameters)` colapsa chaves duplicadas.
    final manualUri = Uri.parse(
      '$_apiBase/manga?'
      '${_encodeParams({
        ...params,
        'contentRating[]': 'safe',
      })}'
      '&contentRating[]=suggestive',
    );

    try {
      final response = await makeRequest(manualUri.toString());
      final data = json.decode(response.body) as Map<String, dynamic>;
      final list = data['data'] as List? ?? const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(_mapToManga)
          .whereType<Manga>()
          .toList();
    } catch (e) {
      debugPrint('[MangaDex] _fetchMangaList error: $e (uri=$uri)');
      return const [];
    }
  }

  String _encodeParams(Map<String, String> p) => p.entries
      .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
      .join('&');

  Manga? _mapToManga(Map<String, dynamic> raw) {
    try {
      final id = raw['id']?.toString() ?? '';
      if (id.isEmpty) return null;

      final attributes = (raw['attributes'] as Map<String, dynamic>?) ?? {};
      final titleMap = (attributes['title'] as Map<String, dynamic>?) ?? {};
      final altTitles =
          (attributes['altTitles'] as List?)?.whereType<Map>().toList() ?? const [];
      final descMap = (attributes['description'] as Map<String, dynamic>?) ?? {};
      final status = attributes['status']?.toString();
      final rawTags = (attributes['tags'] as List?) ?? const [];

      final title = (titleMap[language] ??
              titleMap['en'] ??
              titleMap.values.firstOrNull ??
              _firstAltTitle(altTitles))
          ?.toString() ??
          'Sem título';

      final description = (descMap[language] ??
              descMap['en'] ??
              descMap.values.firstOrNull)
          ?.toString();

      final relationships = (raw['relationships'] as List?) ?? const [];
      String? coverFile;
      String? author;
      for (final rel in relationships) {
        if (rel is! Map) continue;
        final type = rel['type'];
        final attrs = rel['attributes'];
        if (type == 'cover_art' && attrs is Map) {
          coverFile = attrs['fileName']?.toString();
        } else if (type == 'author' && attrs is Map) {
          author = attrs['name']?.toString();
        }
      }

      final image = (coverFile != null && coverFile.isNotEmpty)
          ? '$_coverBase/$id/$coverFile.512.jpg'
          : '';

      final genres = rawTags
          .whereType<Map>()
          .map((t) {
            final attrs = t['attributes'];
            if (attrs is! Map) return null;
            final nameMap = attrs['name'];
            if (nameMap is! Map) return null;
            return (nameMap['en'] ?? nameMap.values.firstOrNull)?.toString();
          })
          .whereType<String>()
          .toList();

      return Manga(
        id: id,
        title: title,
        image: image,
        url: '$baseUrl/title/$id',
        genres: genres,
        description: description,
        status: status,
        author: author,
        source: name,
      );
    } catch (e) {
      debugPrint('[MangaDex] mapToManga error: $e');
      return null;
    }
  }

  String? _firstAltTitle(List<Map> altTitles) {
    for (final entry in altTitles) {
      final value = entry[language] ?? entry['en'];
      if (value != null) return value.toString();
    }
    return null;
  }

  String _extractIdFromUrl(String mangaUrl) {
    final match = RegExp(r'/title/([a-f0-9-]{8,})').firstMatch(mangaUrl);
    return match?.group(1) ?? mangaUrl;
  }

  @override
  Future<List<Manga>> getAllMangas(int page) async {
    final offset = (page - 1) * _pageLimit;
    return _fetchMangaList(offset: offset, orderKey: 'latestUploadedChapter');
  }

  @override
  Future<List<Manga>> getPopularMangas() =>
      _fetchMangaList(orderKey: 'followedCount');

  @override
  Future<List<Manga>> getLatestUpdates() =>
      _fetchMangaList(orderKey: 'latestUploadedChapter');

  @override
  Future<List<Manga>> searchManga(String query) =>
      _fetchMangaList(title: query, orderKey: 'relevance');

  @override
  Future<Manga?> getMangaDetails(String mangaUrl) async {
    final id = _extractIdFromUrl(mangaUrl);
    try {
      final response = await makeRequest(
        '$_apiBase/manga/$id?includes[]=cover_art&includes[]=author',
      );
      final data = json.decode(response.body) as Map<String, dynamic>;
      final raw = data['data'];
      if (raw is! Map<String, dynamic>) return null;
      return _mapToManga(raw);
    } catch (e) {
      debugPrint('[MangaDex] getMangaDetails error: $e');
      return null;
    }
  }

  @override
  Future<List<Chapter>> getChapters(String mangaUrl) async {
    final id = _extractIdFromUrl(mangaUrl);
    final List<Chapter> chapters = [];
    int offset = 0;
    const limit = 100;
    try {
      while (offset < 500) {
        final uri = Uri.parse('$_apiBase/manga/$id/feed').replace(
          queryParameters: {
            'limit': limit.toString(),
            'offset': offset.toString(),
            'translatedLanguage[]': language,
            'order[chapter]': 'desc',
            'includes[]': 'scanlation_group',
            'contentRating[]': 'safe',
          },
        );
        final response = await makeRequest(uri.toString());
        final body = json.decode(response.body) as Map<String, dynamic>;
        final list = (body['data'] as List?) ?? const [];
        if (list.isEmpty) break;

        for (final item in list) {
          if (item is! Map) continue;
          final chapterId = item['id']?.toString() ?? '';
          final attrs = (item['attributes'] as Map<String, dynamic>?) ?? {};
          final chapterStr = attrs['chapter']?.toString() ?? '0';
          final chapterNum = double.tryParse(chapterStr) ?? 0.0;
          chapters.add(
            Chapter(
              number: chapterStr,
              numberFloat: chapterNum,
              title: (attrs['title']?.toString() ?? '').isEmpty
                  ? 'Capítulo $chapterStr'
                  : attrs['title'].toString(),
              url: '$baseUrl/chapter/$chapterId',
              date: attrs['publishAt']?.toString(),
              mangaId: id,
            ),
          );
        }

        final total = (body['total'] as num?)?.toInt() ?? list.length;
        offset += limit;
        if (offset >= total) break;
      }
    } catch (e) {
      debugPrint('[MangaDex] getChapters error: $e');
    }
    return chapters;
  }

  @override
  Future<List<MangaPage>> getChapterPages(String chapterUrl) async {
    final match = RegExp(r'/chapter/([a-f0-9-]{8,})').firstMatch(chapterUrl);
    final chapterId = match?.group(1) ?? chapterUrl;
    try {
      final response = await makeRequest('$_apiBase/at-home/server/$chapterId');
      final data = json.decode(response.body) as Map<String, dynamic>;
      final host = data['baseUrl']?.toString() ?? '';
      final chapter = data['chapter'] as Map<String, dynamic>?;
      if (host.isEmpty || chapter == null) return const [];
      final hash = chapter['hash']?.toString() ?? '';
      final files = (chapter['data'] as List?)?.cast<String>() ?? const [];
      return [
        for (int i = 0; i < files.length; i++)
          MangaPage(number: i + 1, url: '$host/data/$hash/${files[i]}'),
      ];
    } catch (e) {
      debugPrint('[MangaDex] getChapterPages error: $e');
      return const [];
    }
  }

  @override
  Future<List<Manga>> getMangasByGenre(String genre) async {
    // MangaDex usa UUIDs para tags; aqui filtramos client-side por nome.
    final all = await _fetchMangaList(orderKey: 'followedCount');
    final lower = genre.toLowerCase();
    return all
        .where((m) => m.genres.any((g) => g.toLowerCase() == lower))
        .toList();
  }

  @override
  Future<List<String>> getGenres() async {
    try {
      final response = await makeRequest('$_apiBase/manga/tag');
      final data = json.decode(response.body) as Map<String, dynamic>;
      final list = (data['data'] as List?) ?? const [];
      final genres = list
          .whereType<Map>()
          .map((t) {
            final attrs = t['attributes'];
            if (attrs is! Map) return null;
            final group = attrs['group']?.toString();
            if (group != 'genre' && group != 'theme') return null;
            final nameMap = attrs['name'];
            if (nameMap is! Map) return null;
            return (nameMap['en'] ?? nameMap.values.firstOrNull)?.toString();
          })
          .whereType<String>()
          .toSet()
          .toList()
        ..sort();
      return genres;
    } catch (e) {
      debugPrint('[MangaDex] getGenres error: $e');
      return const [];
    }
  }
}

extension _IterableFirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
