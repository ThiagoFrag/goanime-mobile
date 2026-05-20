// Check total mangas on site
import 'package:goanime/services/gomang_service.dart';

void main() async {
  final service = GomangService();
  
  print('=== Checking Total Mangas on MangaLivre.blog ===\n');
  
  // Get 5 pages of all mangas
  print('Loading 5 pages of mangas...');
  final mangas = await service.getMangasMultiplePages(startPage: 1, endPage: 5);
  print('Found ${mangas.length} mangas in 5 pages\n');
  
  // Print some titles
  print('First 20 mangas:');
  for (int i = 0; i < 20 && i < mangas.length; i++) {
    print('  ${i + 1}. ${mangas[i]['title']}');
  }
  
  // Test some searches
  print('\n=== Testing Searches ===');
  
  final searchTerms = ['dragon', 'one', 'naruto', 'attack', 'demon', 'jujutsu', 'solo'];
  for (final term in searchTerms) {
    final results = await service.search(term);
    print('Search "$term": ${results.length} results');
    if (results.isNotEmpty) {
      for (final r in results.take(3)) {
        print('  - ${r['title']}');
      }
    }
  }
  
  service.dispose();
}
