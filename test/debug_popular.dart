// Debug popular mangas
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

void main() async {
  final client = http.Client();

  // Test popular
  final url = 'https://mangalivre.blog/manga/?m_orderby=views';
  print('Testing: $url\n');

  final resp = await client.get(
    Uri.parse(url),
    headers: {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    },
  );

  print('Status: ${resp.statusCode}');

  final doc = html_parser.parse(resp.body);

  // Check selectors
  print('\n=== Selectors count ===');
  print(
    'article.manga-card: ${doc.querySelectorAll("article.manga-card").length}',
  );
  print('div.manga-card: ${doc.querySelectorAll("div.manga-card").length}');
  print('.manga-card: ${doc.querySelectorAll(".manga-card").length}');
  print(
    '.page-item-detail: ${doc.querySelectorAll(".page-item-detail").length}',
  );
  print('.badge-pos-1: ${doc.querySelectorAll(".badge-pos-1").length}');
  print(
    'a[href*="/manga/"] unique: ${doc.querySelectorAll("a[href*='/manga/']").map((e) => e.attributes['href']).toSet().length}',
  );

  // Get all unique manga links
  print('\n=== All manga links ===');
  final mangaLinks = <String>{};
  for (final a in doc.querySelectorAll('a[href*="/manga/"]')) {
    final href = a.attributes['href'] ?? '';
    if (href.contains('/manga/') &&
        !href.contains('?') &&
        !href.endsWith('/manga/')) {
      mangaLinks.add(href);
    }
  }
  print('Found ${mangaLinks.length} unique manga URLs');
  for (final link in mangaLinks.take(15)) {
    print('  $link');
  }

  // Show manga-card results
  print('\n=== .manga-card results ===');
  for (final card in doc.querySelectorAll('.manga-card').take(5)) {
    final title =
        card.querySelector('.manga-card-title, h3')?.text.trim() ?? 'NO TITLE';
    final link = card.querySelector('a')?.attributes['href'] ?? 'NO LINK';
    print('  $title -> $link');
  }

  // Check page-item-detail (common madara theme selector)
  print('\n=== .page-item-detail results ===');
  for (final item in doc.querySelectorAll('.page-item-detail').take(5)) {
    final title =
        item.querySelector('h3 a, h5 a, .post-title a')?.text.trim() ??
        'NO TITLE';
    print('  $title');
  }

  client.close();
}
