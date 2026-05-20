// Test script for manga scraper
// Run with: dart run test/manga_scraper_test.dart

import 'package:goanime/services/manga/manga.dart';

void main() async {
  print('=== Testing Manga Scraper ===\n');
  
  final scraper = MangaScraper();
  
  print('Available sources: ${scraper.sources}');
  print('Source info: ${scraper.sourceInfo.map((s) => s.toJson())}');
  
  print('\n--- Testing getPopularMangas ---');
  try {
    final popular = await scraper.getPopularMangas('mangalivre.blog');
    print('Found ${popular.length} popular mangas');
    if (popular.isNotEmpty) {
      print('First manga: ${popular.first.title}');
      print('  URL: ${popular.first.url}');
      print('  Image: ${popular.first.image}');
    }
  } catch (e) {
    print('Error: $e');
  }
  
  print('\n--- Testing searchManga ---');
  try {
    final results = await scraper.searchManga('mangalivre.blog', 'naruto');
    print('Found ${results.length} results for "naruto"');
    for (var i = 0; i < results.length && i < 3; i++) {
      print('  ${i + 1}. ${results[i].title}');
    }
  } catch (e) {
    print('Error: $e');
  }
  
  print('\n--- Testing getChapters ---');
  try {
    final popular = await scraper.getPopularMangas('mangalivre.blog');
    if (popular.isNotEmpty) {
      final mangaUrl = popular.first.url;
      print('Getting chapters for: ${popular.first.title}');
      final chapters = await scraper.getChapters(mangaUrl);
      print('Found ${chapters.length} chapters');
      if (chapters.isNotEmpty) {
        print('First chapter: ${chapters.first.title} (${chapters.first.url})');
      }
    }
  } catch (e) {
    print('Error: $e');
  }
  
  print('\n=== Test Complete ===');
  scraper.dispose();
}
