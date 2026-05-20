import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../models/anime.dart';
import 'allanime_service.dart';
import 'anilist_service.dart';
import 'animedrive_service.dart';
import 'episode_thumbnail_service.dart';

/// Camada de busca + extração de vídeo para múltiplas fontes.
///
/// Originalmente vivia inteira em `main.dart`. Mantida como classe estática
/// porque ainda não há injeção de dependência — todos os calls são pontuais.
class AnimeService {
  static const String baseSiteUrl = 'https://animefire.plus';
  static const String _googleVideoUserAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1';
  static const String _bloggerOrigin = 'https://www.blogger.com';
  static const String _bloggerReferer = 'https://www.blogger.com/';

  static Future<List<Anime>> searchAnime(String animeName) async {
    try {
      debugPrint('[AnimeService] Searching in multiple sources: $animeName');

      final results = await Future.wait([
        _searchAnimeFire(animeName),
        _searchAllAnime(animeName),
      ]);

      final List<Anime> allAnimes = [];
      allAnimes.addAll(results[0]);
      allAnimes.addAll(results[1]);

      debugPrint(
        '[AnimeService] Total results: ${allAnimes.length} '
        '(AnimeFire: ${results[0].length}, AllAnime: ${results[1].length})',
      );

      await Future.wait(
        allAnimes.map((anime) => enrichAnimeWithAniList(anime)),
      );

      return allAnimes;
    } catch (e) {
      throw Exception('Error searching anime: $e');
    }
  }

  static Future<List<Anime>> _searchAnimeFire(String animeName) async {
    final String searchUrl =
        '$baseSiteUrl/pesquisar/${_treatAnimeName(animeName)}';

    try {
      final response = await http
          .get(Uri.parse(searchUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint('[AnimeFire] Search failed: ${response.statusCode}');
        return [];
      }

      final document = html_parser.parse(response.body);
      final animeElements = document.querySelectorAll('.row.ml-1.mr-1 a');

      final List<Anime> animes = [];
      for (final element in animeElements) {
        final name = element.text.trim();
        final url = element.attributes['href'] ?? '';

        String? thumbnail;
        final imgElement = element.querySelector('img.imgAnimes');
        if (imgElement != null) {
          thumbnail = imgElement.attributes['data-src'] ??
              imgElement.attributes['src'];
        }

        if (name.isNotEmpty && url.isNotEmpty) {
          animes.add(
            Anime(
              name: name,
              url: url,
              source: AnimeSource.animeFire,
              fallbackImageUrl: thumbnail,
            ),
          );
        }
      }

      debugPrint('[AnimeFire] Found ${animes.length} results');
      return animes;
    } catch (e) {
      debugPrint('[AnimeFire] Search error: $e');
      return [];
    }
  }

  static Future<List<Anime>> _searchAllAnime(String animeName) async {
    try {
      final response = await AllAnimeService.searchAnime(animeName);
      if (response == null || response.shows.isEmpty) {
        debugPrint('[AllAnime] No results found');
        return [];
      }

      final List<Anime> animes = [];
      for (final show in response.shows) {
        final episodeInfo =
            show.episodeCount > 0 ? ' (${show.episodeCount} eps)' : '';
        final fallbackImage =
            show.thumbnail?.isNotEmpty == true ? show.thumbnail! : null;

        animes.add(
          Anime(
            name: '${show.displayName}$episodeInfo',
            url: show.id,
            source: AnimeSource.allAnime,
            allAnimeId: show.id,
            fallbackImageUrl: fallbackImage,
          ),
        );
      }

      debugPrint('[AllAnime] Found ${animes.length} results');
      return animes;
    } catch (e) {
      debugPrint('[AllAnime] Search error: $e');
      return [];
    }
  }

  static Future<void> enrichAnimeWithAniList(Anime anime) async {
    try {
      anime.isLoadingAniList = true;
      final aniListResponse =
          await AniListService.fetchAnimeFromAniList(anime.name);
      if (aniListResponse != null) {
        anime.aniListData = aniListResponse.data.media;
        debugPrint(
          '[AnimeService] Enriched ${anime.name} - '
          'ID: ${anime.anilistId}, Cover: ${anime.imageUrl}',
        );
      }
    } catch (e) {
      debugPrint('[AnimeService] Failed to enrich ${anime.name}: $e');
    } finally {
      anime.isLoadingAniList = false;
    }
  }

  static Future<List<Episode>> getAnimeEpisodes(Anime anime) async {
    try {
      debugPrint(
        '[AnimeService] Getting episodes for ${anime.name} from ${anime.sourceName}',
      );
      if (anime.source == AnimeSource.allAnime) {
        return await _getEpisodesFromAllAnime(anime);
      } else if (anime.source == AnimeSource.animeDrive) {
        return await _getEpisodesFromAnimeDrive(anime);
      }
      return await _getEpisodesFromAnimeFire(anime);
    } catch (e) {
      throw Exception('Error getting episodes: $e');
    }
  }

  static Future<List<Episode>> _getEpisodesFromAnimeFire(Anime anime) async {
    try {
      final response = await http
          .get(Uri.parse(anime.url))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Failed to get episodes: ${response.statusCode}');
      }

      final document = html_parser.parse(response.body);
      final episodeElements = document.querySelectorAll(
        'a.lEp.epT.divNumEp.smallbox.px-2.mx-1.text-left.d-flex',
      );

      final List<int> episodeNumbers = [];
      final List<Episode> tempEpisodes = [];

      for (final element in episodeElements) {
        final number = element.text.trim();
        final url = element.attributes['href'] ?? '';
        if (number.isNotEmpty && url.isNotEmpty) {
          final epNumMatch = RegExp(r'\d+').firstMatch(number);
          final epNum = epNumMatch != null ? int.tryParse(epNumMatch.group(0)!) : null;
          if (epNum != null) {
            episodeNumbers.add(epNum);
            tempEpisodes.add(Episode(number: number, url: url));
          }
        }
      }

      final kitsuThumbnails = await EpisodeThumbnailService.batchGetThumbnails(
        animeTitle: anime.name,
        episodeNumbers: episodeNumbers,
        malId: anime.malId?.toString(),
        anilistId: anime.anilistId?.toString(),
      );

      final List<Episode> episodes = [];
      for (int i = 0; i < tempEpisodes.length; i++) {
        final tempEp = tempEpisodes[i];
        final epNum = episodeNumbers[i];
        final episodeThumbnail = kitsuThumbnails[epNum] ??
            (anime.imageUrl.isNotEmpty ? anime.imageUrl : null);
        episodes.add(
          Episode(
            number: tempEp.number,
            url: tempEp.url,
            thumbnail: episodeThumbnail,
          ),
        );
      }
      return episodes;
    } catch (e) {
      debugPrint('[AnimeFire] Get episodes error: $e');
      throw Exception('Error getting episodes from AnimeFire: $e');
    }
  }

  static Future<List<Episode>> _getEpisodesFromAllAnime(Anime anime) async {
    try {
      final animeId = anime.allAnimeId ?? anime.url;
      final showThumbnail = anime.imageUrl;

      final detailedEpisodes = await AllAnimeService.getEpisodesListDetailed(
        animeId,
        showThumbnail: showThumbnail,
      );
      if (detailedEpisodes.isEmpty) return [];

      final episodeNumbers = detailedEpisodes
          .map((e) => int.tryParse(e.episodeNumber))
          .whereType<int>()
          .toList();

      final kitsuThumbnails = await EpisodeThumbnailService.batchGetThumbnails(
        animeTitle: anime.name,
        episodeNumbers: episodeNumbers,
        malId: anime.malId?.toString(),
        anilistId: anime.anilistId?.toString(),
      );

      final List<Episode> episodes = [];
      for (final allAnimeEp in detailedEpisodes) {
        final displayNumber = 'Episódio ${allAnimeEp.episodeNumber}';
        final epNum = int.tryParse(allAnimeEp.episodeNumber);
        String? episodeThumbnail;
        if (epNum != null && kitsuThumbnails.containsKey(epNum)) {
          episodeThumbnail = kitsuThumbnails[epNum];
        } else {
          episodeThumbnail = allAnimeEp.getImageUrl();
          if (episodeThumbnail == null || episodeThumbnail.isEmpty) {
            episodeThumbnail = showThumbnail;
          }
        }

        episodes.add(
          Episode(
            number: displayNumber,
            url: allAnimeEp.episodeNumber,
            thumbnail: episodeThumbnail,
            title: allAnimeEp.title,
            description: allAnimeEp.description,
          ),
        );
      }
      return episodes;
    } catch (e) {
      debugPrint('[AllAnime] Get episodes error: $e');
      throw Exception('Error getting episodes from AllAnime: $e');
    }
  }

  static Future<List<Episode>> _getEpisodesFromAnimeDrive(Anime anime) async {
    try {
      final animeUrl = anime.animeDriveId != null
          ? 'https://animesdrive.blog/anime/${anime.animeDriveId}'
          : anime.url;

      final details = await AnimeDriveService.getAnimeDetails(animeUrl);
      if (details == null || details.episodes.isEmpty) return [];

      final episodeNumbers = details.episodes
          .map((e) => int.tryParse(e.number))
          .whereType<int>()
          .toList();

      final kitsuThumbnails = await EpisodeThumbnailService.batchGetThumbnails(
        animeTitle: anime.name,
        episodeNumbers: episodeNumbers,
        malId: anime.malId?.toString(),
        anilistId: anime.anilistId?.toString(),
      );

      final List<Episode> episodes = [];
      for (final driveEp in details.episodes) {
        final displayNumber = 'Episódio ${driveEp.number}';
        final epNum = int.tryParse(driveEp.number);
        final episodeThumbnail =
            (epNum != null && kitsuThumbnails.containsKey(epNum))
                ? kitsuThumbnails[epNum]
                : anime.imageUrl;

        episodes.add(
          Episode(
            number: displayNumber,
            url: driveEp.url,
            thumbnail: episodeThumbnail,
            title: driveEp.title.isNotEmpty ? driveEp.title : null,
          ),
        );
      }
      return episodes;
    } catch (e) {
      debugPrint('[AnimeDrive] Get episodes error: $e');
      throw Exception('Error getting episodes from AnimeDrive: $e');
    }
  }

  static Future<String> extractVideoURL(String episodeUrl) async {
    try {
      final response = await http.get(Uri.parse(episodeUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to get video page: ${response.statusCode}');
      }

      final document = html_parser.parse(response.body);

      const selectors = [
        'video',
        'div[data-video-src]',
        'div[data-src]',
        'div[data-url]',
        'div[data-video]',
        'div[data-player]',
        'iframe[src*="video"]',
        'iframe[src*="player"]',
      ];
      const attributes = [
        'data-video-src',
        'data-src',
        'data-url',
        'data-video',
        'src',
      ];

      for (final selector in selectors) {
        final elements = document.querySelectorAll(selector);
        for (final element in elements) {
          for (final attr in attributes) {
            final videoSrc = element.attributes[attr];
            if (videoSrc != null && videoSrc.isNotEmpty) {
              return videoSrc;
            }
          }
        }
      }

      final bloggerLink = _findBloggerLink(response.body);
      if (bloggerLink.isNotEmpty) return bloggerLink;

      final videoUrlPattern = RegExp(r'https?://[^\s<>"]+?\.(?:mp4|m3u8)');
      final match = videoUrlPattern.firstMatch(response.body);
      if (match != null) return match.group(0)!;

      throw Exception('No video source found in the page');
    } catch (e) {
      throw Exception('Error extracting video URL: $e');
    }
  }

  static Future<VideoStreamResult> extractActualVideoURL(String videoSrc) async {
    try {
      if (videoSrc.contains('blogger.com')) {
        return await _extractBloggerVideoURL(videoSrc);
      }

      if (videoSrc.contains('animefire.plus/video/')) {
        final response = await http.get(Uri.parse(videoSrc));
        if (response.statusCode != 200) {
          throw Exception('Failed to get video data: ${response.statusCode}');
        }

        try {
          final jsonData = json.decode(response.body);
          final videoResponse =
              VideoResponse.fromJson(jsonData as Map<String, dynamic>);
          if (videoResponse.data.isNotEmpty) {
            return VideoStreamResult(url: videoResponse.data[0].src);
          }
        } catch (_) {
          // fall through to regex extraction below
        }

        final videoUrlPattern = RegExp(r'https?://[^\s<>"]+?\.(?:mp4|m3u8)');
        final match = videoUrlPattern.firstMatch(response.body);
        if (match != null) {
          return VideoStreamResult(url: match.group(0)!);
        }

        final bloggerLink = _findBloggerLink(response.body);
        if (bloggerLink.isNotEmpty) {
          return await _extractBloggerVideoURL(bloggerLink);
        }
      }

      final response = await http.get(Uri.parse(videoSrc));
      if (response.statusCode != 200) {
        throw Exception('Failed to get video data: ${response.statusCode}');
      }
      final jsonData = json.decode(response.body);
      final videoResponse =
          VideoResponse.fromJson(jsonData as Map<String, dynamic>);
      if (videoResponse.data.isEmpty) {
        throw Exception('No video data found');
      }
      return VideoStreamResult(url: videoResponse.data[0].src);
    } catch (e) {
      throw Exception('Error extracting actual video URL: $e');
    }
  }

  static String _findBloggerLink(String content) {
    final pattern = RegExp(
      r'https://www\.blogger\.com/video\.g\?token=([A-Za-z0-9_-]+)',
    );
    return pattern.firstMatch(content)?.group(0) ?? '';
  }

  static Future<VideoStreamResult> _extractBloggerVideoURL(
    String bloggerUrl,
  ) async {
    try {
      final response = await http.get(
        Uri.parse(bloggerUrl),
        headers: {
          HttpHeaders.userAgentHeader: _googleVideoUserAgent,
          HttpHeaders.refererHeader: 'https://animefire.plus/',
        },
      );

      if (response.headers.containsKey('location')) {
        final location = response.headers['location']!;
        if (location.contains('.mp4') ||
            location.contains('googlevideo.com') ||
            location.contains('googleusercontent.com')) {
          return await _createVideoStreamResult(location, referer: bloggerUrl);
        }
      }

      final content = response.body;

      final videoConfigStart = content.indexOf('VIDEO_CONFIG = ');
      if (videoConfigStart != -1) {
        final jsonStart = content.indexOf('{', videoConfigStart);
        if (jsonStart != -1) {
          int braceCount = 0;
          int jsonEnd = jsonStart;
          for (int i = jsonStart; i < content.length; i++) {
            if (content[i] == '{') {
              braceCount++;
            } else if (content[i] == '}') {
              braceCount--;
              if (braceCount == 0) {
                jsonEnd = i;
                break;
              }
            }
          }
          if (jsonEnd > jsonStart) {
            final configJson = content.substring(jsonStart, jsonEnd + 1);
            try {
              final config = json.decode(configJson);
              if (config is Map) {
                if (config['streams'] is List &&
                    (config['streams'] as List).isNotEmpty) {
                  final firstStream = (config['streams'] as List).first;
                  if (firstStream is Map && firstStream['play_url'] != null) {
                    return await _createVideoStreamResult(
                      firstStream['play_url'].toString(),
                      referer: bloggerUrl,
                    );
                  }
                }
                for (final key in const [
                  'url',
                  'stream_url',
                  'video_url',
                  'source',
                  'src',
                ]) {
                  final value = config[key];
                  if (value != null) {
                    final videoUrl = value.toString();
                    if (videoUrl.contains('http')) {
                      return await _createVideoStreamResult(
                        videoUrl,
                        referer: bloggerUrl,
                      );
                    }
                  }
                }
              }
            } catch (_) {
              final playUrlPattern = RegExp(r'"play_url"\s*:\s*"([^"]+)"');
              final playUrlMatch = playUrlPattern.firstMatch(configJson);
              if (playUrlMatch != null) {
                return await _createVideoStreamResult(
                  playUrlMatch.group(1)!,
                  referer: bloggerUrl,
                );
              }
            }
          }
        }
      }

      final patterns = <RegExp>[
        RegExp(r'https://[^"\s<>]+videoplayback[^"\s<>]*', caseSensitive: false),
        RegExp(r'https://[^"\s<>]+\.googlevideo\.com[^"\s<>]*',
            caseSensitive: false),
        RegExp(
          r'https://[^"\s<>]+\.googleusercontent\.com[^"\s<>]*videoplayback[^"\s<>]*',
          caseSensitive: false,
        ),
        RegExp(r'https://[^"\s<>]+\.googleapis\.com[^"\s<>]*',
            caseSensitive: false),
        RegExp(r'stream_url.*?"([^"]*)"', caseSensitive: false),
        RegExp(r'video_url.*?"([^"]*)"', caseSensitive: false),
        RegExp(r'"url":\s*"([^"]*videoplayback[^"]*)"', caseSensitive: false),
        RegExp(r'"url":\s*"([^"]*\.mp4[^"]*)"', caseSensitive: false),
        RegExp(r'https://[^"\s<>]+\.mp4[^"\s<>]*', caseSensitive: false),
      ];

      for (final pattern in patterns) {
        final match = pattern.firstMatch(content);
        if (match != null) {
          var videoUrl = match.group(1) ?? match.group(0)!;
          // Original escape sequences from blogger embedded JSON.
          videoUrl = videoUrl
              .replaceAll(r'\u003d', '=')
              .replaceAll(r'\u0026', '&')
              .replaceAll(r'\\/', '/')
              .replaceAll(r'\\', '')
              .replaceAll(r'\/', '/');
          if (videoUrl.startsWith('http') &&
              (videoUrl.contains('.mp4') ||
                  videoUrl.contains('googlevideo') ||
                  videoUrl.contains('googleusercontent'))) {
            return await _createVideoStreamResult(videoUrl, referer: bloggerUrl);
          }
        }
      }

      final scriptMatches = RegExp(
        r'<script[^>]*>(.*?)</script>',
        dotAll: true,
      ).allMatches(content);
      for (final scriptMatch in scriptMatches) {
        final scriptContent = scriptMatch.group(1) ?? '';
        final jsPatterns = <RegExp>[
          RegExp(r'https://[^"]+videoplayback[^"]*'),
          RegExp(r'https://[^"]+\.googlevideo\.com[^"]*'),
          RegExp(
            r'https://[^"]+\.googleusercontent\.com[^"]*videoplayback[^"]*',
          ),
        ];
        for (final jsPattern in jsPatterns) {
          final jsMatch = jsPattern.firstMatch(scriptContent);
          if (jsMatch != null) {
            return await _createVideoStreamResult(
              jsMatch.group(0)!,
              referer: bloggerUrl,
            );
          }
        }
      }

      final tokenMatch =
          RegExp(r'token=([A-Za-z0-9_-]+)').firstMatch(bloggerUrl);
      if (tokenMatch != null) {
        final token = tokenMatch.group(1)!;
        final alternativeUrls = [
          'https://www.blogger.com/video-play/mp4/$token',
          'https://blogger.googleusercontent.com/video.g?token=$token',
          'https://redirector.googlevideo.com/videoplayback?token=$token',
        ];
        for (final altUrl in alternativeUrls) {
          try {
            final testResponse = await http.head(Uri.parse(altUrl));
            if (testResponse.statusCode == 200 ||
                testResponse.statusCode == 302) {
              return await _createVideoStreamResult(altUrl, referer: bloggerUrl);
            }
          } catch (_) {
            // try next
          }
        }
      }

      return VideoStreamResult(url: bloggerUrl);
    } catch (e) {
      debugPrint('Error extracting Blogger video URL: $e');
      return VideoStreamResult(url: bloggerUrl);
    }
  }

  static Future<VideoStreamResult> _createVideoStreamResult(
    String url, {
    String? referer,
  }) async {
    if (url.contains('googlevideo.com') || url.contains('videoplayback')) {
      return await _processGoogleVideoURL(url, referer: referer);
    }
    return VideoStreamResult(url: url);
  }

  static Future<VideoStreamResult> _processGoogleVideoURL(
    String googleVideoUrl, {
    String? referer,
  }) async {
    HttpClient? httpClient;
    try {
      final originalUri = Uri.parse(googleVideoUrl);
      final sanitizedUri = _sanitizeGoogleVideoUri(originalUri);

      httpClient = HttpClient();
      httpClient.userAgent = _googleVideoUserAgent;
      httpClient.connectionTimeout = const Duration(seconds: 12);

      final request = await httpClient.getUrl(sanitizedUri);
      request.followRedirects = true;
      request.headers
        ..set(HttpHeaders.acceptHeader, 'video/mp4,video/*;q=0.9,*/*;q=0.8')
        ..set(HttpHeaders.acceptLanguageHeader, 'en-US,en;q=0.9')
        ..set(HttpHeaders.acceptEncodingHeader, 'identity')
        ..set(HttpHeaders.rangeHeader, 'bytes=0-1')
        ..set(HttpHeaders.refererHeader, referer ?? _bloggerReferer)
        ..set('Origin', _bloggerOrigin)
        ..set(HttpHeaders.connectionHeader, 'keep-alive');

      final response = await request.close();
      final effectiveUri = response.redirects.isNotEmpty
          ? response.redirects.last.location
          : sanitizedUri;
      final cookies = response.cookies;
      await response.drain();

      final cookieHeader = cookies.isEmpty
          ? ''
          : cookies
              .map((cookie) => '${cookie.name}=${cookie.value}')
              .join('; ');

      final headers = <String, String>{
        HttpHeaders.userAgentHeader: _googleVideoUserAgent,
        HttpHeaders.acceptHeader: 'video/mp4,video/*;q=0.9,*/*;q=0.8',
        HttpHeaders.acceptLanguageHeader: 'en-US,en;q=0.9',
        HttpHeaders.acceptEncodingHeader: 'identity',
        HttpHeaders.refererHeader: referer ?? _bloggerReferer,
        'Origin': _bloggerOrigin,
      };
      if (cookieHeader.isNotEmpty) {
        headers[HttpHeaders.cookieHeader] = cookieHeader;
      }

      return VideoStreamResult(
        url: effectiveUri.toString(),
        headers: headers,
        isGoogleVideo: true,
      );
    } catch (e) {
      debugPrint('Error processing Google Video URL: $e');
      return VideoStreamResult(
        url: googleVideoUrl,
        headers: {
          HttpHeaders.userAgentHeader: _googleVideoUserAgent,
          HttpHeaders.refererHeader: referer ?? _bloggerReferer,
          'Origin': _bloggerOrigin,
        },
        isGoogleVideo: true,
      );
    } finally {
      httpClient?.close(force: true);
    }
  }

  static Uri _sanitizeGoogleVideoUri(Uri uri) {
    final params = Map<String, String>.from(uri.queryParameters);
    params.removeWhere((key, value) => value.isEmpty);
    return uri.replace(queryParameters: params);
  }

  static String _treatAnimeName(String animeName) {
    return animeName.toLowerCase().replaceAll(' ', '-');
  }
}
