/// Models for the manga scraper

class Manga {
  final String id;
  final String title;
  final String image;
  final String url;
  final String? latestChapter;
  final List<String> genres;
  final String? description;
  final String? status;
  final double? rating;
  final int? views;
  final String? author;
  final String source;

  const Manga({
    required this.id,
    required this.title,
    required this.image,
    required this.url,
    this.latestChapter,
    this.genres = const [],
    this.description,
    this.status,
    this.rating,
    this.views,
    this.author,
    required this.source,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'image': image,
        'url': url,
        'latestChapter': latestChapter,
        'genres': genres,
        'description': description,
        'status': status,
        'rating': rating,
        'views': views,
        'author': author,
        'source': source,
      };

  factory Manga.fromJson(Map<String, dynamic> json) => Manga(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        image: json['image'] ?? '',
        url: json['url'] ?? '',
        latestChapter: json['latestChapter'],
        genres: (json['genres'] as List?)?.cast<String>() ?? [],
        description: json['description'],
        status: json['status'],
        rating: (json['rating'] as num?)?.toDouble(),
        views: json['views'] as int?,
        author: json['author'],
        source: json['source'] ?? '',
      );
}

class Chapter {
  final String number;
  final double numberFloat;
  final String title;
  final String url;
  final String? date;
  final String mangaId;
  final String? mangaName;

  const Chapter({
    required this.number,
    required this.numberFloat,
    required this.title,
    required this.url,
    this.date,
    required this.mangaId,
    this.mangaName,
  });

  Map<String, dynamic> toJson() => {
        'number': number,
        'numberFloat': numberFloat,
        'title': title,
        'url': url,
        'date': date,
        'mangaId': mangaId,
        'mangaName': mangaName,
      };

  factory Chapter.fromJson(Map<String, dynamic> json) => Chapter(
        number: json['number']?.toString() ?? '',
        numberFloat: (json['numberFloat'] as num?)?.toDouble() ?? 0.0,
        title: json['title'] ?? '',
        url: json['url'] ?? '',
        date: json['date'],
        mangaId: json['mangaId'] ?? '',
        mangaName: json['mangaName'],
      );
}

class MangaPage {
  final int number;
  final String url;

  const MangaPage({
    required this.number,
    required this.url,
  });

  Map<String, dynamic> toJson() => {
        'number': number,
        'url': url,
      };

  factory MangaPage.fromJson(Map<String, dynamic> json) => MangaPage(
        number: json['number'] ?? 0,
        url: json['url'] ?? '',
      );
}

class SourceInfo {
  final String name;
  final String displayName;
  final String baseUrl;
  final String language;
  final bool nsfw;

  const SourceInfo({
    required this.name,
    required this.displayName,
    required this.baseUrl,
    this.language = 'pt-BR',
    this.nsfw = false,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'displayName': displayName,
        'baseUrl': baseUrl,
        'language': language,
        'nsfw': nsfw,
      };
}

class SearchResult {
  final List<Manga> mangas;
  final String source;
  final String? error;

  const SearchResult({
    required this.mangas,
    required this.source,
    this.error,
  });
}
