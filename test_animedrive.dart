import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

const String _baseUrl = 'https://animesdrive.blog';
const String _userAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

Map<String, String> get _headers => {
  'User-Agent': _userAgent,
  'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
  'Accept-Language': 'pt-BR,pt;q=0.9,en-US;q=0.8,en;q=0.7',
  'Referer': _baseUrl,
};

Future<void> main() async {
  print('=== Testando AnimeDrive Service ===\n');
  
  // Teste 1: Buscar na página inicial
  print('1. Buscando animes na página inicial...');
  try {
    final response = await http
        .get(Uri.parse(_baseUrl), headers: _headers)
        .timeout(const Duration(seconds: 15));
    
    print('Status: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      final document = html_parser.parse(response.body);
      
      // Busca artigos/items
      final items = document.querySelectorAll('article, .item, .post');
      print('Encontrados ${items.length} items na página');
      
      // Mostra os primeiros 5
      for (var i = 0; i < items.length && i < 5; i++) {
        final item = items[i];
        final title = item.querySelector('h2, h3, .title, a')?.text.trim() ?? 'Sem título';
        final link = item.querySelector('a')?.attributes['href'] ?? '';
        print('  - $title');
        print('    URL: $link');
      }
    }
  } catch (e) {
    print('Erro: $e');
  }
  
  print('\n2. Testando busca por "naruto"...');
  try {
    final searchUrl = Uri.parse('$_baseUrl/?s=naruto');
    final response = await http
        .get(searchUrl, headers: _headers)
        .timeout(const Duration(seconds: 15));
    
    print('Status: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      final document = html_parser.parse(response.body);
      
      // Busca resultados
      final results = document.querySelectorAll('article, .result-item, .item');
      print('Encontrados ${results.length} resultados');
      
      for (var i = 0; i < results.length && i < 5; i++) {
        final item = results[i];
        final title = item.querySelector('h2, h3, .title, a')?.text.trim() ?? 'Sem título';
        final link = item.querySelector('a')?.attributes['href'] ?? '';
        print('  - $title');
        print('    URL: $link');
      }
    }
  } catch (e) {
    print('Erro: $e');
  }
  
  print('\n3. Testando extração de episódio específico...');
  final testUrl = 'https://animesdrive.blog/episodio/chanto-suenai-kyuuketsuki-chan-episodio-11';
  try {
    final response = await http
        .get(Uri.parse(testUrl), headers: _headers)
        .timeout(const Duration(seconds: 15));
    
    print('Status: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      final body = response.body;
      
      // Busca links MP4
      final mp4Matches = RegExp(
        'https?://[^\\s<>"]+\\.mp4',
        caseSensitive: false,
      ).allMatches(body);
      
      print('Links MP4 encontrados: ${mp4Matches.length}');
      for (final match in mp4Matches) {
        print('  - ${match.group(0)}');
      }
      
      // Busca iframes
      final document = html_parser.parse(body);
      final iframes = document.querySelectorAll('iframe');
      print('\nIframes encontrados: ${iframes.length}');
      for (final iframe in iframes) {
        final src = iframe.attributes['src'] ?? iframe.attributes['data-src'] ?? 'sem src';
        print('  - $src');
      }
      
      // Busca scripts com player
      print('\nBuscando em scripts...');
      final scripts = document.querySelectorAll('script');
      for (final script in scripts) {
        final text = script.text;
        if (text.contains('mp4') || text.contains('m3u8') || text.contains('player') || text.contains('source')) {
          print('Script interessante encontrado (${text.length} chars):');
          if (text.length < 500) {
            print(text);
          } else {
            print('${text.substring(0, 500)}...');
          }
        }
      }
    }
  } catch (e) {
    print('Erro: $e');
  }
  
  print('\n=== Teste concluído ===');
}
