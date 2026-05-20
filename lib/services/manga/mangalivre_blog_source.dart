import 'package:html/dom.dart';
import 'base_source.dart';
import 'models.dart';

/// MangaLivre.blog source implementation
class MangaLivreBlogSource extends BaseMangaSource {
  @override
  String get name => 'mangalivre.blog';

  @override
  String get displayName => 'MangaLivre.blog';

  @override
  String get baseUrl => 'https://mangalivre.blog';

  MangaLivreBlogSource({super.client});

  @override
  Future<List<Manga>> getAllMangas(int page) async {
    var pageUrl = '$baseUrl/manga/';
    if (page > 1) {
      pageUrl = '$baseUrl/manga/page/$page/';
    }

    final doc = await fetchDocument(pageUrl);
    final mangas = _extractMangasFromListPage(doc);

    return mangas.map((m) => m.copyWith(source: name)).toList();
  }

  @override
  Future<List<Manga>> getPopularMangas() async {
    // Load multiple pages for more variety (3 pages = 30 mangas)
    return getPopularMangasWithPages(3);
  }

  /// Get popular mangas with specified number of pages
  Future<List<Manga>> getPopularMangasWithPages(int pages) async {
    final allMangas = <Manga>[];
    final seenIds = <String>{};

    for (int page = 1; page <= pages; page++) {
      try {
        final pageUrl = page == 1
            ? '$baseUrl/manga/?m_orderby=views'
            : '$baseUrl/manga/page/$page/?m_orderby=views';
        
        final doc = await fetchDocument(pageUrl);
        final mangas = _extractMangasFromListPage(doc);

        for (final manga in mangas) {
          if (!seenIds.contains(manga.id)) {
            seenIds.add(manga.id);
            allMangas.add(manga.copyWith(source: name));
          }
        }
      } catch (e) {
        // Stop if page fails
        break;
      }
    }

    return allMangas;
  }

  @override
  Future<List<Manga>> getLatestUpdates() async {
    // Load multiple pages for latest updates
    return getLatestUpdatesWithPages(3);
  }

  /// Get latest updates with specified number of pages
  Future<List<Manga>> getLatestUpdatesWithPages(int pages) async {
    final allMangas = <Manga>[];
    final seenIds = <String>{};

    for (int page = 1; page <= pages; page++) {
      try {
        final pageUrl = page == 1
            ? '$baseUrl/manga/?m_orderby=latest'
            : '$baseUrl/manga/page/$page/?m_orderby=latest';
        
        final doc = await fetchDocument(pageUrl);
        final mangas = _extractMangasFromListPage(doc);

        for (final manga in mangas) {
          if (!seenIds.contains(manga.id)) {
            seenIds.add(manga.id);
            allMangas.add(manga.copyWith(source: name));
          }
        }
      } catch (e) {
        break;
      }
    }

    return allMangas;
  }

  @override
  Future<List<Manga>> searchManga(String query) async {
    final searchUrl = '$baseUrl/?s=${Uri.encodeComponent(query)}&post_type=wp-manga';
    final doc = await fetchDocument(searchUrl);
    final mangas = _extractMangasFromListPage(doc);

    return mangas.map((m) => m.copyWith(source: name)).toList();
  }

  @override
  Future<Manga?> getMangaDetails(String mangaUrl) async {
    final doc = await fetchDocument(mangaUrl);
    final mangaId = extractMangaId(mangaUrl);
    var title = formatMangaTitle(mangaId);

    // Try to get title from h1 or manga-title
    for (final selector in ['h1', '.manga-title', '.entry-title']) {
      final element = doc.querySelector(selector);
      if (element != null) {
        final text = element.text.trim();
        if (text.isNotEmpty &&
            !text.toLowerCase().contains('mangalivre') &&
            text.length > 3) {
          title = text;
          break;
        }
      }
    }

    // Get cover image
    var image = '';
    final coverImg = doc.querySelector('.summary_image img, img.wp-post-image, .manga-cover img, .manga-thumb img');
    if (coverImg != null) {
      image = normalizeUrl(getImageSrc(coverImg));
    }

    // Get description
    var description = '';
    for (final selector in ['.summary__content', '.description-summary', '.manga-excerpt', '.manga-description']) {
      final element = doc.querySelector(selector);
      if (element != null) {
        description = element.text.trim();
        if (description.isNotEmpty) break;
      }
    }

    // Determine status
    String? status;
    final fullText = doc.body?.text.toLowerCase() ?? '';
    if (fullText.contains('em lancamento') || fullText.contains('ongoing')) {
      status = 'Em Lancamento';
    } else if (fullText.contains('completo') || fullText.contains('completed') || fullText.contains('finalizado')) {
      status = 'Completo';
    }

    // Get genres
    final genres = <String>[];
    for (final link in doc.querySelectorAll('a[href*="/genero/"], a[href*="/genre/"]')) {
      final genre = link.text.trim();
      if (genre.isNotEmpty && !genres.contains(genre)) {
        genres.add(genre);
      }
    }

    // Get author
    String? author;
    final authorLink = doc.querySelector('a[href*="/manga-author/"], a[href*="/author/"]');
    if (authorLink != null) {
      author = authorLink.text.trim();
    }

    return Manga(
      id: mangaId,
      title: title,
      image: image,
      url: mangaUrl,
      description: description,
      status: status,
      genres: genres,
      author: author,
      source: name,
    );
  }

  @override
  Future<List<Chapter>> getChapters(String mangaUrl) async {
    final doc = await fetchDocument(mangaUrl);
    final mangaId = extractMangaId(mangaUrl);
    final mangaName = doc.querySelector('h1')?.text.trim() ?? '';

    final chapters = <Chapter>[];
    final seenUrls = <String>{};

    for (final link in doc.querySelectorAll('a[href*="/capitulo/"]')) {
      var href = link.attributes['href'] ?? '';
      if (href.isEmpty) continue;

      href = href.trim();
      if (!href.startsWith('http')) {
        href = normalizeUrl(href);
      }

      if (seenUrls.contains(href)) continue;

      // Ensure it's from the same manga
      if (!href.toLowerCase().contains(mangaId.toLowerCase())) continue;

      seenUrls.add(href);

      final chapter = _parseChapterFromUrl(href, mangaId, mangaName);
      if (chapter != null) {
        chapters.add(chapter);
      }
    }

    // Sort by chapter number
    chapters.sort((a, b) => a.numberFloat.compareTo(b.numberFloat));

    return chapters;
  }

  @override
  Future<List<MangaPage>> getChapterPages(String chapterUrl) async {
    final doc = await fetchDocument(chapterUrl);
    final pages = <MangaPage>[];
    final seenUrls = <String>{};

    // First try: images with "pagina" in alt
    for (final img in doc.querySelectorAll('img')) {
      final alt = (img.attributes['alt'] ?? '').toLowerCase();
      if (!alt.contains('pagina') && !alt.contains('página')) continue;

      var imgSrc = getImageSrc(img).trim();
      if (imgSrc.isNotEmpty && !seenUrls.contains(imgSrc) && imgSrc.contains('wp-content/uploads')) {
        seenUrls.add(imgSrc);
        pages.add(MangaPage(
          number: pages.length + 1,
          url: normalizeUrl(imgSrc),
        ));
      }
    }

    if (pages.isNotEmpty) return pages;

    // Fallback: all valid manga images
    for (final img in doc.querySelectorAll('img')) {
      var imgSrc = getImageSrc(img).trim();
      if (imgSrc.isNotEmpty && !seenUrls.contains(imgSrc) && isValidMangaImage(imgSrc)) {
        seenUrls.add(imgSrc);
        pages.add(MangaPage(
          number: pages.length + 1,
          url: normalizeUrl(imgSrc),
        ));
      }
    }

    return pages;
  }

  @override
  Future<List<Manga>> getMangasByGenre(String genre) async {
    final genreSlug = genre.toLowerCase().replaceAll(' ', '-');
    final genreUrl = '$baseUrl/genero/$genreSlug/';

    final doc = await fetchDocument(genreUrl);
    final mangas = _extractMangasFromListPage(doc);

    return mangas.map((m) {
      final genres = m.genres.toList();
      if (!genres.contains(genre)) genres.add(genre);
      return m.copyWith(source: name, genres: genres);
    }).toList();
  }

  @override
  Future<List<String>> getGenres() async {
    final doc = await fetchDocument(baseUrl);
    final genres = <String>[];
    final seen = <String>{};

    for (final link in doc.querySelectorAll('a[href*="/genero/"], a[href*="/genre/"]')) {
      var genre = link.text.trim();
      // Remove count suffix like "(123)"
      genre = genre.replaceAll(RegExp(r'\s*\(\d+\)\s*$'), '').trim();

      if (genre.isNotEmpty && !seen.contains(genre) && genre.length > 1) {
        seen.add(genre);
        genres.add(genre);
      }
    }

    return genres;
  }

  /// Extract mangas from a list page
  List<Manga> _extractMangasFromListPage(Document doc) {
    final mangas = <Manga>[];
    final seenUrls = <String>{};

    // Method 1: article.manga-card or div.manga-card with genres in classes
    for (final article in doc.querySelectorAll('article.manga-card, div.manga-card, .manga-card')) {
      final cssClass = article.attributes['class'] ?? '';
      final genres = extractGenresFromClass(cssClass);

      final link = article.querySelector('a[href*="/manga/"]');
      final href = link?.attributes['href'] ?? '';
      if (href.isEmpty) continue;

      if (href.contains('/capitulo') || href.contains('/chapter')) continue;

      final normalizedHref = normalizeUrl(href.trim());
      if (seenUrls.contains(normalizedHref)) continue;

      final titleElement = article.querySelector('.manga-card-title, h3');
      final title = titleElement?.text.trim() ?? '';
      if (title.isEmpty || title.length < 2) continue;

      final img = article.querySelector('img');
      final imgSrc = getImageSrc(img);

      seenUrls.add(normalizedHref);

      final finalGenres = genres.toList();
      if (isAdultContent(title, genres) && !finalGenres.contains('Adulto')) {
        finalGenres.add('Adulto');
      }

      mangas.add(Manga(
        id: extractMangaId(normalizedHref),
        title: title,
        image: normalizeUrl(imgSrc),
        url: normalizedHref,
        genres: finalGenres,
        source: name,
      ));
    }

    if (mangas.isNotEmpty) return mangas;

    // Method 2: h3 a or h2 a with href /manga/
    for (final a in doc.querySelectorAll('h3 a[href*="/manga/"], h2 a[href*="/manga/"]')) {
      final href = a.attributes['href'] ?? '';
      if (href.isEmpty) continue;

      if (href.contains('/capitulo') || href.contains('/chapter')) continue;

      final normalizedHref = normalizeUrl(href.trim());
      if (seenUrls.contains(normalizedHref)) continue;

      final title = a.text.trim();
      if (title.isEmpty || title.length < 2) continue;

      // Try to find parent container
      var parent = a.parent;
      while (parent != null && !['article', 'div'].contains(parent.localName)) {
        parent = parent.parent;
      }

      var imgSrc = '';
      var genres = <String>[];

      if (parent != null) {
        final cssClass = parent.attributes['class'] ?? '';
        genres = extractGenresFromClass(cssClass);

        final img = parent.querySelector('img');
        imgSrc = getImageSrc(img);
      }

      seenUrls.add(normalizedHref);

      final finalGenres = genres.toList();
      if (isAdultContent(title, genres) && !finalGenres.contains('Adulto')) {
        finalGenres.add('Adulto');
      }

      mangas.add(Manga(
        id: extractMangaId(normalizedHref),
        title: title,
        image: normalizeUrl(imgSrc),
        url: normalizedHref,
        genres: finalGenres,
        source: name,
      ));
    }

    return mangas;
  }

  /// Parse chapter info from URL
  Chapter? _parseChapterFromUrl(String href, String mangaId, String mangaName) {
    final lowerHref = href.toLowerCase();

    final regex = RegExp(r'(?:capitulo|chapter)-(\d+)(?:[.-](\d+|extra|final))?');
    final match = regex.firstMatch(lowerHref);

    int chapterNum = 0;
    double numFloat = 0.0;
    String chapterStr = '';

    if (match != null) {
      chapterNum = int.tryParse(match.group(1) ?? '') ?? 0;
      numFloat = chapterNum.toDouble();
      chapterStr = '$chapterNum';

      final suffix = match.group(2);
      if (suffix != null && suffix.isNotEmpty) {
        final decimal = int.tryParse(suffix);
        if (decimal != null) {
          numFloat += decimal / 10.0;
          chapterStr = '$chapterNum.$suffix';
        } else if (suffix == 'extra' || suffix == 'final') {
          numFloat += 0.5;
          chapterStr = '$chapterNum ${suffix.toUpperCase()}';
        }
      }
    } else if (lowerHref.contains('/completo')) {
      chapterNum = 1;
      numFloat = 1.0;
      chapterStr = 'Completo';
    } else if (lowerHref.contains('/oneshot')) {
      chapterNum = 1;
      numFloat = 1.0;
      chapterStr = 'Oneshot';
    } else {
      return null;
    }

    if (chapterNum == 0 && chapterStr.isEmpty) return null;

    var title = 'Capitulo $chapterStr';
    if (chapterStr == 'Completo' || chapterStr == 'Oneshot') {
      title = chapterStr;
    }

    return Chapter(
      number: chapterStr,
      numberFloat: numFloat,
      title: title,
      url: href,
      mangaId: mangaId,
      mangaName: mangaName,
    );
  }
}

/// Extension to add copyWith to Manga
extension MangaCopyWith on Manga {
  Manga copyWith({
    String? id,
    String? title,
    String? image,
    String? url,
    String? latestChapter,
    List<String>? genres,
    String? description,
    String? status,
    double? rating,
    int? views,
    String? author,
    String? source,
  }) {
    return Manga(
      id: id ?? this.id,
      title: title ?? this.title,
      image: image ?? this.image,
      url: url ?? this.url,
      latestChapter: latestChapter ?? this.latestChapter,
      genres: genres ?? this.genres,
      description: description ?? this.description,
      status: status ?? this.status,
      rating: rating ?? this.rating,
      views: views ?? this.views,
      author: author ?? this.author,
      source: source ?? this.source,
    );
  }
}
