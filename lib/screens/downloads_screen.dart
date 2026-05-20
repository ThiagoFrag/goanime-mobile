import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

import '../services/download_service.dart';
import '../theme/app_colors.dart';

/// Downloads screen - Netflix-style UI for managing downloads
class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.accent, AppColors.accent.withValues(alpha: 0.7)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.download_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Downloads',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.settings_outlined, color: AppColors.textPrimary),
              onPressed: () => _showSettingsDialog(context),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.accent, AppColors.accent.withValues(alpha: 0.8)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorPadding: const EdgeInsets.all(4),
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: 'Ativos'),
                Tab(text: 'Completos'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_ActiveDownloadsTab(), _CompletedDownloadsTab()],
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    final downloadService = context.read<DownloadService>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Download Settings',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text(
                'Max Concurrent Downloads',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              subtitle: Slider(
                value: downloadService.maxConcurrentDownloads.toDouble(),
                min: 1,
                max: 5,
                divisions: 4,
                label: downloadService.maxConcurrentDownloads.toString(),
                onChanged: (value) {
                  downloadService.maxConcurrentDownloads = value.toInt();
                },
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                downloadService.clearCompleted();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Clear All Completed'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

/// Active downloads tab
class _ActiveDownloadsTab extends StatelessWidget {
  const _ActiveDownloadsTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<DownloadService>(
      builder: (context, downloadService, _) {
        final activeDownloads = downloadService.activeDownloads;

        if (activeDownloads.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.download_outlined,
                  size: 64,
                  color: AppColors.textSecondary,
                ),
                SizedBox(height: 16),
                Text(
                  'No active downloads',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: activeDownloads.length,
          itemBuilder: (context, index) {
            final download = activeDownloads[index];
            return _DownloadCard(download: download, isActive: true);
          },
        );
      },
    );
  }
}

/// Completed downloads tab
class _CompletedDownloadsTab extends StatelessWidget {
  const _CompletedDownloadsTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<DownloadService>(
      builder: (context, downloadService, _) {
        final completedDownloads = downloadService.completedDownloads;

        if (completedDownloads.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 64,
                  color: AppColors.textSecondary,
                ),
                SizedBox(height: 16),
                Text(
                  'No completed downloads',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          );
        }

        // Group by anime
        final Map<String, List<DownloadItem>> groupedDownloads = {};
        for (var download in completedDownloads) {
          groupedDownloads
              .putIfAbsent(download.animeId, () => [])
              .add(download);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: groupedDownloads.length,
          itemBuilder: (context, index) {
            final animeId = groupedDownloads.keys.elementAt(index);
            final episodes = groupedDownloads[animeId]!;
            episodes.sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));

            return _AnimeDownloadGroup(
              animeId: animeId,
              animeName: episodes.first.animeName,
              thumbnailUrl: episodes.first.thumbnailUrl,
              episodes: episodes,
            );
          },
        );
      },
    );
  }
}

/// Download card widget com animações modernas
class _DownloadCard extends StatefulWidget {
  final DownloadItem download;
  final bool isActive;

  const _DownloadCard({required this.download, required this.isActive});

  @override
  State<_DownloadCard> createState() => _DownloadCardState();
}

class _DownloadCardState extends State<_DownloadCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    if (widget.download.status == DownloadStatus.downloading) {
      _progressController.repeat();
    }
  }

  @override
  void didUpdateWidget(_DownloadCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.download.status == DownloadStatus.downloading) {
      if (!_progressController.isAnimating) {
        _progressController.repeat();
      }
    } else {
      _progressController.stop();
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final downloadService = context.read<DownloadService>();

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _getStatusColor(widget.download.status).withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _getStatusColor(widget.download.status).withValues(alpha: 0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      // Thumbnail com badge de status
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: widget.download.thumbnailUrl,
                              width: 75,
                              height: 110,
                              fit: BoxFit.cover,
                              memCacheWidth: 225,
                              memCacheHeight: 330,
                              filterQuality: FilterQuality.high,
                              placeholder: (context, url) => Container(
                                color: AppColors.background,
                                child: const Center(
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: AppColors.background,
                                child: const Icon(Icons.error, color: Colors.white54),
                              ),
                            ),
                          ),
                          // Status badge
                          Positioned(
                            top: 6,
                            right: 6,
                            child: _StatusBadge(status: widget.download.status),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.download.animeName,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'EP ${widget.download.episodeNumber}',
                                style: TextStyle(
                                  color: AppColors.accent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (widget.isActive) ...[
                              const SizedBox(height: 10),
                              // Status text
                              Text(
                                _getStatusText(widget.download, downloadService),
                                style: TextStyle(
                                  color: _getStatusColor(widget.download.status),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Action buttons
                      if (widget.isActive)
                        _buildActiveActions(context, widget.download, downloadService)
                      else
                        _buildCompletedActions(context, widget.download, downloadService),
                    ],
                  ),
                ),
                // Animated progress bar
                if (widget.isActive && widget.download.status == DownloadStatus.downloading)
                  _AnimatedProgressBar(progress: widget.download.progress),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.downloading:
        return AppColors.accent;
      case DownloadStatus.completed:
        return Colors.green;
      case DownloadStatus.paused:
        return Colors.orange;
      case DownloadStatus.failed:
        return Colors.red;
      case DownloadStatus.queued:
        return AppColors.textSecondary;
      case DownloadStatus.cancelled:
        return Colors.grey;
    }
  }

  Widget _buildActiveActions(
    BuildContext context,
    DownloadItem download,
    DownloadService downloadService,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (download.status == DownloadStatus.downloading)
          IconButton(
            icon: const Icon(Icons.pause, color: AppColors.accent),
            onPressed: () => downloadService.pauseDownload(download.id),
          )
        else if (download.status == DownloadStatus.paused)
          IconButton(
            icon: const Icon(Icons.play_arrow, color: AppColors.accent),
            onPressed: () => downloadService.resumeDownload(download.id),
          )
        else if (download.status == DownloadStatus.failed)
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.accent),
            onPressed: () => downloadService.retryDownload(download.id),
          ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.red),
          onPressed: () =>
              _showDeleteDialog(context, download, downloadService),
        ),
      ],
    );
  }

  Widget _buildCompletedActions(
    BuildContext context,
    DownloadItem download,
    DownloadService downloadService,
  ) {
    return IconButton(
      icon: const Icon(Icons.delete, color: Colors.red),
      onPressed: () => _showDeleteDialog(context, download, downloadService),
    );
  }

  String _getStatusText(
    DownloadItem download,
    DownloadService downloadService,
  ) {
    switch (download.status) {
      case DownloadStatus.downloading:
        final percentage = (download.progress * 100).toStringAsFixed(1);
        final downloaded = downloadService.formatBytes(
          download.bytesDownloaded,
        );
        final total = downloadService.formatBytes(download.totalBytes);
        return '$percentage% • $downloaded / $total';
      case DownloadStatus.paused:
        return 'Paused';
      case DownloadStatus.queued:
        return 'Waiting...';
      case DownloadStatus.failed:
        return 'Failed: ${download.error ?? "Unknown error"}';
      default:
        return '';
    }
  }

  void _showDeleteDialog(
    BuildContext context,
    DownloadItem download,
    DownloadService downloadService,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Delete Download',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Are you sure you want to delete this download?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              downloadService.deleteDownload(download.id);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

/// Anime download group widget (for completed downloads)
class _AnimeDownloadGroup extends StatefulWidget {
  final String animeId;
  final String animeName;
  final String thumbnailUrl;
  final List<DownloadItem> episodes;

  const _AnimeDownloadGroup({
    required this.animeId,
    required this.animeName,
    required this.thumbnailUrl,
    required this.episodes,
  });

  @override
  State<_AnimeDownloadGroup> createState() => _AnimeDownloadGroupState();
}

class _AnimeDownloadGroupState extends State<_AnimeDownloadGroup> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: widget.thumbnailUrl,
                      width: 60,
                      height: 90,
                      fit: BoxFit.cover,
                      memCacheWidth: 180,
                      memCacheHeight: 270,
                      filterQuality: FilterQuality.high,
                      placeholder: (context, url) => Container(
                        color: AppColors.background,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: AppColors.background,
                        child: const Icon(Icons.error),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.animeName,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.episodes.length} episodes',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          // Episodes list
          if (_isExpanded)
            ...widget.episodes.map(
              (episode) => _EpisodeListItem(episode: episode),
            ),
        ],
      ),
    );
  }
}

/// Episode list item
class _EpisodeListItem extends StatelessWidget {
  final DownloadItem episode;

  const _EpisodeListItem({required this.episode});

  @override
  Widget build(BuildContext context) {
    final downloadService = context.read<DownloadService>();

    return InkWell(
      onTap: () => _playEpisode(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.background, width: 1),
          ),
        ),
        child: Row(
          children: [
            // Episode number
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  episode.episodeNumber,
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Episode title
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    episode.episodeTitle,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  if (episode.totalBytes > 0)
                    Text(
                      downloadService.formatBytes(episode.totalBytes),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            // Play button
            IconButton(
              icon: const Icon(
                Icons.play_circle_filled,
                color: AppColors.accent,
                size: 32,
              ),
              onPressed: () => _playEpisode(context),
            ),
          ],
        ),
      ),
    );
  }

  void _playEpisode(BuildContext context) {
    if (episode.filePath == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _LocalVideoPlayerScreen(
          filePath: episode.filePath!,
          episodeTitle: 'Episode ${episode.episodeNumber}',
        ),
      ),
    );
  }
}

/// Local video player screen for downloaded files
class _LocalVideoPlayerScreen extends StatefulWidget {
  final String filePath;
  final String episodeTitle;

  const _LocalVideoPlayerScreen({
    required this.filePath,
    required this.episodeTitle,
  });

  @override
  State<_LocalVideoPlayerScreen> createState() =>
      _LocalVideoPlayerScreenState();
}

class _LocalVideoPlayerScreenState extends State<_LocalVideoPlayerScreen> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isInitialized = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      _videoPlayerController = VideoPlayerController.file(
        File(widget.filePath),
      );

      await _videoPlayerController.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.accent,
          handleColor: AppColors.accent,
          backgroundColor: Colors.grey,
          bufferedColor: Colors.grey.shade300,
        ),
        placeholder: Container(
          color: Colors.black,
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorBuilder: (context, errorMessage) {
          return Container(
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 60),
                  const SizedBox(height: 16),
                  Text(
                    'Error: $errorMessage',
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      );

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          widget.episodeTitle,
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: _errorMessage != null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 60),
                  const SizedBox(height: 16),
                  Text(
                    'Error: $_errorMessage',
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ],
              )
            : _isInitialized && _chewieController != null
            ? Chewie(controller: _chewieController!)
            : const CircularProgressIndicator(),
      ),
    );
  }
}

/// Badge de status animado
class _StatusBadge extends StatefulWidget {
  final DownloadStatus status;

  const _StatusBadge({required this.status});

  @override
  State<_StatusBadge> createState() => _StatusBadgeState();
}

class _StatusBadgeState extends State<_StatusBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    if (widget.status == DownloadStatus.downloading) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_StatusBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status == DownloadStatus.downloading) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (color, icon) = _getStatusInfo();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: color.withValues(
                alpha: widget.status == DownloadStatus.downloading
                    ? 0.3 + (_controller.value * 0.3)
                    : 0.3,
              ),
              blurRadius: 8,
              spreadRadius: widget.status == DownloadStatus.downloading
                  ? _controller.value * 2
                  : 0,
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 12),
      ),
    );
  }

  (Color, IconData) _getStatusInfo() {
    switch (widget.status) {
      case DownloadStatus.downloading:
        return (AppColors.accent, Icons.downloading);
      case DownloadStatus.completed:
        return (Colors.green, Icons.check);
      case DownloadStatus.paused:
        return (Colors.orange, Icons.pause);
      case DownloadStatus.failed:
        return (Colors.red, Icons.error);
      case DownloadStatus.queued:
        return (AppColors.textSecondary, Icons.schedule);
      case DownloadStatus.cancelled:
        return (Colors.grey, Icons.cancel);
    }
  }
}

/// Barra de progresso animada
class _AnimatedProgressBar extends StatefulWidget {
  final double progress;

  const _AnimatedProgressBar({required this.progress});

  @override
  State<_AnimatedProgressBar> createState() => _AnimatedProgressBarState();
}

class _AnimatedProgressBarState extends State<_AnimatedProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.background,
      ),
      child: AnimatedBuilder(
        animation: _shimmerController,
        builder: (context, child) => Stack(
          children: [
            // Progress fill
            FractionallySizedBox(
              widthFactor: widget.progress.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.accent,
                      AppColors.accent.withValues(alpha: 0.8),
                      AppColors.accent,
                    ],
                    stops: [
                      0.0,
                      _shimmerController.value,
                      1.0,
                    ],
                  ),
                ),
              ),
            ),
            // Shimmer effect
            if (widget.progress > 0 && widget.progress < 1)
              Positioned(
                left: (MediaQuery.of(context).size.width * widget.progress) - 20,
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.white.withValues(alpha: 0.4),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
