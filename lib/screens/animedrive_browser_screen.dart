import 'package:flutter/material.dart';
import '../services/animedrive_service.dart';

/// Tela de navegação do AnimeDrive
/// Permite explorar todos os 875+ animes por página, A-Z, gênero
class AnimeDriveBrowser extends StatefulWidget {
  final Function(AnimeDriveShow)? onAnimeSelected;

  const AnimeDriveBrowser({super.key, this.onAnimeSelected});

  @override
  State<AnimeDriveBrowser> createState() => _AnimeDriveBrowserState();
}

class _AnimeDriveBrowserState extends State<AnimeDriveBrowser>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // State for pagination
  int _currentPage = 1;
  bool _isLoading = false;
  bool _hasMore = true;
  List<AnimeDriveShow> _animes = [];

  // State for A-Z navigation
  String _selectedLetter = '';

  // State for genres
  List<AnimeDriveGenre> _genres = [];
  AnimeDriveGenre? _selectedGenre;

  // State for search
  final TextEditingController _searchController = TextEditingController();
  List<AnimeDriveShow> _searchResults = [];
  bool _isSearching = false;

  // Filter options
  bool _showDubbedOnly = false;
  String _sortBy = 'recent'; // recent, title, rating

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    try {
      // Load first page and genres in parallel
      final results = await Future.wait([
        AnimeDriveService.getAnimesByPage(1),
        AnimeDriveService.getGenres(),
      ]);

      setState(() {
        _animes = results[0] as List<AnimeDriveShow>;
        _genres = results[1] as List<AnimeDriveGenre>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('[AnimeDriveBrowser] Error loading data: $e');
    }
  }

  Future<void> _loadMoreAnimes() async {
    if (_isLoading || !_hasMore) return;

    setState(() => _isLoading = true);

    try {
      final nextPage = _currentPage + 1;
      List<AnimeDriveShow> newAnimes;

      if (_selectedLetter.isNotEmpty) {
        newAnimes = await AnimeDriveService.getAnimesByLetter(
          _selectedLetter,
          page: nextPage,
        );
      } else if (_selectedGenre != null) {
        newAnimes = await AnimeDriveService.getAnimesByGenre(
          _selectedGenre!.url,
          page: nextPage,
        );
      } else {
        newAnimes = await AnimeDriveService.getAnimesByPage(nextPage);
      }

      setState(() {
        _animes.addAll(newAnimes);
        _currentPage = nextPage;
        _hasMore = newAnimes.isNotEmpty;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadByLetter(String letter) async {
    setState(() {
      _isLoading = true;
      _selectedLetter = letter;
      _selectedGenre = null;
      _animes = [];
      _currentPage = 1;
      _hasMore = true;
    });

    try {
      final animes = await AnimeDriveService.getAnimesByLetter(letter);
      setState(() {
        _animes = animes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadByGenre(AnimeDriveGenre genre) async {
    setState(() {
      _isLoading = true;
      _selectedGenre = genre;
      _selectedLetter = '';
      _animes = [];
      _currentPage = 1;
      _hasMore = true;
    });

    try {
      final animes = await AnimeDriveService.getAnimesByGenre(genre.url);
      setState(() {
        _animes = animes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final results = await AnimeDriveService.searchAnime(query);
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _animes = [];
      _currentPage = 1;
      _hasMore = true;
      _selectedLetter = '';
      _selectedGenre = null;
    });
    await _loadInitialData();
  }

  List<AnimeDriveShow> get _filteredAnimes {
    var animes = _animes;

    if (_showDubbedOnly) {
      animes = animes.where((a) => a.isDubbed).toList();
    }

    switch (_sortBy) {
      case 'title':
        animes.sort((a, b) => a.title.compareTo(b.title));
        break;
      case 'rating':
        animes.sort((a, b) {
          final ratingA = double.tryParse(a.rating ?? '0') ?? 0;
          final ratingB = double.tryParse(b.rating ?? '0') ?? 0;
          return ratingB.compareTo(ratingA);
        });
        break;
    }

    return animes;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAnimesTab(),
                _buildAZTab(),
                _buildGenresTab(),
                _buildFilmsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.grey[900],
      elevation: 0,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.pinkAccent, Colors.purple],
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'AnimeDrive',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${AnimeDriveService.totalPages * 24}+ animes',
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
        ],
      ),
      actions: [
        // Filter button
        IconButton(
          icon: const Icon(Icons.filter_list),
          onPressed: _showFilterSheet,
        ),
        // Search button
        IconButton(icon: const Icon(Icons.search), onPressed: _showSearchSheet),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.grey[900],
      child: TabBar(
        controller: _tabController,
        indicatorColor: Colors.pinkAccent,
        labelColor: Colors.pinkAccent,
        unselectedLabelColor: Colors.grey,
        tabs: const [
          Tab(text: 'Recentes', icon: Icon(Icons.new_releases, size: 18)),
          Tab(text: 'A-Z', icon: Icon(Icons.sort_by_alpha, size: 18)),
          Tab(text: 'Gêneros', icon: Icon(Icons.category, size: 18)),
          Tab(text: 'Filmes', icon: Icon(Icons.movie, size: 18)),
        ],
      ),
    );
  }

  Widget _buildAnimesTab() {
    return RefreshIndicator(
      onRefresh: _refresh,
      color: Colors.pinkAccent,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollEndNotification) {
            if (notification.metrics.pixels >=
                notification.metrics.maxScrollExtent - 200) {
              _loadMoreAnimes();
            }
          }
          return false;
        },
        child: _filteredAnimes.isEmpty && _isLoading
            ? _buildLoadingGrid()
            : _buildAnimeGrid(_filteredAnimes),
      ),
    );
  }

  Widget _buildAZTab() {
    return Column(
      children: [
        // Alphabet navigation
        Container(
          height: 50,
          color: Colors.grey[850],
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: AnimeDriveService.alphabetLetters.length,
            itemBuilder: (context, index) {
              final letter = AnimeDriveService.alphabetLetters[index];
              final isSelected = _selectedLetter == letter;

              return GestureDetector(
                onTap: () => _loadByLetter(letter),
                child: Container(
                  width: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.pinkAccent : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  margin: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 8,
                  ),
                  child: Text(
                    letter,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[400],
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Anime grid
        Expanded(
          child: _isLoading && _animes.isEmpty
              ? _buildLoadingGrid()
              : _buildAnimeGrid(_filteredAnimes),
        ),
      ],
    );
  }

  Widget _buildGenresTab() {
    return Column(
      children: [
        // Genres chips
        if (_genres.isNotEmpty)
          Container(
            height: 50,
            color: Colors.grey[850],
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: _genres.length,
              itemBuilder: (context, index) {
                final genre = _genres[index];
                final isSelected = _selectedGenre?.id == genre.id;

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  child: FilterChip(
                    label: Text(genre.name),
                    selected: isSelected,
                    onSelected: (_) => _loadByGenre(genre),
                    selectedColor: Colors.pinkAccent,
                    backgroundColor: Colors.grey[800],
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[400],
                    ),
                  ),
                );
              },
            ),
          ),

        // Anime grid
        Expanded(
          child: _isLoading && _animes.isEmpty
              ? _buildLoadingGrid()
              : _buildAnimeGrid(_filteredAnimes),
        ),
      ],
    );
  }

  Widget _buildFilmsTab() {
    return FutureBuilder<List<AnimeDriveShow>>(
      future: AnimeDriveService.getFilms(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingGrid();
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return const Center(
            child: Text(
              'Erro ao carregar filmes',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return _buildAnimeGrid(snapshot.data!);
      },
    );
  }

  Widget _buildAnimeGrid(List<AnimeDriveShow> animes) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.6,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: animes.length + (_hasMore && _isLoading ? 3 : 0),
      itemBuilder: (context, index) {
        if (index >= animes.length) {
          return _buildLoadingCard();
        }

        final anime = animes[index];
        return _buildAnimeCard(anime);
      },
    );
  }

  Widget _buildAnimeCard(AnimeDriveShow anime) {
    return GestureDetector(
      onTap: () {
        if (widget.onAnimeSelected != null) {
          widget.onAnimeSelected!(anime);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey[850],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Poster
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (anime.thumbnail != null && anime.thumbnail!.isNotEmpty)
                    Image.network(
                      anime.thumbnail!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey[800],
                        child: const Icon(Icons.image, color: Colors.grey),
                      ),
                    )
                  else
                    Container(
                      color: Colors.grey[800],
                      child: const Icon(Icons.movie, color: Colors.grey),
                    ),

                  // Rating badge
                  if (anime.rating != null && anime.rating!.isNotEmpty)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 12,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              anime.rating!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Dubbed badge
                  if (anime.isDubbed)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'DUB',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Title
            Container(
              padding: const EdgeInsets.all(6),
              child: Text(
                anime.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.6,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: 12,
      itemBuilder: (_, __) => _buildLoadingCard(),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[850],
      ),
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.pinkAccent,
        ),
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filtros',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Dubbed only switch
            SwitchListTile(
              title: const Text(
                'Apenas Dublado',
                style: TextStyle(color: Colors.white),
              ),
              value: _showDubbedOnly,
              activeColor: Colors.pinkAccent,
              onChanged: (value) {
                setState(() => _showDubbedOnly = value);
                Navigator.pop(context);
              },
            ),

            const Divider(color: Colors.grey),

            // Sort options
            const Text(
              'Ordenar por',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 8),

            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Recentes'),
                  selected: _sortBy == 'recent',
                  onSelected: (_) {
                    setState(() => _sortBy = 'recent');
                    Navigator.pop(context);
                  },
                ),
                ChoiceChip(
                  label: const Text('Título'),
                  selected: _sortBy == 'title',
                  onSelected: (_) {
                    setState(() => _sortBy = 'title');
                    Navigator.pop(context);
                  },
                ),
                ChoiceChip(
                  label: const Text('Avaliação'),
                  selected: _sortBy == 'rating',
                  onSelected: (_) {
                    setState(() => _sortBy = 'rating');
                    Navigator.pop(context);
                  },
                ),
              ],
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showSearchSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => _SearchSheet(
          controller: scrollController,
          onAnimeSelected: (anime) {
            Navigator.pop(context);
            if (widget.onAnimeSelected != null) {
              widget.onAnimeSelected!(anime);
            }
          },
        ),
      ),
    );
  }
}

/// Sheet de busca
class _SearchSheet extends StatefulWidget {
  final ScrollController controller;
  final Function(AnimeDriveShow) onAnimeSelected;

  const _SearchSheet({required this.controller, required this.onAnimeSelected});

  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<AnimeDriveShow> _results = [];
  bool _isLoading = false;

  Future<void> _search(String query) async {
    if (query.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final results = await AnimeDriveService.searchAnime(query);
      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Buscar anime...',
              hintStyle: TextStyle(color: Colors.grey[500]),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _results = []);
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey[800],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: _search,
            onChanged: (value) {
              if (value.length >= 3) {
                _search(value);
              }
            },
          ),
        ),

        // Results
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.pinkAccent),
                )
              : _results.isEmpty
              ? Center(
                  child: Text(
                    _searchController.text.isEmpty
                        ? 'Digite para buscar...'
                        : 'Nenhum resultado',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                )
              : ListView.builder(
                  controller: widget.controller,
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final anime = _results[index];
                    return ListTile(
                      leading: anime.thumbnail != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.network(
                                anime.thumbnail!,
                                width: 50,
                                height: 70,
                                fit: BoxFit.cover,
                              ),
                            )
                          : null,
                      title: Text(
                        anime.title,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Row(
                        children: [
                          if (anime.rating != null)
                            Text(
                              '⭐ ${anime.rating}',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                          if (anime.isDubbed)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'DUB',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                        ],
                      ),
                      onTap: () => widget.onAnimeSelected(anime),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
