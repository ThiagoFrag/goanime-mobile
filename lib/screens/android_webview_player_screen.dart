import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../main.dart';
import '../theme/app_colors.dart';
import '../services/allanime_service.dart';
import '../services/animedrive_service.dart';

/// Player de vídeo usando WebView para Android
/// Mais compatível com diferentes fontes de vídeo HLS
class AndroidWebViewPlayerScreen extends StatefulWidget {
  final Episode episode;
  final String animeTitle;
  final Anime? anime;

  const AndroidWebViewPlayerScreen({
    super.key,
    required this.episode,
    required this.animeTitle,
    this.anime,
  });

  @override
  State<AndroidWebViewPlayerScreen> createState() =>
      _AndroidWebViewPlayerScreenState();
}

class _AndroidWebViewPlayerScreenState
    extends State<AndroidWebViewPlayerScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _errorMessage;
  String? _videoUrl;
  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      // Obter URL do vídeo
      String? videoSrc;

      if (widget.anime?.source == AnimeSource.allAnime) {
        debugPrint('[WebViewPlayer] Getting AllAnime episode URL');
        final animeId = widget.anime!.allAnimeId ?? widget.anime!.url;
        final episodeNo = widget.episode.url;
        videoSrc = await AllAnimeService.getEpisodeURL(animeId, episodeNo);
      } else if (widget.anime?.source == AnimeSource.animeDrive) {
        debugPrint('[WebViewPlayer] Getting AnimeDrive episode URL');
        videoSrc = await AnimeDriveService.getVideoUrl(widget.episode.url);
      } else {
        debugPrint('[WebViewPlayer] Getting AnimeFire episode URL');
        final extractedUrl =
            await AnimeService.extractVideoURL(widget.episode.url);
        if (extractedUrl.isNotEmpty) {
          final actualVideo =
              await AnimeService.extractActualVideoURL(extractedUrl);
          videoSrc = actualVideo.url;
        }
      }

      if (videoSrc == null || videoSrc.isEmpty) {
        // Tentar AllAnime como fallback
        debugPrint('[WebViewPlayer] Trying AllAnime as fallback...');
        videoSrc = await _tryAllAnimeFallback();
      }

      if (videoSrc == null || videoSrc.isEmpty) {
        throw Exception('Não foi possível obter a URL do vídeo');
      }

      _videoUrl = videoSrc;
      debugPrint('[WebViewPlayer] Video URL: $_videoUrl');

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _setupWebView();
      }
    } catch (e) {
      debugPrint('[WebViewPlayer] Error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<String?> _tryAllAnimeFallback() async {
    try {
      // Limpar título para busca
      String searchTitle = widget.animeTitle
          .replaceAll(RegExp(r'\s*\(Dublado\)\s*', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s*\(Legendado\)\s*', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s*-\s*Episódio.*', caseSensitive: false), '')
          .trim();

      debugPrint('[WebViewPlayer] Searching AllAnime for: $searchTitle');

      final searchResult = await AllAnimeService.searchAnime(searchTitle);

      if (searchResult == null || searchResult.shows.isEmpty) {
        debugPrint('[WebViewPlayer] No results from AllAnime');
        return null;
      }

      // Encontrar melhor match
      final normalizedSearch = searchTitle.toLowerCase();
      AllAnimeShow? bestMatch;

      for (final show in searchResult.shows) {
        final showName = (show.name).toLowerCase();
        final englishName = (show.englishName ?? '').toLowerCase();

        if (showName == normalizedSearch ||
            englishName == normalizedSearch ||
            showName.contains(normalizedSearch) ||
            englishName.contains(normalizedSearch)) {
          bestMatch = show;
          break;
        }
      }

      bestMatch ??= searchResult.shows.first;
      debugPrint('[WebViewPlayer] Using AllAnime show: ${bestMatch.name}');

      // Extrair número do episódio
      final episodeMatch = RegExp(r'(\d+)').firstMatch(widget.episode.number);
      final episodeNum = episodeMatch?.group(1) ?? '1';

      // Obter URL do episódio
      final videoUrl = await AllAnimeService.getEpisodeURL(
        bestMatch.id,
        episodeNum,
      );

      return videoUrl;
    } catch (e) {
      debugPrint('[WebViewPlayer] AllAnime fallback failed: $e');
      return null;
    }
  }

  void _setupWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            debugPrint('[WebViewPlayer] Page loaded: $url');
          },
          onWebResourceError: (error) {
            debugPrint('[WebViewPlayer] WebResource error: ${error.description}');
          },
        ),
      )
      ..loadHtmlString(_buildHlsPlayerHtml());
  }

  String _buildHlsPlayerHtml() {
    final videoUrl = _videoUrl ?? '';
    final title = '${widget.animeTitle} - Ep ${widget.episode.number}';
    final escapedUrl = jsonEncode(videoUrl);
    final escapedTitle = jsonEncode(title);

    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <title>$title</title>
    <script src="https://cdn.jsdelivr.net/npm/hls.js@latest"></script>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        html, body {
            width: 100%;
            height: 100%;
            background: #000;
            overflow: hidden;
        }
        .container {
            width: 100%;
            height: 100%;
            display: flex;
            flex-direction: column;
            justify-content: center;
            align-items: center;
            background: #000;
        }
        video {
            width: 100%;
            height: 100%;
            max-width: 100vw;
            max-height: 100vh;
            object-fit: contain;
            background: #000;
        }
        .loading {
            position: absolute;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            color: #FF6B35;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            font-size: 16px;
            text-align: center;
        }
        .spinner {
            width: 40px;
            height: 40px;
            border: 3px solid rgba(255, 107, 53, 0.3);
            border-top-color: #FF6B35;
            border-radius: 50%;
            animation: spin 1s linear infinite;
            margin: 0 auto 16px;
        }
        @keyframes spin {
            to { transform: rotate(360deg); }
        }
        .error {
            color: #ff4444;
            padding: 20px;
            text-align: center;
        }
        .title {
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            padding: 16px;
            background: linear-gradient(to bottom, rgba(0,0,0,0.8), transparent);
            color: white;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            font-size: 14px;
            font-weight: 500;
            z-index: 10;
            opacity: 0;
            transition: opacity 0.3s;
        }
        .container:hover .title,
        .container.controls-visible .title {
            opacity: 1;
        }
        video::-webkit-media-controls {
            display: flex !important;
        }
    </style>
</head>
<body>
    <div class="container" id="container">
        <div class="title" id="title"></div>
        <div class="loading" id="loading">
            <div class="spinner"></div>
            <div>Carregando vídeo...</div>
        </div>
        <video id="video" controls playsinline autoplay></video>
    </div>

    <script>
        const videoUrl = $escapedUrl;
        const videoTitle = $escapedTitle;
        const video = document.getElementById('video');
        const loading = document.getElementById('loading');
        const container = document.getElementById('container');
        const titleEl = document.getElementById('title');
        
        titleEl.textContent = videoTitle;

        function hideLoading() {
            loading.style.display = 'none';
        }

        function showError(message) {
            loading.innerHTML = '<div class="error">' + message + '</div>';
        }

        function initPlayer() {
            if (!videoUrl) {
                showError('URL do vídeo não disponível');
                return;
            }

            // Check if HLS is needed
            const isHLS = videoUrl.includes('.m3u8') || videoUrl.includes('m3u8');
            
            if (isHLS && Hls.isSupported()) {
                console.log('Using HLS.js');
                const hls = new Hls({
                    maxLoadingDelay: 4,
                    maxBufferLength: 30,
                    maxBufferSize: 60 * 1000 * 1000,
                    enableWorker: true,
                    lowLatencyMode: false,
                    backBufferLength: 30,
                    xhrSetup: function(xhr, url) {
                        xhr.withCredentials = false;
                    }
                });
                
                hls.loadSource(videoUrl);
                hls.attachMedia(video);
                
                hls.on(Hls.Events.MANIFEST_PARSED, function() {
                    console.log('HLS manifest parsed');
                    hideLoading();
                    video.play().catch(function(e) {
                        console.log('Autoplay prevented:', e);
                    });
                });
                
                hls.on(Hls.Events.ERROR, function(event, data) {
                    console.error('HLS error:', data);
                    if (data.fatal) {
                        switch(data.type) {
                            case Hls.ErrorTypes.NETWORK_ERROR:
                                console.log('Network error, trying to recover...');
                                hls.startLoad();
                                break;
                            case Hls.ErrorTypes.MEDIA_ERROR:
                                console.log('Media error, trying to recover...');
                                hls.recoverMediaError();
                                break;
                            default:
                                showError('Erro ao carregar vídeo: ' + data.details);
                                hls.destroy();
                                break;
                        }
                    }
                });
            } else if (video.canPlayType('application/vnd.apple.mpegurl')) {
                // Native HLS support (Safari/iOS)
                console.log('Using native HLS');
                video.src = videoUrl;
                video.addEventListener('loadedmetadata', function() {
                    hideLoading();
                    video.play().catch(function(e) {
                        console.log('Autoplay prevented:', e);
                    });
                });
            } else {
                // Direct video source
                console.log('Using direct source');
                video.src = videoUrl;
                video.addEventListener('loadeddata', function() {
                    hideLoading();
                });
                video.addEventListener('canplay', function() {
                    hideLoading();
                    video.play().catch(function(e) {
                        console.log('Autoplay prevented:', e);
                    });
                });
            }

            video.addEventListener('error', function(e) {
                console.error('Video error:', e);
                showError('Erro ao reproduzir vídeo');
            });

            // Show/hide title on touch
            let touchTimeout;
            container.addEventListener('touchstart', function() {
                container.classList.add('controls-visible');
                clearTimeout(touchTimeout);
                touchTimeout = setTimeout(function() {
                    container.classList.remove('controls-visible');
                }, 3000);
            });
        }

        // Start player
        initPlayer();
    </script>
</body>
</html>
''';
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });

    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _isFullscreen
          ? null
          : AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 0,
              title: Text(
                '${widget.animeTitle} - Ep ${widget.episode.number}',
                style: const TextStyle(fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                IconButton(
                  icon: Icon(_isFullscreen
                      ? Icons.fullscreen_exit
                      : Icons.fullscreen),
                  onPressed: _toggleFullscreen,
                ),
              ],
            ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: AppColors.primary,
            ),
            SizedBox(height: 16),
            Text(
              'Carregando vídeo...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                'Erro no Player',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                  });
                  _initializePlayer();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar Novamente'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onDoubleTap: _toggleFullscreen,
      child: WebViewWidget(controller: _controller),
    );
  }
}
