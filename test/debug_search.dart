// Debug search test
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

void main() async {
  final client = http.Client();
  
  // Test search for 'one piece'
  final url = 'https://mangalivre.blog/?s=one+piece&post_type=wp-manga';
  print('Testing: $url');
  
  final resp = await client.get(Uri.parse(url), headers: {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
  });
  
  print('Status: ${resp.statusCode}');
  
  final doc = html_parser.parse(resp.body);
  
  // Check different selectors
  print('\narticle.manga-card: ${doc.querySelectorAll("article.manga-card").length}');
  print('div.manga-card: ${doc.querySelectorAll("div.manga-card").length}');
  print('.manga-card: ${doc.querySelectorAll(".manga-card").length}');
  print('a[href*="/manga/"]: ${doc.querySelectorAll("a[href*='/manga/']").length}');
  print('.c-tabs-item: ${doc.querySelectorAll(".c-tabs-item").length}');
  print('.row.c-tabs-item__content: ${doc.querySelectorAll(".row.c-tabs-item__content").length}');
  
  // Show what we find in manga-card
  print('\n--- Found in .manga-card ---');
  for (final card in doc.querySelectorAll('.manga-card')) {
    final title = card.querySelector('.manga-card-title, h3')?.text.trim() ?? 'NO TITLE';
    final link = card.querySelector('a[href*="/manga/"]')?.attributes['href'] ?? 'NO LINK';
    print('Found: $title -> $link');
  }
  
  // Try alternate selectors for search results
  print('\n--- Looking for search-specific elements ---');
  for (final item in doc.querySelectorAll('.c-tabs-item, .search-wrap, .tab-content-wrap')) {
    print('Tab item found: ${item.className}');
    final links = item.querySelectorAll('a[href*="/manga/"]');
    for (final link in links) {
      print('  Link: ${link.attributes['href']}');
    }
  }
  
  // Check for any h3/h4 with manga links
  print('\n--- h3/h4 with manga links ---');
  for (final h in doc.querySelectorAll('h3 a[href*="/manga/"], h4 a[href*="/manga/"]')) {
    print('Title link: ${h.text.trim()} -> ${h.attributes['href']}');
  }
  
  client.close();
}
