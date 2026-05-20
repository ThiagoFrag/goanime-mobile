import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/gomang_service.dart';

class MangaReaderScreen extends StatefulWidget {
  final String chapterUrl;
  final String chapterTitle;

  const MangaReaderScreen({
    super.key,
    required this.chapterUrl,
    required this.chapterTitle,
  });

  @override
  State<MangaReaderScreen> createState() => _MangaReaderScreenState();
}

class _MangaReaderScreenState extends State<MangaReaderScreen> {
  final GomangService _gomang = GomangService();

  /// Apenas usado no modo página-a-página. No modo vertical cada item tem o seu.
  final TransformationController _pageTransformController =
      TransformationController();
  final PageController _pageController = PageController();
  final ScrollController _verticalScrollController = ScrollController();

  List<String> _pages = [];
  bool _isLoading = true;
  String? _error;
  int _currentPage = 0;
  bool _isVerticalMode = true;

  static const String _progressPrefix = 'manga_reader_progress_';

  @override
  void initState() {
    super.initState();
    _loadPages();
  }

  @override
  void dispose() {
    _persistProgress();
    _pageTransformController.dispose();
    _pageController.dispose();
    _verticalScrollController.dispose();
    _pages.clear();
    super.dispose();
  }

  String get _progressKey => '$_progressPrefix${widget.chapterUrl}';

  Future<int> _readPersistedPage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_progressKey) ?? 0;
  }

  Future<void> _persistProgress() async {
    if (_pages.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_progressKey, _currentPage);
  }

  Future<void> _loadPages() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final raw = await _gomang.getChapterPages(widget.chapterUrl);
      final normalized = raw
          .map((p) {
            if (p is String) return p;
            if (p is Map) {
              return (p['image'] ?? p['url'] ?? '').toString();
            }
            return '';
          })
          .where((url) => url.isNotEmpty)
          .toList();

      final lastPage = await _readPersistedPage();
      if (!mounted) return;

      setState(() {
        _pages = normalized;
        _currentPage = lastPage.clamp(0, normalized.isEmpty ? 0 : normalized.length - 1);
        _isLoading = false;
      });

      _restoreScrollPosition();
      _prefetchAround(_currentPage);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _restoreScrollPosition() {
    if (_currentPage <= 0 || _pages.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_isVerticalMode) {
        _verticalScrollController.jumpTo(
          _currentPage * MediaQuery.of(context).size.height * 0.8,
        );
      } else if (_pageController.hasClients) {
        _pageController.jumpToPage(_currentPage);
      }
    });
  }

  /// Pré-aquece o cache de imagens vizinhas para evitar stall ao trocar de página.
  void _prefetchAround(int index) {
    if (!mounted || _pages.isEmpty) return;
    for (final offset in const [1, 2, -1]) {
      final target = index + offset;
      if (target < 0 || target >= _pages.length) continue;
      precacheImage(
        CachedNetworkImageProvider(_pages[target]),
        context,
      );
    }
  }

  void _resetZoom() {
    _pageTransformController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          _pages.isEmpty
              ? widget.chapterTitle
              : '${widget.chapterTitle} (${_currentPage + 1}/${_pages.length})',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.black.withValues(alpha: 0.8),
        actions: [
          IconButton(
            icon: Icon(_isVerticalMode ? Icons.view_carousel : Icons.view_day),
            tooltip: _isVerticalMode ? 'Modo página' : 'Modo scroll',
            onPressed: () {
              setState(() => _isVerticalMode = !_isVerticalMode);
              _restoreScrollPosition();
            },
          ),
          if (!_isVerticalMode)
            IconButton(
              icon: const Icon(Icons.zoom_out_map),
              tooltip: 'Resetar zoom',
              onPressed: _resetZoom,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(
                    'Erro ao carregar páginas',
                    style: TextStyle(color: Colors.grey.shade400),
                  ),
                )
              : _pages.isEmpty
                  ? const Center(
                      child: Text(
                        'Nenhuma página encontrada',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : _isVerticalMode
                      ? _buildVerticalReader()
                      : _buildPageReader(),
    );
  }

  /// Modo de leitura vertical (scroll). Cada página tem seu próprio
  /// InteractiveViewer para evitar conflito de gesto com o ListView.
  Widget _buildVerticalReader() {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollEndNotification && _pages.isNotEmpty) {
          final viewport = MediaQuery.of(context).size.height;
          final visibleIndex =
              (_verticalScrollController.offset / viewport).round();
          final clamped = visibleIndex.clamp(0, _pages.length - 1);
          if (clamped != _currentPage) {
            setState(() => _currentPage = clamped);
            _prefetchAround(clamped);
            _persistProgress();
          }
        }
        return false;
      },
      child: ListView.builder(
        controller: _verticalScrollController,
        itemCount: _pages.length,
        itemBuilder: (context, index) => _PageImage(
          url: _pages[index],
          isVertical: true,
        ),
      ),
    );
  }

  /// Modo página-por-página com zoom individual.
  Widget _buildPageReader() {
    return PageView.builder(
      controller: _pageController,
      itemCount: _pages.length,
      onPageChanged: (index) {
        setState(() => _currentPage = index);
        _resetZoom();
        _prefetchAround(index);
        _persistProgress();
      },
      itemBuilder: (context, index) => _PageImage(
        url: _pages[index],
        isVertical: false,
        transformController: _pageTransformController,
      ),
    );
  }
}

class _PageImage extends StatelessWidget {
  final String url;
  final bool isVertical;
  final TransformationController? transformController;

  const _PageImage({
    required this.url,
    required this.isVertical,
    this.transformController,
  });

  @override
  Widget build(BuildContext context) {
    final image = CachedNetworkImage(
      imageUrl: url,
      fit: isVertical ? BoxFit.fitWidth : BoxFit.contain,
      memCacheWidth: isVertical ? 1200 : 1600,
      maxWidthDiskCache: isVertical ? 1600 : 2000,
      filterQuality: FilterQuality.high,
      placeholder: (c, u) => Container(
        height: 400,
        color: Colors.grey[900],
        child: const Center(child: CircularProgressIndicator()),
      ),
      errorWidget: (c, u, e) => Container(
        height: 200,
        color: Colors.grey[900],
        child: const Center(
          child: Icon(Icons.error, color: Colors.white54),
        ),
      ),
    );

    if (isVertical) {
      // Per-item InteractiveViewer evita conflito com o ListView pan global.
      return InteractiveViewer(
        minScale: 1.0,
        maxScale: 4.0,
        panEnabled: false,
        scaleEnabled: true,
        child: image,
      );
    }

    return InteractiveViewer(
      transformationController: transformController,
      minScale: 1.0,
      maxScale: 5.0,
      panEnabled: true,
      scaleEnabled: true,
      child: Center(child: image),
    );
  }
}
