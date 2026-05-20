// Extended test script for manga scraper
// Run with: dart run test/manga_scraper_full_test.dart

import 'package:goanime/services/manga/manga.dart';
import 'package:goanime/services/gomang_service.dart';

void main() async {
  print('=== Testing Full Manga Scraper Flow ===\n');
  
  // Test native scraper
  print('--- Testing Native Scraper ---');
  final scraper = MangaScraper();
  
  print('1. Getting popular mangas...');
  final popular = await scraper.getPopularMangas('mangalivre.blog');
  print('   Found ${popular.length} popular mangas');
  
  if (popular.isNotEmpty) {
    final manga = popular.first;
    print('\n2. Testing with: ${manga.title}');
    print('   URL: ${manga.url}');
    
    print('\n3. Getting chapters...');
    final chapters = await scraper.getChapters(manga.url);
    print('   Found ${chapters.length} chapters');
    
    if (chapters.isNotEmpty) {
      final chapter = chapters.first;
      print('   First chapter: ${chapter.title}');
      print('   Chapter URL: ${chapter.url}');
      
      print('\n4. Getting chapter pages...');
      final pages = await scraper.getChapterPages(chapter.url);
      print('   Found ${pages.length} pages');
      if (pages.isNotEmpty) {
        print('   First page: ${pages.first.url}');
        print('   Last page: ${pages.last.url}');
      }
    }
  }
  
  scraper.dispose();
  
  // Test GomangService (should use native scraper)
  print('\n\n--- Testing GomangService (Native Scraper) ---');
  final service = GomangService();
  
  print('1. Sources: ${service.sources}');
  
  print('\n2. Getting popular...');
  final popularJson = await service.getPopular();
  print('   Found ${popularJson.length} mangas');
  if (popularJson.isNotEmpty) {
    print('   First: ${popularJson.first['title']}');
  }
  
  print('\n3. Searching for "one piece"...');
  final searchResults = await service.search('one piece');
  print('   Found ${searchResults.length} results');
  for (var i = 0; i < searchResults.length && i < 5; i++) {
    print('   ${i + 1}. ${searchResults[i]['title']}');
  }
  
  if (popularJson.isNotEmpty) {
    final mangaUrl = popularJson.first['url'];
    print('\n4. Getting chapters for ${popularJson.first['title']}...');
    final chaptersJson = await service.getMangaChapters(mangaUrl);
    print('   Found ${chaptersJson.length} chapters');
    
    if (chaptersJson.isNotEmpty) {
      final chapterUrl = chaptersJson.first['url'];
      print('\n5. Getting pages for first chapter...');
      final pagesJson = await service.getChapterPages(chapterUrl);
      print('   Found ${pagesJson.length} pages');
    }
  }
  
  service.dispose();
  
  print('\n=== All Tests Complete ===');
}
