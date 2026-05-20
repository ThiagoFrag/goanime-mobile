import 'anilist_models.dart';

class Episode {
  final String number;
  final String url;
  final String? thumbnail;
  final String? title;
  final String? description;

  Episode({
    required this.number,
    required this.url,
    this.thumbnail,
    this.title,
    this.description,
  });

  @override
  String toString() => number;

  String? getImageUrl() => thumbnail;
}

class StreamEpisodeListItem {
  final String episodeNumber;
  final String? thumbnailUrl;
  final String? title;
  final String? description;
  final String? url;
  final Duration? duration;
  final DateTime? airDate;

  StreamEpisodeListItem({
    required this.episodeNumber,
    this.thumbnailUrl,
    this.title,
    this.description,
    this.url,
    this.duration,
    this.airDate,
  });

  String? getImageUrl() => thumbnailUrl;

  Episode toEpisode() {
    return Episode(
      number: episodeNumber,
      url: url ?? '',
      thumbnail: thumbnailUrl,
      title: title,
      description: description,
    );
  }

  factory StreamEpisodeListItem.fromJson(Map<String, dynamic> json) {
    return StreamEpisodeListItem(
      episodeNumber:
          json['episodeNumber']?.toString() ?? json['number']?.toString() ?? '',
      thumbnailUrl: json['thumbnail'] ?? json['thumbnailUrl'] ?? json['image'],
      title: json['title'] ?? json['name'],
      description: json['description'] ?? json['synopsis'],
      url: json['url'],
      duration: json['duration'] != null
          ? Duration(
              seconds: json['duration'] is int
                  ? json['duration']
                  : int.tryParse(json['duration'].toString()) ?? 0,
            )
          : null,
      airDate: json['airDate'] != null
          ? DateTime.tryParse(json['airDate'].toString())
          : null,
    );
  }
}

enum AnimeSource { animeFire, allAnime, animeDrive }

class Anime {
  final String name;
  final String url;
  final AnimeSource source;
  final String? allAnimeId;
  final String? animeDriveId;
  final String? fallbackImageUrl;
  MediaDetails? aniListData;
  bool isLoadingAniList = false;

  Anime({
    required this.name,
    required this.url,
    this.source = AnimeSource.animeFire,
    this.allAnimeId,
    this.animeDriveId,
    this.aniListData,
    this.fallbackImageUrl,
  });

  @override
  String toString() => name;

  String get imageUrl => aniListData?.coverImage.best ?? fallbackImageUrl ?? '';
  String get bannerUrl => aniListData?.bannerImage ?? '';
  String get description => aniListData?.description ?? '';
  int? get malId => aniListData?.idMal;
  int? get anilistId => aniListData?.id;
  List<String> get genres => aniListData?.genres ?? [];
  String? get status => aniListData?.status;
  int? get episodeCount => aniListData?.episodes;
  double? get averageScore => aniListData?.averageScore;

  String get sourceName {
    switch (source) {
      case AnimeSource.animeFire:
        return 'AnimeFire';
      case AnimeSource.allAnime:
        return 'AllAnime';
      case AnimeSource.animeDrive:
        return 'AnimeDrive';
    }
  }
}

class VideoData {
  final String src;
  final String label;

  VideoData({required this.src, required this.label});

  factory VideoData.fromJson(Map<String, dynamic> json) {
    return VideoData(src: json['src'] ?? '', label: json['label'] ?? '');
  }
}

class VideoResponse {
  final List<VideoData> data;
  final Map<String, dynamic> resposta;

  VideoResponse({required this.data, required this.resposta});

  factory VideoResponse.fromJson(Map<String, dynamic> json) {
    final dataList = json['data'] as List? ?? [];
    final videoDataList = dataList
        .whereType<Map<String, dynamic>>()
        .map(VideoData.fromJson)
        .toList();
    return VideoResponse(
      data: videoDataList,
      resposta: (json['resposta'] as Map<String, dynamic>?) ?? const {},
    );
  }
}

class VideoStreamResult {
  final String url;
  final Map<String, String> headers;
  final bool isGoogleVideo;

  const VideoStreamResult({
    required this.url,
    Map<String, String>? headers,
    this.isGoogleVideo = false,
  }) : headers = headers ?? const {};

  bool get hasHeaders => headers.isNotEmpty;
}
