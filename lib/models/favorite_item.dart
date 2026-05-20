/// Modelo unificado para favoritos (anime ou manga)
class FavoriteItem {
  final int? id;
  final String itemId; // ID único do item
  final String title;
  final String coverImage;
  final String url; // URL para acessar detalhes
  final FavoriteType type; // anime ou manga
  final String? source; // fonte do manga (mangalivre.blog, etc)
  final List<String>? genres;
  final DateTime addedAt;
  final DateTime? lastReadAt; // Último episódio/capítulo lido
  final String? lastRead; // Nome do último episódio/capítulo lido
  final double? progress; // Progresso (0-100)

  FavoriteItem({
    this.id,
    required this.itemId,
    required this.title,
    required this.coverImage,
    required this.url,
    required this.type,
    this.source,
    this.genres,
    required this.addedAt,
    this.lastReadAt,
    this.lastRead,
    this.progress,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'itemId': itemId,
      'title': title,
      'coverImage': coverImage,
      'url': url,
      'type': type.name,
      'source': source,
      'genres': genres?.join(','),
      'addedAt': addedAt.toIso8601String(),
      'lastReadAt': lastReadAt?.toIso8601String(),
      'lastRead': lastRead,
      'progress': progress,
    };
  }

  factory FavoriteItem.fromMap(Map<String, dynamic> map) {
    return FavoriteItem(
      id: map['id'] as int?,
      itemId: map['itemId'] as String,
      title: map['title'] as String,
      coverImage: map['coverImage'] as String,
      url: map['url'] as String,
      type: FavoriteType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => FavoriteType.anime,
      ),
      source: map['source'] as String?,
      genres: (map['genres'] as String?)
          ?.split(',')
          .where((g) => g.isNotEmpty)
          .toList(),
      addedAt: DateTime.parse(map['addedAt'] as String),
      lastReadAt: map['lastReadAt'] != null
          ? DateTime.parse(map['lastReadAt'] as String)
          : null,
      lastRead: map['lastRead'] as String?,
      progress: map['progress'] as double?,
    );
  }

  /// Criar a partir de um manga (Map)
  factory FavoriteItem.fromManga(Map<String, dynamic> manga) {
    final id = manga['id']?.toString() ?? manga['url']?.toString() ?? '';
    return FavoriteItem(
      itemId: id,
      title: manga['title'] ?? 'Manga',
      coverImage: manga['image'] ?? '',
      url: manga['url'] ?? '',
      type: FavoriteType.manga,
      source: manga['source'],
      genres: (manga['genres'] as List?)?.cast<String>(),
      addedAt: DateTime.now(),
    );
  }

  /// Criar a partir de um anime JikanAnime
  factory FavoriteItem.fromAnime({
    required String animeId,
    required String title,
    required String coverImage,
    required String url,
  }) {
    return FavoriteItem(
      itemId: animeId,
      title: title,
      coverImage: coverImage,
      url: url,
      type: FavoriteType.anime,
      addedAt: DateTime.now(),
    );
  }

  FavoriteItem copyWith({
    int? id,
    String? itemId,
    String? title,
    String? coverImage,
    String? url,
    FavoriteType? type,
    String? source,
    List<String>? genres,
    DateTime? addedAt,
    DateTime? lastReadAt,
    String? lastRead,
    double? progress,
  }) {
    return FavoriteItem(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      title: title ?? this.title,
      coverImage: coverImage ?? this.coverImage,
      url: url ?? this.url,
      type: type ?? this.type,
      source: source ?? this.source,
      genres: genres ?? this.genres,
      addedAt: addedAt ?? this.addedAt,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      lastRead: lastRead ?? this.lastRead,
      progress: progress ?? this.progress,
    );
  }

  /// Converter para JSON para sincronização
  Map<String, dynamic> toJson() {
    return {
      'itemId': itemId,
      'title': title,
      'coverImage': coverImage,
      'url': url,
      'type': type.name,
      'source': source,
      'genres': genres,
      'addedAt': addedAt.toIso8601String(),
      'lastReadAt': lastReadAt?.toIso8601String(),
      'lastRead': lastRead,
      'progress': progress,
    };
  }

  factory FavoriteItem.fromJson(Map<String, dynamic> json) {
    return FavoriteItem(
      itemId: json['itemId'] as String,
      title: json['title'] as String,
      coverImage: json['coverImage'] as String,
      url: json['url'] as String,
      type: FavoriteType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => FavoriteType.anime,
      ),
      source: json['source'] as String?,
      genres: (json['genres'] as List?)?.cast<String>(),
      addedAt: DateTime.parse(json['addedAt'] as String),
      lastReadAt: json['lastReadAt'] != null
          ? DateTime.parse(json['lastReadAt'] as String)
          : null,
      lastRead: json['lastRead'] as String?,
      progress: (json['progress'] as num?)?.toDouble(),
    );
  }
}

enum FavoriteType { anime, manga }
