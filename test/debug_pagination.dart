// Debug pagination and total count
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

void main() async {
  final client = http.Client();
  
  int totalMangas = 0;
  
  // Check multiple pages
  for (int page = 1; page <= 5; page++) {
    final url = page == 1 
        ? 'https://mangalivre.blog/manga/?m_orderby=views'
        : 'https://mangalivre.blog/manga/page/$page/?m_orderby=views';
    
    try {
      final resp = await client.get(Uri.parse(url), headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
      });
      
      if (resp.statusCode != 200) {
        print('Page $page: Status ${resp.statusCode}');
        break;
      }
      
      final doc = html_parser.parse(resp.body);
      final cards = doc.querySelectorAll('.manga-card');
      
      print('Page $page: ${cards.length} mangas');
      totalMangas += cards.length;
      
      if (cards.isEmpty) break;
    } catch (e) {
      print('Page $page: Error - $e');
      break;
    }
  }
  
  print('\nTotal mangas found (5 pages): $totalMangas');
  
  // Also check /manga/ without orderby
  print('\n=== Checking /manga/ base ===');
  final resp = await client.get(Uri.parse('https://mangalivre.blog/manga/'), headers: {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
  });
  final doc = html_parser.parse(resp.body);
  print('Base /manga/: ${doc.querySelectorAll(".manga-card").length} mangas');
  
  // Check for pagination links
  final paginationLinks = doc.querySelectorAll('a[href*="/manga/page/"]');
  final maxPage = paginationLinks
      .map((e) => e.attributes['href'] ?? '')
      .where((h) => h.contains('/page/'))
      .map((h) {
        final match = RegExp(r'/page/(\d+)').firstMatch(h);
        return match != null ? int.tryParse(match.group(1)!) ?? 0 : 0;
      })
      .fold(0, (a, b) => a > b ? a : b);
  print('Max page found in pagination: $maxPage');
  
  client.close();
}
