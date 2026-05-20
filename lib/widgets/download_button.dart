import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;

import '../services/download_service.dart';
import '../theme/app_colors.dart';

/// Download button widget com animações modernas
class DownloadButton extends StatefulWidget {
  final String animeId;
  final String animeName;
  final String episodeNumber;
  final String episodeTitle;
  final String videoUrl;
  final String thumbnailUrl;
  final DownloadQuality quality;

  const DownloadButton({
    super.key,
    required this.animeId,
    required this.animeName,
    required this.episodeNumber,
    required this.episodeTitle,
    required this.videoUrl,
    required this.thumbnailUrl,
    this.quality = DownloadQuality.auto,
  });

  @override
  State<DownloadButton> createState() => _DownloadButtonState();
}

class _DownloadButtonState extends State<DownloadButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.85), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 0.85, end: 1.1), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _bounceController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DownloadService>(
      builder: (context, downloadService, _) {
        final downloadId = '${widget.animeId}_${widget.episodeNumber}';
        final download = downloadService.getDownload(downloadId);

        if (download == null) {
          // Not downloaded - show animated download button
          return AnimatedBuilder(
            animation: _bounceAnimation,
            builder: (context, child) => Transform.scale(
              scale: _bounceAnimation.value,
              child: _AnimatedDownloadIcon(
                onTap: () {
                  _bounceController.forward(from: 0);
                  _startDownload(context, downloadService);
                },
              ),
            ),
          );
        }

        // Show status based on download state
        switch (download.status) {
          case DownloadStatus.downloading:
            return _AnimatedProgressIndicator(
              progress: download.progress,
              onPause: () => downloadService.pauseDownload(downloadId),
            );

          case DownloadStatus.paused:
            return _AnimatedStatusButton(
              icon: Icons.play_arrow,
              color: AppColors.accent,
              onTap: () => downloadService.resumeDownload(downloadId),
              tooltip: 'Continuar',
            );

          case DownloadStatus.queued:
            return _AnimatedQueuedIndicator();

          case DownloadStatus.completed:
            return _AnimatedStatusButton(
              icon: Icons.check_circle,
              color: Colors.green,
              onTap: () => _showDownloadOptions(context, downloadService, downloadId),
              tooltip: 'Baixado',
              showPulse: true,
            );

          case DownloadStatus.failed:
            return _AnimatedStatusButton(
              icon: Icons.error,
              color: Colors.red,
              onTap: () => downloadService.retryDownload(downloadId),
              tooltip: 'Tentar novamente',
              showShake: true,
            );

          case DownloadStatus.cancelled:
            return AnimatedBuilder(
              animation: _bounceAnimation,
              builder: (context, child) => Transform.scale(
                scale: _bounceAnimation.value,
                child: _AnimatedDownloadIcon(
                  onTap: () {
                    _bounceController.forward(from: 0);
                    _startDownload(context, downloadService);
                  },
                ),
              ),
            );
        }
      },
    );
  }

  Future<void> _startDownload(
    BuildContext context,
    DownloadService downloadService,
  ) async {
    try {
      await downloadService.addDownload(
        animeId: widget.animeId,
        animeName: widget.animeName,
        episodeNumber: widget.episodeNumber,
        episodeTitle: widget.episodeTitle,
        videoUrl: widget.videoUrl,
        thumbnailUrl: widget.thumbnailUrl,
        quality: widget.quality,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.download, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Episódio ${widget.episodeNumber} adicionado à fila'),
              ],
            ),
            backgroundColor: AppColors.accent,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(e.toString())),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _showDownloadOptions(
    BuildContext context,
    DownloadService downloadService,
    String downloadId,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Opções de Download',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.delete, color: Colors.red),
              ),
              title: const Text(
                'Excluir Download',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              subtitle: const Text(
                'Remove o arquivo baixado',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              onTap: () {
                downloadService.deleteDownload(downloadId);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// Ícone de download com animação de hover
class _AnimatedDownloadIcon extends StatefulWidget {
  final VoidCallback onTap;

  const _AnimatedDownloadIcon({required this.onTap});

  @override
  State<_AnimatedDownloadIcon> createState() => _AnimatedDownloadIconState();
}

class _AnimatedDownloadIconState extends State<_AnimatedDownloadIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _isHovered 
                ? AppColors.primary.withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: AnimatedScale(
            scale: _isHovered ? 1.1 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: Icon(
              Icons.download_rounded,
              color: _isHovered ? AppColors.primary : AppColors.textSecondary,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

/// Indicador de progresso com animação
class _AnimatedProgressIndicator extends StatefulWidget {
  final double progress;
  final VoidCallback onPause;

  const _AnimatedProgressIndicator({
    required this.progress,
    required this.onPause,
  });

  @override
  State<_AnimatedProgressIndicator> createState() => _AnimatedProgressIndicatorState();
}

class _AnimatedProgressIndicatorState extends State<_AnimatedProgressIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onPause,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background circle
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: 0.15),
              ),
            ),
            // Progress ring
            SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                value: widget.progress,
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation(AppColors.accent),
                backgroundColor: AppColors.accent.withValues(alpha: 0.2),
              ),
            ),
            // Percentage or pause icon
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                '${(widget.progress * 100).toInt()}%',
                key: ValueKey(widget.progress.toInt()),
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Indicador de fila com animação
class _AnimatedQueuedIndicator extends StatefulWidget {
  const _AnimatedQueuedIndicator();

  @override
  State<_AnimatedQueuedIndicator> createState() => _AnimatedQueuedIndicatorState();
}

class _AnimatedQueuedIndicatorState extends State<_AnimatedQueuedIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.rotate(
        angle: _controller.value * 2 * math.pi,
        child: const Icon(
          Icons.schedule,
          color: AppColors.textSecondary,
          size: 24,
        ),
      ),
    );
  }
}

/// Botão de status com animações
class _AnimatedStatusButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;
  final bool showPulse;
  final bool showShake;

  const _AnimatedStatusButton({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
    this.showPulse = false,
    this.showShake = false,
  });

  @override
  State<_AnimatedStatusButton> createState() => _AnimatedStatusButtonState();
}

class _AnimatedStatusButtonState extends State<_AnimatedStatusButton>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _shakeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    if (widget.showPulse) {
      _pulseController.repeat(reverse: true);
    }
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    if (widget.showShake) {
      _shakeController.repeat();
    }
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 5), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 5, end: -5), weight: 50),
      TweenSequenceItem(tween: Tween(begin: -5, end: 0), weight: 25),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: Listenable.merge([_pulseAnimation, _shakeAnimation]),
          builder: (context, child) => Transform.translate(
            offset: Offset(widget.showShake ? _shakeAnimation.value : 0, 0),
            child: Transform.scale(
              scale: widget.showPulse ? _pulseAnimation.value : 1.0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  widget.icon,
                  color: widget.color,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Batch download dialog - allows downloading multiple episodes
class BatchDownloadDialog extends StatefulWidget {
  final String animeId;
  final String animeName;
  final String thumbnailUrl;
  final List<Map<String, String>> episodes;

  const BatchDownloadDialog({
    super.key,
    required this.animeId,
    required this.animeName,
    required this.thumbnailUrl,
    required this.episodes,
  });

  @override
  State<BatchDownloadDialog> createState() => _BatchDownloadDialogState();
}

class _BatchDownloadDialogState extends State<BatchDownloadDialog> {
  final Set<int> _selectedEpisodes = {};
  DownloadQuality _selectedQuality = DownloadQuality.auto;
  bool _selectAll = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.background, width: 1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Batch Download',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.animeName,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // Quality selector
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    'Quality:',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SegmentedButton<DownloadQuality>(
                      segments: const [
                        ButtonSegment(
                          value: DownloadQuality.auto,
                          label: Text('Auto'),
                        ),
                        ButtonSegment(
                          value: DownloadQuality.low,
                          label: Text('480p'),
                        ),
                        ButtonSegment(
                          value: DownloadQuality.medium,
                          label: Text('720p'),
                        ),
                        ButtonSegment(
                          value: DownloadQuality.high,
                          label: Text('1080p'),
                        ),
                      ],
                      selected: {_selectedQuality},
                      onSelectionChanged: (Set<DownloadQuality> selected) {
                        setState(() => _selectedQuality = selected.first);
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Select all checkbox
            CheckboxListTile(
              title: const Text(
                'Select All',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              value: _selectAll,
              onChanged: (value) {
                setState(() {
                  _selectAll = value ?? false;
                  if (_selectAll) {
                    _selectedEpisodes.clear();
                    _selectedEpisodes.addAll(
                      List.generate(widget.episodes.length, (i) => i),
                    );
                  } else {
                    _selectedEpisodes.clear();
                  }
                });
              },
            ),

            const Divider(color: AppColors.background),

            // Episodes list
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.episodes.length,
                itemBuilder: (context, index) {
                  final episode = widget.episodes[index];
                  final isSelected = _selectedEpisodes.contains(index);

                  return CheckboxListTile(
                    title: Text(
                      'Episode ${episode['number']}',
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                    subtitle: episode['title'] != null
                        ? Text(
                            episode['title']!,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        : null,
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value ?? false) {
                          _selectedEpisodes.add(index);
                        } else {
                          _selectedEpisodes.remove(index);
                        }
                        _selectAll =
                            _selectedEpisodes.length == widget.episodes.length;
                      });
                    },
                  );
                },
              ),
            ),

            // Action buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.background, width: 1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _selectedEpisodes.isEmpty
                        ? null
                        : () => _startBatchDownload(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                    ),
                    child: Text(
                      'Download ${_selectedEpisodes.length} Episodes',
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

  Future<void> _startBatchDownload(BuildContext context) async {
    final downloadService = context.read<DownloadService>();
    final selectedEpisodesList = _selectedEpisodes
        .map((index) => widget.episodes[index])
        .toList();

    try {
      final downloadIds = await downloadService.addBatchDownloads(
        animeId: widget.animeId,
        animeName: widget.animeName,
        episodes: selectedEpisodesList,
        thumbnailUrl: widget.thumbnailUrl,
        quality: _selectedQuality,
      );

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added ${downloadIds.length} episodes to downloads'),
            backgroundColor: AppColors.accent,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}
