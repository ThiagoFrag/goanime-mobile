import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../services/allanime_service.dart';
import '../services/animedrive_service.dart';
import '../main.dart'; // For Episode, Anime, AnimeSource, AnimeService
import '../theme/app_colors.dart';

/// Desktop Video Player using media_kit for Windows/Linux/macOS
class DesktopVideoPlayerScreen extends StatefulWidget {
  final Episode episode;
  final String animeTitle;
  final Anime? anime;

  const DesktopVideoPlayerScreen({
    super.key,
    required this.episode,
    required this.animeTitle,
    this.anime,
  });

  @override
  State<DesktopVideoPlayerScreen> createState() =>
      _DesktopVideoPlayerScreenState();
}

class _DesktopVideoPlayerScreenState extends State<DesktopVideoPlayerScreen> {
  late final Player _player;
  late final VideoController _controller;
  bool _isLoading = true;
  String? _errorMessage;
  bool _showControls = true;
  Timer? _hideControlsTimer;
  
  // Playback state
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  bool _isBuffering = false;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    _setupListeners();
    _initializePlayer();
  }

  void _setupListeners() {
    _player.stream.playing.listen((playing) {
      if (mounted) setState(() => _isPlaying = playing);
    });
    
    _player.stream.position.listen((position) {
      if (mounted) setState(() => _position = position);
    });
    
    _player.stream.duration.listen((duration) {
      if (mounted) setState(() => _duration = duration);
    });
    
    _player.stream.buffering.listen((buffering) {
      if (mounted) setState(() => _isBuffering = buffering);
    });
    
    _player.stream.error.listen((error) {
      if (mounted && error.isNotEmpty) {
        setState(() {
          _errorMessage = error;
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _initializePlayer() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String? videoSrc;
      Map<String, String> headers = {};

      // Extract episode number from various formats
      final episodeNumber = _extractEpisodeNumber(widget.episode.number);
      debugPrint('[DesktopPlayer] Episode number extracted: $episodeNumber');

      // Check if AnimeDrive source (direct MP4)
      if (widget.anime?.source == AnimeSource.animeDrive) {
        debugPrint('[DesktopPlayer] Using AnimeDrive source...');
        videoSrc = await AnimeDriveService.getVideoUrl(widget.episode.url);
        if (videoSrc != null && videoSrc.isNotEmpty) {
          headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Referer': 'https://animesdrive.blog/',
          };
          debugPrint('[DesktopPlayer] AnimeDrive video URL: $videoSrc');
          await _playVideo(videoSrc, headers);
          return;
        }
      }

      // Try AllAnime first (more reliable for desktop)
      debugPrint('[DesktopPlayer] Trying AllAnime source...');
      
      String? allAnimeId = widget.anime?.allAnimeId;
      
      // If we don't have AllAnime ID, search for the anime
      if (allAnimeId == null || allAnimeId.isEmpty) {
        debugPrint('[DesktopPlayer] No AllAnime ID, searching by title: ${widget.animeTitle}');
        final searchResult = await _searchAllAnimeByTitle(widget.animeTitle);
        if (searchResult != null) {
          allAnimeId = searchResult;
          debugPrint('[DesktopPlayer] Found AllAnime ID: $allAnimeId');
        }
      }

      if (allAnimeId != null && allAnimeId.isNotEmpty) {
        try {
          // Try both sub and dub modes
          final isDub = widget.animeTitle.toLowerCase().contains('dublado') ||
                        widget.animeTitle.toLowerCase().contains('dub');
          final mode = isDub ? 'dub' : 'sub';
          
          var allAnimeUrl = await AllAnimeService.getEpisodeURL(
            allAnimeId,
            episodeNumber,
            mode: mode,
          );

          // If failed, try the other mode
          if (allAnimeUrl == null || allAnimeUrl.isEmpty) {
            final altMode = mode == 'sub' ? 'dub' : 'sub';
            debugPrint('[DesktopPlayer] Trying $altMode mode...');
            allAnimeUrl = await AllAnimeService.getEpisodeURL(
              allAnimeId,
              episodeNumber,
              mode: altMode,
            );
          }

          if (allAnimeUrl != null && allAnimeUrl.isNotEmpty) {
            videoSrc = allAnimeUrl;
            headers = {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
              'Origin': 'https://allanime.to',
              'Referer': 'https://allanime.to/',
            };
            debugPrint('[DesktopPlayer] AllAnime video URL: $videoSrc');
            await _playVideo(videoSrc, headers);
            return;
          }
        } catch (e) {
          debugPrint('[DesktopPlayer] AllAnime failed: $e');
        }
      }

      // Fallback to AnimeFire
      debugPrint('[DesktopPlayer] Trying AnimeFire source...');
      videoSrc = await AnimeService.extractVideoURL(widget.episode.url);

      if (videoSrc.isEmpty) {
        throw Exception('Video URL not found on page');
      }

      // Get actual video URL
      final actualVideo = await AnimeService.extractActualVideoURL(videoSrc);
      if (actualVideo.url.isEmpty) {
        throw Exception('Video URL could not be extracted from API');
      }
      
      videoSrc = actualVideo.url;
      headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Referer': 'https://animefire.plus/',
        'Origin': 'https://animefire.plus',
      };
      
      // Add any headers from the extraction
      if (actualVideo.hasHeaders) {
        headers.addAll(actualVideo.headers);
      }

      debugPrint('[DesktopPlayer] AnimeFire video URL: $videoSrc');
      await _playVideo(videoSrc, headers);

    } catch (e) {
      debugPrint('[DesktopPlayer] Error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  /// Extract episode number from episode text
  String _extractEpisodeNumber(String episodeText) {
    // Try to extract number from text (e.g.: "Dandadan - Episódio 5" -> "5")
    final patterns = [
      RegExp(r'Episódio\s*(\d+)', caseSensitive: false),
      RegExp(r'Episode\s*(\d+)', caseSensitive: false),
      RegExp(r'Ep\.?\s*(\d+)', caseSensitive: false),
      RegExp(r'-\s*(\d+)$'),
      RegExp(r'(\d+)'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(episodeText);
      if (match != null) {
        return match.group(1) ?? match.group(0) ?? episodeText;
      }
    }

    return episodeText;
  }

  /// Search AllAnime by title and return the ID
  Future<String?> _searchAllAnimeByTitle(String title) async {
    try {
      // Clean title for better search
      String cleanTitle = title
          .replaceAll(RegExp(r'\(Dublado\)', caseSensitive: false), '')
          .replaceAll(RegExp(r'\(Legendado\)', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s+\d+\.\d+\s+A\d+'), '') // Remove "7.88 A14" etc
          .replaceAll(RegExp(r'\s+-\s+Episódio\s+\d+', caseSensitive: false), '')
          .trim();
      
      debugPrint('[DesktopPlayer] Searching AllAnime for: $cleanTitle');
      
      final searchResult = await AllAnimeService.searchAnime(cleanTitle);
      
      if (searchResult != null && searchResult.shows.isNotEmpty) {
        // Try to find best match
        for (final anime in searchResult.shows) {
          final animeName = anime.name.toLowerCase();
          final searchName = cleanTitle.toLowerCase();
          
          if (animeName.contains(searchName) || searchName.contains(animeName)) {
            debugPrint('[DesktopPlayer] Found match: ${anime.name} (${anime.id})');
            return anime.id;
          }
        }
        
        // If no exact match, return first result
        debugPrint('[DesktopPlayer] Using first result: ${searchResult.shows.first.name}');
        return searchResult.shows.first.id;
      }
      
      return null;
    } catch (e) {
      debugPrint('[DesktopPlayer] Search error: $e');
      return null;
    }
  }

  /// Play video with given URL and headers
  Future<void> _playVideo(String url, Map<String, String> headers) async {
    debugPrint('[DesktopPlayer] Playing video: $url');
    debugPrint('[DesktopPlayer] Headers: $headers');
    
    await _player.open(
      Media(url, httpHeaders: headers),
    );

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _player.dispose();
    super.dispose();
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    _resetHideTimer();
  }

  void _resetHideTimer() {
    _hideControlsTimer?.cancel();
    if (_showControls && _isPlaying) {
      _hideControlsTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _isPlaying) {
          setState(() => _showControls = false);
        }
      });
    }
  }

  void _togglePlayPause() {
    _player.playOrPause();
    _resetHideTimer();
  }

  void _seek(Duration position) {
    _player.seek(position);
  }

  void _skipForward() {
    final newPosition = _position + const Duration(seconds: 10);
    _seek(newPosition > _duration ? _duration : newPosition);
  }

  void _skipBackward() {
    final newPosition = _position - const Duration(seconds: 10);
    _seek(newPosition < Duration.zero ? Duration.zero : newPosition);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Video
          MouseRegion(
            onHover: (_) {
              if (!_showControls) {
                setState(() => _showControls = true);
              }
              _resetHideTimer();
            },
            child: GestureDetector(
              onTap: _toggleControls,
              onDoubleTap: _togglePlayPause,
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : _errorMessage != null
                      ? _buildErrorWidget()
                      : Video(
                          controller: _controller,
                          controls: NoVideoControls,
                        ),
            ),
          ),

          // Buffering indicator
          if (_isBuffering && !_isLoading)
            const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),

          // Custom controls overlay
          if (_showControls && !_isLoading && _errorMessage == null)
            _buildControlsOverlay(),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Player Error',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _initializePlayer,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsOverlay() {
    return AnimatedOpacity(
      opacity: _showControls ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.7),
              Colors.transparent,
              Colors.transparent,
              Colors.black.withValues(alpha: 0.8),
            ],
            stops: const [0.0, 0.2, 0.7, 1.0],
          ),
        ),
        child: Column(
          children: [
            // Top bar
            _buildTopBar(),
            
            // Center controls
            Expanded(
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildControlButton(
                      icon: Icons.replay_10,
                      onTap: _skipBackward,
                      size: 40,
                    ),
                    const SizedBox(width: 40),
                    _buildControlButton(
                      icon: _isPlaying ? Icons.pause : Icons.play_arrow,
                      onTap: _togglePlayPause,
                      size: 64,
                      isPrimary: true,
                    ),
                    const SizedBox(width: 40),
                    _buildControlButton(
                      icon: Icons.forward_10,
                      onTap: _skipForward,
                      size: 40,
                    ),
                  ],
                ),
              ),
            ),

            // Bottom bar
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.animeTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Episode ${widget.episode.number}',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress bar
            Row(
              children: [
                Text(
                  _formatDuration(_position),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 12,
                      ),
                      activeTrackColor: AppColors.primary,
                      inactiveTrackColor: Colors.grey[700],
                      thumbColor: AppColors.primary,
                      overlayColor: AppColors.primary.withValues(alpha: 0.2),
                    ),
                    child: Slider(
                      value: _duration.inMilliseconds > 0
                          ? _position.inMilliseconds.toDouble().clamp(
                              0, _duration.inMilliseconds.toDouble())
                          : 0,
                      min: 0,
                      max: _duration.inMilliseconds > 0
                          ? _duration.inMilliseconds.toDouble()
                          : 1,
                      onChanged: (value) {
                        _seek(Duration(milliseconds: value.toInt()));
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _formatDuration(_duration),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    double size = 48,
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size + 16,
        height: size + 16,
        decoration: BoxDecoration(
          color: isPrimary
              ? AppColors.primary.withValues(alpha: 0.9)
              : Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
          border: isPrimary
              ? null
              : Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: size * 0.6,
        ),
      ),
    );
  }
}

/// Helper to determine if we should use desktop player
bool get isDesktopPlatform {
  return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
}
