import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

void main() async {
  final ncode = 'n9669bk'; // Mushoku Tensei
  final url = 'https://ncode.syosetu.com/$ncode/';
  final headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
  };

  print('Fetching $url...');
  final response = await http.get(Uri.parse(url), headers: headers);
  if (response.statusCode != 200) {
    print('Failed to fetch: ${response.statusCode}');
    return;
  }

  final doc = html_parser.parse(utf8.decode(response.bodyBytes));
  
  // Check episode count on first page
  final links = doc.querySelectorAll('.novel_sublist2 a, .p-eplist__sublist a, dl.novel_sublist2 a');
  print('Found ${links.length} episodes on page 1.');

  // Check for next page link
  print('\nLooking for next page link...');
  
  // Try various selectors
  final selectors = [
    '.c-pager__item--next a',
    '.pager_next a',
    'a.next_link',
    'span.pager a',
    'div.pager_relative a'
  ];

  for (final selector in selectors) {
    final elements = doc.querySelectorAll(selector);
    print('Selector "$selector": found ${elements.length} elements');
    for (final el in elements) {
      print('  - Text: "${el.text.trim()}", Href: "${el.attributes['href']}"');
    }
  }

  // Print raw pager HTML if possible
  final pager = doc.querySelector('.c-pager, .pager, .pager_relative');
  if (pager != null) {
    print('\nPager HTML:\n${pager.outerHtml}');
  } else {
    print('\nPager element not found.');
  }
}
