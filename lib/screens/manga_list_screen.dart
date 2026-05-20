import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/gomang_service.dart';
import 'manga_detail_screen.dart';

class MangaListScreen extends StatefulWidget {
  const MangaListScreen({super.key});

  @override
  State<MangaListScreen> createState() => _MangaListScreenState();
}

class _MangaListScreenState extends State<MangaListScreen> {
  final GomangService _service = GomangService();
  final ScrollController _scrollController = ScrollController();
  
  bool _loading = true;
  bool _loadingMore = false;
  List<dynamic> _mangas = [];
  int _currentPage = 1;
  bool _hasMore = true;
  final Set<String> _seenIds = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadPopular();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadPopular() async {
    if (mounted) setState(() => _loading = true);
    try {
      // Load first 5 pages for more variety
      final list = await _service.getPopular(pages: 5);
      if (mounted) {
        setState(() {
          _mangas = list;
          _seenIds.clear();
          for (final m in list) {
            _seenIds.add(m['id'] ?? m['url'] ?? '');
          }
          _currentPage = 5;
          _hasMore = list.length >= 50;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar mangas: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao carregar mangas')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;

    setState(() => _loadingMore = true);
    final nextPage = _currentPage + 1;
    try {
      final newMangas = await _service.getMangas(page: nextPage);
      // Só avança o cursor depois do sucesso. Em falha, próxima tentativa
      // re-tenta a mesma página em vez de pular para a seguinte.
      _currentPage = nextPage;

      if (mounted) {
        final uniqueMangas = <dynamic>[];
        for (final m in newMangas) {
          final id = m['id'] ?? m['url'] ?? '';
          if (!_seenIds.contains(id)) {
            _seenIds.add(id);
            uniqueMangas.add(m);
          }
        }

        setState(() {
          _mangas.addAll(uniqueMangas);
          _hasMore = newMangas.isNotEmpty;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar mais mangas: $e');
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _refresh() async {
    _currentPage = 1;
    _hasMore = true;
    _seenIds.clear();
    await _loadPopular();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mangás (${_mangas.length})'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: _mangas.length + (_loadingMore ? 1 : 0),
                itemBuilder: (context, index) {
                  // Loading indicator at bottom
                  if (index >= _mangas.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  
                  final m = _mangas[index] as Map<String, dynamic>;
                  return Card(
                    color: Theme.of(context).colorScheme.surface,
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: CachedNetworkImage(
                          imageUrl: m['image'] ?? '',
                          width: 48,
                          height: 64,
                          fit: BoxFit.cover,
                          memCacheWidth: 144,
                          memCacheHeight: 192,
                          filterQuality: FilterQuality.high,
                          errorWidget: (c, u, e) => Container(
                            width: 48,
                            height: 64,
                            color: Colors.grey[800],
                            child: const Icon(Icons.broken_image, size: 24),
                          ),
                        ),
                      ),
                      title: Text(
                        m['title'] ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        m['genres']?.take(3).join(', ') ?? m['source'] ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 12,
                        ),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MangaDetailScreen(manga: m),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
    );
  }
}
