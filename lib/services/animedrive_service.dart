import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

/// Qualidade de vídeo disponível
enum VideoQuality {
  mobile('Mobile / Celular', 'SD'),
  sd('SD', 'SD'),
  hd('HD', 'HD'),
  fullHd('FullHD / HLS', 'FHD'),
  fhd('FHD', 'FHD'),
  unknown('Unknown', '');

  final String label;
  final String badge;
  const VideoQuality(this.label, this.badge);

  static VideoQuality fromLabel(String label) {
    final lower = label.toLowerCase().trim();

    // Mobile/Celular primeiro (mais específico)
    if (lower.contains('mobile') || lower.contains('celular')) {
      return VideoQuality.mobile;
    }

    // FullHD ou HLS (1080p streaming)
    if (lower.contains('fullhd') || lower == 'hls') {
      return VideoQuality.fullHd;
    }

    // FHD sozinho (1080p)
    if (lower == 'fhd' || (lower.contains('fhd') && !lower.contains('/'))) {
      return VideoQuality.fhd;
    }

    // SD / HD combinado - trata como HD
    if (lower.contains('sd') && lower.contains('hd')) {
      return VideoQuality.hd;
    }

    // SD sozinho
    if (lower.contains('sd') && !lower.contains('hd')) {
      return VideoQuality.sd;
    }

    // HD sozinho (720p)
    if (lower.contains('hd')) {
      return VideoQuality.hd;
    }

    return VideoQuality.unknown;
  }
}

/// Opção de servidor/qualidade para um episódio
class VideoOption {
  final String label;
  final VideoQuality quality;
  final String serverName;
  final int serverIndex;
  final String? videoUrl;
  final String? postId;
  final String? type;
  final String? nume;

  VideoOption({
    required this.label,
    required this.quality,
    required this.serverName,
    required this.serverIndex,
    this.videoUrl,
    this.postId,
    this.type,
    this.nume,
  });

  @override
  String toString() => 'VideoOption($label, $quality)';
}

/// AnimeDrive Service - Integração com animesdrive.blog
/// Extrai links diretos de MP4 para streaming
/// Suporta: Navegação por páginas, A-Z, múltiplas qualidades
class AnimeDriveService {
  static const String _baseUrl = 'https://animesdrive.blog';
  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  /// Total de páginas disponíveis (atualizado dinamicamente)
  static int totalPages = 371;

  /// Headers padrão para requests
  static Map<String, String> get _headers => {
    'User-Agent': _userAgent,
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    'Accept-Language': 'pt-BR,pt;q=0.9,en-US;q=0.8,en;q=0.7',
    'Referer': _baseUrl,
  };

  /// Lista de letras para navegação A-Z
  static const List<String> alphabetLetters = [
    '#',
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'I',
    'J',
    'K',
    'L',
    'M',
    'N',
    'O',
    'P',
    'Q',
    'R',
    'S',
    'T',
    'U',
    'V',
    'W',
    'X',
    'Y',
    'Z',
  ];

  /// Navega pela lista de animes por página
  /// Retorna lista de animes e atualiza totalPages
  static Future<List<AnimeDriveShow>> getAnimesByPage(int page) async {
    try {
      debugPrint('[AnimeDrive] Getting animes page $page');

      final pageUrl = page == 1
          ? '$_baseUrl/anime/'
          : '$_baseUrl/anime/page/$page/';

      final response = await http
          .get(Uri.parse(pageUrl), headers: _headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);
        final results = <AnimeDriveShow>[];

        // Atualiza total de páginas
        final paginationLinks = document.querySelectorAll(
          '.pagination a, .wp-pagenavi a',
        );
        for (final link in paginationLinks) {
          final pageNum = int.tryParse(link.text.trim());
          if (pageNum != null && pageNum > totalPages) {
            totalPages = pageNum;
          }
        }

        // Extrai animes - múltiplos seletores para cobrir variações do tema
        final items = document.querySelectorAll(
          'article.item, '
          '.items article, '
          '#archive-content article, '
          '.content article, '
          '.movies-list .ml-item, '
          '.animation-2 .item',
        );

        for (final item in items) {
          try {
            final linkElement = item.querySelector('a[href*="/anime/"]');
            final titleElement = item.querySelector(
              'h3, h2, .data h3, .title, .mli-info h2',
            );
            final imageElement = item.querySelector('img');
            final ratingElement = item.querySelector('.rating, .score, .imdb');
            final yearElement = item.querySelector('.year, .date, span.year');

            final url = linkElement?.attributes['href'] ?? '';
            if (url.isEmpty || !url.contains('/anime/')) continue;

            final title =
                titleElement?.text.trim() ??
                linkElement?.attributes['title']?.trim() ??
                '';
            if (title.isEmpty) continue;

            final image =
                imageElement?.attributes['src'] ??
                imageElement?.attributes['data-src'] ??
                imageElement?.attributes['data-lazy-src'] ??
                '';

            final rating = ratingElement?.text.trim();
            final year = yearElement?.text.trim();

            // Verifica se é dublado
            final isDubbed = title.toLowerCase().contains('dublado');

            results.add(
              AnimeDriveShow(
                id: _extractIdFromUrl(url),
                title: title,
                url: url,
                thumbnail: image,
                rating: rating,
                year: year,
                isDubbed: isDubbed,
              ),
            );
          } catch (e) {
            debugPrint('[AnimeDrive] Error parsing item: $e');
          }
        }

        debugPrint('[AnimeDrive] Found ${results.length} animes on page $page');
        return results;
      } else {
        debugPrint(
          '[AnimeDrive] Failed to get page $page: ${response.statusCode}',
        );
        return [];
      }
    } catch (e) {
      debugPrint('[AnimeDrive] Error getting page $page: $e');
      return [];
    }
  }

  /// Navega pela lista de animes por letra (A-Z)
  static Future<List<AnimeDriveShow>> getAnimesByLetter(
    String letter, {
    int page = 1,
  }) async {
    try {
      debugPrint('[AnimeDrive] Getting animes by letter: $letter, page: $page');

      // A navegação A-Z usa query parameter ou path específico
      String letterUrl;
      if (letter == '#') {
        letterUrl = page == 1
            ? '$_baseUrl/anime/?letter=0-9'
            : '$_baseUrl/anime/page/$page/?letter=0-9';
      } else {
        letterUrl = page == 1
            ? '$_baseUrl/anime/?letter=${letter.toLowerCase()}'
            : '$_baseUrl/anime/page/$page/?letter=${letter.toLowerCase()}';
      }

      final response = await http
          .get(Uri.parse(letterUrl), headers: _headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);
        final results = <AnimeDriveShow>[];

        final items = document.querySelectorAll(
          'article.item, '
          '.items article, '
          '#archive-content article',
        );

        for (final item in items) {
          try {
            final linkElement = item.querySelector('a[href*="/anime/"]');
            final titleElement = item.querySelector('h3, h2, .data h3, .title');
            final imageElement = item.querySelector('img');

            final url = linkElement?.attributes['href'] ?? '';
            if (url.isEmpty || !url.contains('/anime/')) continue;

            final title = titleElement?.text.trim() ?? '';
            if (title.isEmpty) continue;

            final image =
                imageElement?.attributes['src'] ??
                imageElement?.attributes['data-src'] ??
                '';

            results.add(
              AnimeDriveShow(
                id: _extractIdFromUrl(url),
                title: title,
                url: url,
                thumbnail: image,
                isDubbed: title.toLowerCase().contains('dublado'),
              ),
            );
          } catch (e) {
            debugPrint('[AnimeDrive] Error parsing item: $e');
          }
        }

        debugPrint(
          '[AnimeDrive] Found ${results.length} animes for letter $letter',
        );
        return results;
      }
      return [];
    } catch (e) {
      debugPrint('[AnimeDrive] Error getting by letter: $e');
      return [];
    }
  }

  /// Busca gêneros disponíveis
  static Future<List<AnimeDriveGenre>> getGenres() async {
    try {
      debugPrint('[AnimeDrive] Getting genres');

      final response = await http
          .get(Uri.parse(_baseUrl), headers: _headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);
        final genres = <AnimeDriveGenre>[];

        // Busca links de gênero
        final genreLinks = document.querySelectorAll('a[href*="/genre/"]');

        final seenGenres = <String>{};
        for (final link in genreLinks) {
          final url = link.attributes['href'] ?? '';
          final name = link.text.trim();

          if (url.isNotEmpty && name.isNotEmpty && !seenGenres.contains(url)) {
            seenGenres.add(url);
            genres.add(
              AnimeDriveGenre(id: _extractIdFromUrl(url), name: name, url: url),
            );
          }
        }

        debugPrint('[AnimeDrive] Found ${genres.length} genres');
        return genres;
      }
      return [];
    } catch (e) {
      debugPrint('[AnimeDrive] Error getting genres: $e');
      return [];
    }
  }

  /// Busca animes por gênero
  static Future<List<AnimeDriveShow>> getAnimesByGenre(
    String genreUrl, {
    int page = 1,
  }) async {
    try {
      final url = genreUrl.startsWith('http') ? genreUrl : '$_baseUrl$genreUrl';
      final pageUrl = page == 1 ? url : '$url/page/$page/';

      debugPrint('[AnimeDrive] Getting animes by genre: $pageUrl');

      final response = await http
          .get(Uri.parse(pageUrl), headers: _headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);
        final results = <AnimeDriveShow>[];

        final items = document.querySelectorAll('article.item, .items article');

        for (final item in items) {
          try {
            final linkElement = item.querySelector('a[href*="/anime/"]');
            final titleElement = item.querySelector('h3, h2, .title');
            final imageElement = item.querySelector('img');

            final animeUrl = linkElement?.attributes['href'] ?? '';
            if (animeUrl.isEmpty) continue;

            final title = titleElement?.text.trim() ?? '';
            if (title.isEmpty) continue;

            final image = imageElement?.attributes['src'] ?? '';

            results.add(
              AnimeDriveShow(
                id: _extractIdFromUrl(animeUrl),
                title: title,
                url: animeUrl,
                thumbnail: image,
                isDubbed: title.toLowerCase().contains('dublado'),
              ),
            );
          } catch (e) {
            debugPrint('[AnimeDrive] Error parsing genre item: $e');
          }
        }

        return results;
      }
      return [];
    } catch (e) {
      debugPrint('[AnimeDrive] Error getting by genre: $e');
      return [];
    }
  }

  /// Busca animes no AnimeDrive
  static Future<List<AnimeDriveShow>> searchAnime(String query) async {
    try {
      debugPrint('[AnimeDrive] Searching for: $query');

      final searchUrl = Uri.parse('$_baseUrl/?s=${Uri.encodeComponent(query)}');

      final response = await http
          .get(searchUrl, headers: _headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);
        final results = <AnimeDriveShow>[];

        // Busca cards de resultado - o site usa divs com classe result-item ou article
        final articles = document.querySelectorAll(
          'article.item, div.result-item, div.search-page .item',
        );

        for (final article in articles) {
          try {
            // Tenta extrair título e URL
            final titleElement = article.querySelector(
              'h3 a, h2 a, .title a, a.tip',
            );
            final imageElement = article.querySelector('img');

            if (titleElement != null) {
              final title = titleElement.text.trim();
              final url = titleElement.attributes['href'] ?? '';
              final image =
                  imageElement?.attributes['src'] ??
                  imageElement?.attributes['data-src'] ??
                  imageElement?.attributes['data-lazy-src'] ??
                  '';

              if (url.contains('/anime/') && title.isNotEmpty) {
                results.add(
                  AnimeDriveShow(
                    id: _extractIdFromUrl(url),
                    title: title,
                    url: url,
                    thumbnail: image,
                  ),
                );
              }
            }
          } catch (e) {
            debugPrint('[AnimeDrive] Error parsing article: $e');
          }
        }

        debugPrint('[AnimeDrive] Found ${results.length} results');
        return results;
      } else {
        debugPrint('[AnimeDrive] Search failed: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('[AnimeDrive] Search error: $e');
      return [];
    }
  }

  /// Busca detalhes de um anime (lista de episódios)
  static Future<AnimeDriveDetails?> getAnimeDetails(String animeUrl) async {
    try {
      debugPrint('[AnimeDrive] Getting details for: $animeUrl');

      final url = animeUrl.startsWith('http') ? animeUrl : '$_baseUrl$animeUrl';

      final response = await http
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);

        // Extrai título
        final titleElement = document.querySelector(
          'h1.entry-title, h1, .sheader .data h1',
        );
        final title = titleElement?.text.trim() ?? 'Unknown';

        // Extrai imagem
        final posterElement = document.querySelector(
          '.poster img, .sheader .poster img, img.wp-post-image',
        );
        final poster =
            posterElement?.attributes['src'] ??
            posterElement?.attributes['data-src'] ??
            '';

        // Extrai sinopse
        final synopsisElement = document.querySelector(
          '.wp-content p, .description p, #info .wp-content',
        );
        final synopsis = synopsisElement?.text.trim() ?? '';

        // Extrai episódios
        final episodes = <AnimeDriveEpisode>[];
        final episodeElements = document.querySelectorAll(
          '#seasons .episodios li a, '
          '.episodios li a, '
          'ul.episodios a, '
          '.se-a a, '
          '#episodes a, '
          '.episodelist a',
        );

        for (final epElement in episodeElements) {
          try {
            final epUrl = epElement.attributes['href'] ?? '';
            final epTitle = epElement.text.trim();

            // Extrai número do episódio
            final epMatch = RegExp(
              r'episodio[s]?[-_]?(\d+)',
              caseSensitive: false,
            ).firstMatch(epUrl);
            final epNumber =
                epMatch?.group(1) ??
                RegExp(r'(\d+)').firstMatch(epTitle)?.group(1) ??
                '0';

            if (epUrl.contains('episodio')) {
              episodes.add(
                AnimeDriveEpisode(number: epNumber, title: epTitle, url: epUrl),
              );
            }
          } catch (e) {
            debugPrint('[AnimeDrive] Error parsing episode: $e');
          }
        }

        // Ordena episódios por número
        episodes.sort((a, b) {
          final numA = int.tryParse(a.number) ?? 0;
          final numB = int.tryParse(b.number) ?? 0;
          return numA.compareTo(numB);
        });

        debugPrint('[AnimeDrive] Found ${episodes.length} episodes');

        return AnimeDriveDetails(
          id: _extractIdFromUrl(url),
          title: title,
          url: url,
          thumbnail: poster,
          synopsis: synopsis,
          episodes: episodes,
        );
      } else {
        debugPrint(
          '[AnimeDrive] Failed to get details: ${response.statusCode}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('[AnimeDrive] Error getting details: $e');
      return null;
    }
  }

  /// Extrai TODAS as opções de qualidade/servidor de um episódio
  /// Retorna lista com todas as opções disponíveis (Mobile, HD, FullHD, FHD)
  static Future<List<VideoOption>> getVideoOptions(String episodeUrl) async {
    try {
      debugPrint('[AnimeDrive] Getting ALL video options for: $episodeUrl');

      final url = episodeUrl.startsWith('http')
          ? episodeUrl
          : '$_baseUrl$episodeUrl';

      final response = await http
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final body = response.body;
        final document = html_parser.parse(body);
        final options = <VideoOption>[];

        // Busca TODAS as opções de player/servidor
        // O site usa li com classe dooplay_player_option
        final playerOptions = document.querySelectorAll(
          '.dooplay_player_option, '
          '[class*="player_option"], '
          '.source-box li, '
          '.player_nav li, '
          '.server-item',
        );

        debugPrint('[AnimeDrive] Found ${playerOptions.length} player options');

        int serverIndex = 0;
        for (final option in playerOptions) {
          try {
            final dataPost = option.attributes['data-post'];
            final dataType = option.attributes['data-type'] ?? 'tv';
            final dataNume =
                option.attributes['data-nume'] ?? '${serverIndex + 1}';

            // Extrai label do servidor
            final serverLabel =
                option.querySelector('.title, .server, span')?.text.trim() ??
                option.text.trim();

            // Detecta qualidade pelo label
            final quality = VideoQuality.fromLabel(serverLabel);

            if (dataPost != null) {
              options.add(
                VideoOption(
                  label: serverLabel.isNotEmpty
                      ? serverLabel
                      : 'Server ${serverIndex + 1}',
                  quality: quality,
                  serverName: 'Server ${serverIndex + 1}',
                  serverIndex: serverIndex,
                  postId: dataPost,
                  type: dataType,
                  nume: dataNume,
                ),
              );

              debugPrint(
                '[AnimeDrive] Option: $serverLabel (post=$dataPost, nume=$dataNume)',
              );
            }

            serverIndex++;
          } catch (e) {
            debugPrint('[AnimeDrive] Error parsing option: $e');
          }
        }

        // Se não encontrou opções estruturadas, tenta extrair de outros elementos
        if (options.isEmpty) {
          final allDataOptions = document.querySelectorAll(
            '[data-post][data-nume]',
          );

          for (int i = 0; i < allDataOptions.length; i++) {
            final option = allDataOptions[i];
            final dataPost = option.attributes['data-post'];
            final dataType = option.attributes['data-type'] ?? 'tv';
            final dataNume = option.attributes['data-nume'] ?? '${i + 1}';
            final label = option.text.trim();

            if (dataPost != null) {
              options.add(
                VideoOption(
                  label: label.isNotEmpty ? label : 'Server ${i + 1}',
                  quality: VideoQuality.fromLabel(label),
                  serverName: 'Server ${i + 1}',
                  serverIndex: i,
                  postId: dataPost,
                  type: dataType,
                  nume: dataNume,
                ),
              );
            }
          }
        }

        debugPrint('[AnimeDrive] Total video options: ${options.length}');
        return options;
      } else {
        debugPrint('[AnimeDrive] Failed to get page: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('[AnimeDrive] Error getting video options: $e');
      return [];
    }
  }

  /// Resolve o URL do vídeo para uma opção específica
  /// Retorna também o tipo (mp4 ou iframe) para priorização
  static Future<Map<String, String>?> resolveVideoUrlWithType(
    VideoOption option,
  ) async {
    try {
      if (option.videoUrl != null) {
        return {'url': option.videoUrl!, 'type': 'mp4'};
      }

      if (option.postId == null || option.nume == null) {
        return null;
      }

      debugPrint(
        '[AnimeDrive] Resolving video for: ${option.label} (nume=${option.nume})',
      );

      final apiUrl =
          '$_baseUrl/wp-json/dooplayer/v2/${option.postId}/${option.type ?? 'tv'}/${option.nume}';

      final apiResponse = await http
          .get(Uri.parse(apiUrl), headers: {..._headers, 'Referer': _baseUrl})
          .timeout(const Duration(seconds: 15));

      if (apiResponse.statusCode == 200) {
        final apiData = json.decode(apiResponse.body);
        final embedUrl = apiData['embed_url'] as String?;
        final videoType = apiData['type'] as String? ?? 'iframe';

        if (embedUrl != null) {
          debugPrint('[AnimeDrive] Got embed URL ($videoType): $embedUrl');

          // Se é MP4 direto, extrai a source
          if (videoType == 'mp4') {
            final sourceMatch = RegExp(r'source=([^&]+)').firstMatch(embedUrl);
            if (sourceMatch != null) {
              final encodedSource = sourceMatch.group(1)!;
              final decodedSource = Uri.decodeComponent(encodedSource);
              debugPrint('[AnimeDrive] Extracted MP4: $decodedSource');
              return {'url': decodedSource, 'type': 'mp4'};
            }
          }

          // Se é um link m3u8/HLS direto
          if (embedUrl.contains('.m3u8')) {
            return {'url': embedUrl, 'type': 'hls'};
          }

          // Retorna iframe para outros tipos
          return {'url': embedUrl, 'type': videoType};
        }
      }

      return null;
    } catch (e) {
      debugPrint('[AnimeDrive] Error resolving video URL: $e');
      return null;
    }
  }

  /// Resolve o URL do vídeo para uma opção específica (compatibilidade)
  static Future<String?> resolveVideoUrl(VideoOption option) async {
    final result = await resolveVideoUrlWithType(option);
    return result?['url'];
  }

  /// Lista de domínios confiáveis que funcionam bem com players
  /// Prioriza estes sobre outros domínios
  static const List<String> _preferredDomains = [
    'tityos.feralhosting.com', // Mais confiável, sem CORS
    'feralhosting.com',
    'archive.org',
  ];

  /// Domínios que podem ter problemas de CORS/bloqueio
  static const List<String> _problematicDomains = [
    'aniplay.online', // Bloqueia requests de apps
    'animeshd.cloud',
    'animes.strp2p.com',
  ];

  /// Verifica se uma URL é de um domínio preferido
  static bool _isPreferredDomain(String url) {
    final lower = url.toLowerCase();
    return _preferredDomains.any((d) => lower.contains(d));
  }

  /// Verifica se uma URL é de um domínio problemático
  static bool _isProblematicDomain(String url) {
    final lower = url.toLowerCase();
    return _problematicDomains.any((d) => lower.contains(d));
  }

  /// Extrai o link direto do MP4 de um episódio (melhor qualidade disponível)
  /// Prioriza servidores confiáveis (tityos) sobre problemáticos (aniplay)
  static Future<String?> getVideoUrl(String episodeUrl) async {
    try {
      debugPrint('[AnimeDrive] Getting video URL for: $episodeUrl');

      // Primeiro busca todas as opções
      final options = await getVideoOptions(episodeUrl);

      if (options.isEmpty) {
        return await _getVideoUrlFallback(episodeUrl);
      }

      // Coleta todas as URLs MP4 disponíveis
      final List<Map<String, dynamic>> allMp4Links = [];

      for (final option in options) {
        final result = await resolveVideoUrlWithType(option);
        if (result != null &&
            result['type'] == 'mp4' &&
            result['url']!.isNotEmpty) {
          allMp4Links.add({
            'url': result['url'],
            'option': option,
            'preferred': _isPreferredDomain(result['url']!),
            'problematic': _isProblematicDomain(result['url']!),
          });
          debugPrint(
            '[AnimeDrive] Found MP4: ${option.label} -> ${result['url']} (preferred: ${_isPreferredDomain(result['url']!)})',
          );
        }
      }

      // Ordena: domínios preferidos primeiro, problemáticos por último
      allMp4Links.sort((a, b) {
        // Preferidos vêm primeiro
        if (a['preferred'] && !b['preferred']) return -1;
        if (!a['preferred'] && b['preferred']) return 1;
        // Problemáticos vão por último
        if (a['problematic'] && !b['problematic']) return 1;
        if (!a['problematic'] && b['problematic']) return -1;
        return 0;
      });

      // Retorna o primeiro link da lista ordenada
      if (allMp4Links.isNotEmpty) {
        final best = allMp4Links.first;
        debugPrint(
          '[AnimeDrive] Selected best: ${best['url']} (preferred: ${best['preferred']})',
        );
        return best['url'] as String;
      }

      // Fallback: tenta iframes
      debugPrint('[AnimeDrive] No MP4 found, trying iframes...');
      for (final option in options) {
        final result = await resolveVideoUrlWithType(option);
        if (result != null && result['type'] == 'iframe') {
          final iframeUrl = result['url']!;
          debugPrint('[AnimeDrive] Trying iframe: $iframeUrl');

          final extractedUrl = await _extractFromIframe(iframeUrl);
          if (extractedUrl != null && extractedUrl.isNotEmpty) {
            debugPrint('[AnimeDrive] Extracted from iframe: $extractedUrl');
            return extractedUrl;
          }
        }
      }

      return await _getVideoUrlFallback(episodeUrl);
    } catch (e) {
      debugPrint('[AnimeDrive] Error getting video URL: $e');
      return null;
    }
  }

  /// Método fallback para extrair vídeo
  static Future<String?> _getVideoUrlFallback(String episodeUrl) async {
    try {
      debugPrint('[AnimeDrive] Using fallback method for: $episodeUrl');

      final url = episodeUrl.startsWith('http')
          ? episodeUrl
          : '$_baseUrl$episodeUrl';

      final response = await http
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final body = response.body;
        final document = html_parser.parse(body);

        // MÉTODO PRINCIPAL: Usa a API dooplayer
        // Busca data-post e data-nume do player
        final playerOption = document.querySelector(
          '.dooplay_player_option, [class*="player_option"]',
        );

        if (playerOption != null) {
          final dataPost = playerOption.attributes['data-post'];
          final dataType = playerOption.attributes['data-type'] ?? 'tv';
          final dataNume = playerOption.attributes['data-nume'] ?? '1';

          if (dataPost != null) {
            debugPrint(
              '[AnimeDrive] Found player data: post=$dataPost, type=$dataType, nume=$dataNume',
            );

            // Chama a API dooplayer
            final apiUrl =
                '$_baseUrl/wp-json/dooplayer/v2/$dataPost/$dataType/$dataNume';
            debugPrint('[AnimeDrive] Calling dooplayer API: $apiUrl');

            final apiResponse = await http
                .get(Uri.parse(apiUrl), headers: {..._headers, 'Referer': url})
                .timeout(const Duration(seconds: 15));

            if (apiResponse.statusCode == 200) {
              final apiData = json.decode(apiResponse.body);
              final embedUrl = apiData['embed_url'] as String?;

              if (embedUrl != null) {
                debugPrint('[AnimeDrive] Got embed URL: $embedUrl');

                // Extrai o source do embed_url (formato: jwplayer?source=URL_ENCODED)
                final sourceMatch = RegExp(
                  r'source=([^&]+)',
                ).firstMatch(embedUrl);
                if (sourceMatch != null) {
                  final encodedSource = sourceMatch.group(1)!;
                  final decodedSource = Uri.decodeComponent(encodedSource);
                  debugPrint('[AnimeDrive] Extracted MP4: $decodedSource');
                  return decodedSource;
                }

                // Se não encontrou source, retorna o embed_url diretamente
                return embedUrl;
              }
            }
          }
        }

        // Tenta extrair de outros elementos player
        final allPlayerOptions = document.querySelectorAll(
          '[data-post][data-nume], .dooplay_player_option',
        );
        for (final option in allPlayerOptions) {
          final dataPost = option.attributes['data-post'];
          final dataType = option.attributes['data-type'] ?? 'tv';
          final dataNume = option.attributes['data-nume'] ?? '1';

          if (dataPost != null) {
            final apiUrl =
                '$_baseUrl/wp-json/dooplayer/v2/$dataPost/$dataType/$dataNume';

            try {
              final apiResponse = await http
                  .get(
                    Uri.parse(apiUrl),
                    headers: {..._headers, 'Referer': url},
                  )
                  .timeout(const Duration(seconds: 10));

              if (apiResponse.statusCode == 200) {
                final apiData = json.decode(apiResponse.body);
                final embedUrl = apiData['embed_url'] as String?;

                if (embedUrl != null) {
                  final sourceMatch = RegExp(
                    r'source=([^&]+)',
                  ).firstMatch(embedUrl);
                  if (sourceMatch != null) {
                    final decodedSource = Uri.decodeComponent(
                      sourceMatch.group(1)!,
                    );
                    debugPrint(
                      '[AnimeDrive] Extracted MP4 from option: $decodedSource',
                    );
                    return decodedSource;
                  }
                }
              }
            } catch (e) {
              debugPrint('[AnimeDrive] Error with option: $e');
            }
          }
        }

        // Fallback: Busca link MP4 direto na página
        final tityosMatch = RegExp(
          'https?://tityos\\.feralhosting\\.com/[^\\s<>"]+\\.mp4',
          caseSensitive: false,
        ).firstMatch(body);

        if (tityosMatch != null) {
          final videoUrl = tityosMatch.group(0);
          debugPrint('[AnimeDrive] Found tityos URL: $videoUrl');
          return videoUrl;
        }

        // Método 2: Busca qualquer link MP4 direto
        final mp4Match = RegExp(
          'https?://[^\\s<>"]+\\.mp4',
          caseSensitive: false,
        ).firstMatch(body);

        if (mp4Match != null) {
          final videoUrl = mp4Match.group(0);
          debugPrint('[AnimeDrive] Found MP4 URL: $videoUrl');
          return videoUrl;
        }

        // Método 3: Busca em iframes do player
        final iframes = document.querySelectorAll('iframe');

        for (final iframe in iframes) {
          final iframeSrc =
              iframe.attributes['src'] ?? iframe.attributes['data-src'] ?? '';
          if (iframeSrc.isNotEmpty) {
            debugPrint('[AnimeDrive] Found iframe: $iframeSrc');

            // Tenta extrair do iframe
            final iframeUrl = await _extractFromIframe(iframeSrc);
            if (iframeUrl != null) {
              return iframeUrl;
            }
          }
        }

        // Método 4: Busca em scripts por configurações de player
        final scripts = document.querySelectorAll('script');
        for (final script in scripts) {
          final scriptContent = script.text;

          // Busca por file: "url" ou source: "url" comum em players
          final fileMatch = RegExp(
            '(?:file|source|src|url)\\s*[=:]\\s*["\']([^"\']+\\.mp4)',
            caseSensitive: false,
          ).firstMatch(scriptContent);

          if (fileMatch != null) {
            final videoUrl = fileMatch.group(1);
            debugPrint('[AnimeDrive] Found in script: $videoUrl');
            return videoUrl;
          }

          // Busca por links HLS/M3U8
          final hlsMatch = RegExp(
            '["\']([^"\']+\\.m3u8[^"\']*)["\']',
            caseSensitive: false,
          ).firstMatch(scriptContent);

          if (hlsMatch != null) {
            final hlsUrl = hlsMatch.group(1);
            debugPrint('[AnimeDrive] Found HLS: $hlsUrl');
            return hlsUrl;
          }
        }

        // Método 5: Busca por data attributes
        final videoElements = document.querySelectorAll(
          '[data-video], [data-src], [data-url]',
        );
        for (final element in videoElements) {
          final dataVideo =
              element.attributes['data-video'] ??
              element.attributes['data-src'] ??
              element.attributes['data-url'] ??
              '';
          if (dataVideo.contains('.mp4') || dataVideo.contains('.m3u8')) {
            debugPrint('[AnimeDrive] Found data attribute: $dataVideo');
            return dataVideo;
          }
        }

        debugPrint('[AnimeDrive] No video URL found in page');
        return null;
      } else {
        debugPrint('[AnimeDrive] Failed to get page: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('[AnimeDrive] Fallback error: $e');
      return null;
    }
  }

  /// Tenta extrair URL do vídeo de um iframe
  static Future<String?> _extractFromIframe(String iframeUrl) async {
    try {
      // Normaliza URL
      String url = iframeUrl;
      if (url.startsWith('//')) {
        url = 'https:$url';
      }

      final response = await http
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = response.body;

        // Busca MP4
        final mp4Match = RegExp(
          'https?://[^\\s<>"]+\\.mp4',
          caseSensitive: false,
        ).firstMatch(body);

        if (mp4Match != null) {
          return mp4Match.group(0);
        }

        // Busca M3U8
        final m3u8Match = RegExp(
          'https?://[^\\s<>"]+\\.m3u8',
          caseSensitive: false,
        ).firstMatch(body);

        if (m3u8Match != null) {
          return m3u8Match.group(0);
        }
      }
    } catch (e) {
      debugPrint('[AnimeDrive] Error extracting from iframe: $e');
    }
    return null;
  }

  /// Busca animes recentes/lançamentos
  static Future<List<AnimeDriveShow>> getLatestReleases() async {
    try {
      debugPrint('[AnimeDrive] Getting latest releases');

      final response = await http
          .get(Uri.parse(_baseUrl), headers: _headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);
        final results = <AnimeDriveShow>[];

        // Busca últimos episódios lançados
        final items = document.querySelectorAll(
          '.items article, '
          '.animation-2 .item, '
          '#archive-content article, '
          '.content article.item',
        );

        for (final item in items) {
          try {
            final linkElement = item.querySelector('a');
            final titleElement = item.querySelector('h3, .data h3, .title');
            final imageElement = item.querySelector('img');
            final ratingElement = item.querySelector('.rating, .score');
            final yearElement = item.querySelector('.year, span.year');

            if (linkElement != null) {
              final url = linkElement.attributes['href'] ?? '';
              final title =
                  titleElement?.text.trim() ??
                  linkElement.attributes['title'] ??
                  '';
              final image =
                  imageElement?.attributes['src'] ??
                  imageElement?.attributes['data-src'] ??
                  '';
              final rating = ratingElement?.text.trim();
              final year = yearElement?.text.trim();
              final isDubbed = title.toLowerCase().contains('dublado');

              if (url.contains('/anime/') && title.isNotEmpty) {
                results.add(
                  AnimeDriveShow(
                    id: _extractIdFromUrl(url),
                    title: title,
                    url: url,
                    thumbnail: image,
                    rating: rating,
                    year: year,
                    isDubbed: isDubbed,
                  ),
                );
              }
            }
          } catch (e) {
            // Ignora erros de parsing individual
          }
        }

        debugPrint('[AnimeDrive] Found ${results.length} latest releases');
        return results;
      }
      return [];
    } catch (e) {
      debugPrint('[AnimeDrive] Error getting latest: $e');
      return [];
    }
  }

  /// Busca filmes disponíveis
  static Future<List<AnimeDriveShow>> getFilms({int page = 1}) async {
    try {
      debugPrint('[AnimeDrive] Getting films page $page');

      final pageUrl = page == 1
          ? '$_baseUrl/filme/'
          : '$_baseUrl/filme/page/$page/';

      final response = await http
          .get(Uri.parse(pageUrl), headers: _headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);
        final results = <AnimeDriveShow>[];

        final items = document.querySelectorAll('article.item, .items article');

        for (final item in items) {
          try {
            final linkElement = item.querySelector('a[href*="/filme/"]');
            final titleElement = item.querySelector('h3, h2, .title');
            final imageElement = item.querySelector('img');
            final ratingElement = item.querySelector('.rating, .score');

            final url = linkElement?.attributes['href'] ?? '';
            if (url.isEmpty) continue;

            final title = titleElement?.text.trim() ?? '';
            if (title.isEmpty) continue;

            final image = imageElement?.attributes['src'] ?? '';
            final rating = ratingElement?.text.trim();

            results.add(
              AnimeDriveShow(
                id: _extractIdFromUrl(url),
                title: title,
                url: url,
                thumbnail: image,
                rating: rating,
                isDubbed: title.toLowerCase().contains('dublado'),
              ),
            );
          } catch (e) {
            debugPrint('[AnimeDrive] Error parsing film: $e');
          }
        }

        debugPrint('[AnimeDrive] Found ${results.length} films');
        return results;
      }
      return [];
    } catch (e) {
      debugPrint('[AnimeDrive] Error getting films: $e');
      return [];
    }
  }

  /// Extrai ID de uma URL
  static String _extractIdFromUrl(String url) {
    // Remove trailing slash e extrai último segmento
    final cleanUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    final parts = cleanUrl.split('/');
    return parts.isNotEmpty ? parts.last : '';
  }
}

/// Modelo de gênero do AnimeDrive
class AnimeDriveGenre {
  final String id;
  final String name;
  final String url;

  AnimeDriveGenre({required this.id, required this.name, required this.url});

  @override
  String toString() => 'AnimeDriveGenre(id: $id, name: $name)';
}

/// Modelo de anime do AnimeDrive
class AnimeDriveShow {
  final String id;
  final String title;
  final String url;
  final String? thumbnail;
  final String? rating;
  final String? year;
  final bool isDubbed;

  AnimeDriveShow({
    required this.id,
    required this.title,
    required this.url,
    this.thumbnail,
    this.rating,
    this.year,
    this.isDubbed = false,
  });

  @override
  String toString() =>
      'AnimeDriveShow(id: $id, title: $title, dubbed: $isDubbed)';
}

/// Modelo de episódio do AnimeDrive
class AnimeDriveEpisode {
  final String number;
  final String title;
  final String url;
  final String? thumbnail;
  final List<String>? qualities; // SD, HD, FHD disponíveis

  AnimeDriveEpisode({
    required this.number,
    required this.title,
    required this.url,
    this.thumbnail,
    this.qualities,
  });

  @override
  String toString() => 'AnimeDriveEpisode(number: $number, title: $title)';
}

/// Modelo de detalhes do anime
class AnimeDriveDetails {
  final String id;
  final String title;
  final String url;
  final String? thumbnail;
  final String? synopsis;
  final List<AnimeDriveEpisode> episodes;

  AnimeDriveDetails({
    required this.id,
    required this.title,
    required this.url,
    this.thumbnail,
    this.synopsis,
    required this.episodes,
  });

  @override
  String toString() =>
      'AnimeDriveDetails(id: $id, title: $title, episodes: ${episodes.length})';
}
