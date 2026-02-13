import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import '../models/novel.dart';
import '../models/episode.dart';

/// Scraper that supports multiple novel sites
class NovelScraper {
  static const Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'ja,en-US;q=0.7,en;q=0.3',
  };

  /// Detect the source site from a URL
  static String detectSource(String url) {
    if (url.contains('ncode.syosetu.com') || url.contains('novel18.syosetu.com')) {
      return 'narou';
    } else if (url.contains('kakuyomu.jp')) {
      return 'kakuyomu';
    } else if (url.contains('syosetu.org')) {
      return 'hameln';
    }
    return 'unknown';
  }

  /// Extract ncode from URL
  static String? extractNcode(String url) {
    final narouMatch =
        RegExp(r'ncode\.syosetu\.com/([a-zA-Z0-9]+)').firstMatch(url);
    if (narouMatch != null) return narouMatch.group(1)!.toLowerCase();

    final kakuyomuMatch =
        RegExp(r'kakuyomu\.jp/works/(\d+)').firstMatch(url);
    if (kakuyomuMatch != null) return 'ky_${kakuyomuMatch.group(1)}';

    final hamelnMatch =
        RegExp(r'syosetu\.org/novel/(\d+)').firstMatch(url);
    if (hamelnMatch != null) return 'hm_${hamelnMatch.group(1)}';

    return null;
  }

  // ── Narou (小説家になろう) ────────────────────────────

  /// Fetch novel info from Narou API
  static Future<Novel?> fetchNarouNovelInfo(String ncode) async {
    // Add ga (general_all_no) for totalEpisodes, l (length) for totalCharacters
    final apiUrl = 'https://api.syosetu.com/novelapi/api/?ncode=$ncode&of=t-w-s-k-gf-gl-ga-l&out=json';
    try {
      final response = await http.get(Uri.parse(apiUrl), headers: _headers);
      if (response.statusCode != 200) return null;

      final List<dynamic> data = json.decode(response.body);
      if (data.length < 2) return null;

      final info = data[1] as Map<String, dynamic>;
      
      // Handle potential int/string type issues from API (though usually JSON handles numbers)
      final totalEpisodes = info['general_all_no'] is int 
          ? info['general_all_no'] 
          : int.tryParse(info['general_all_no']?.toString() ?? '0') ?? 0;
          
      final totalCharacters = info['length'] is int
          ? info['length']
          : int.tryParse(info['length']?.toString() ?? '0') ?? 0;

      return Novel(
        ncode: ncode.toLowerCase(),
        title: info['title'] as String? ?? 'Unknown',
        author: info['writer'] as String? ?? 'Unknown',
        synopsis: info['story'] as String? ?? '',
        source: 'narou',
        sourceUrl: 'https://ncode.syosetu.com/$ncode/',
        totalEpisodes: totalEpisodes,
        totalCharacters: totalCharacters,
        lastUpdated: info['general_lastup'] != null
            ? DateTime.tryParse(info['general_lastup'] as String)
            : null,
      );
    } catch (e) {
      print('Error fetching narou info: $e');
      return null;
    }
  }

  /// Fetch episode list from Narou (handles pagination)
  static Future<List<Map<String, String>>> fetchNarouEpisodeList(
      String ncode) async {
    // Start with the base URL
    String url = 'https://ncode.syosetu.com/$ncode/';
    final episodes = <Map<String, String>>[];
    final visitedUrls = <String>{};

    try {
      while (true) {
        if (visitedUrls.contains(url)) break;
        visitedUrls.add(url);

        final response = await http.get(Uri.parse(url), headers: _headers);
        if (response.statusCode != 200) break;

        final doc = html_parser.parse(utf8.decode(response.bodyBytes));

        final links = doc.querySelectorAll(
            '.novel_sublist2 a, .p-eplist__sublist a, dl.novel_sublist2 a');

        if (links.isEmpty && episodes.isEmpty) {
          // Single-page novel check only on first page
          episodes.add({'number': '1', 'title': '本文', 'url': url});
          break;
        }

        for (int i = 0; i < links.length; i++) {
          final href = links[i].attributes['href'] ?? '';
          if (href.isNotEmpty) {
             episodes.add({
              'number': '${episodes.length + 1}', // Sequential numbering
              'title': links[i].text.trim(),
              'url': 'https://ncode.syosetu.com$href',
            });
          }
        }

        // Check for next page
        // Selector fix: The class is directly on the <a> tag
        final nextLink = doc.querySelector(
            'a.c-pager__item--next, a.pager_next, a.next_link');
        if (nextLink != null) {
          final nextHref = nextLink.attributes['href'];
          if (nextHref != null) {
            url = nextHref.startsWith('http')
                ? nextHref
                : 'https://ncode.syosetu.com$nextHref';
            // Wait slightly to be polite
            await Future.delayed(const Duration(milliseconds: 500));
            continue;
          }
        }
        break; // No next page
      }
      return episodes;
    } catch (e) {
      print('Error fetching episode list: $e');
      return episodes; // Return what we have so far
    }
  }

  /// Fetch a single episode content from Narou
  static Future<Episode?> fetchNarouEpisode(
      int novelId, String ncode, int episodeNumber) async {
    final url = 'https://ncode.syosetu.com/$ncode/$episodeNumber/';
    try {
      final response = await http.get(Uri.parse(url), headers: _headers);
      if (response.statusCode != 200) return null;

      final doc = html_parser.parse(utf8.decode(response.bodyBytes));

      // Extract title
      final titleEl = doc.querySelector('.novel_subtitle, .p-novel__subtitle');
      final title = titleEl?.text.trim() ?? 'Episode $episodeNumber';

      // Extract body (main content)
      final bodyEl = doc.querySelector('#novel_honbun, .p-novel__body');
      final body = _cleanHtml(bodyEl);

      // Extract preface
      final prefaceEl = doc.querySelector('#novel_p, .p-novel__preface');
      final preface = _cleanHtml(prefaceEl);

      // Extract afterword
      final afterwordEl = doc.querySelector('#novel_a, .p-novel__afterword');
      final afterword = _cleanHtml(afterwordEl);

      final characterCount = body.length;

      return Episode(
        novelId: novelId,
        episodeNumber: episodeNumber,
        title: title,
        body: body,
        preface: preface.isEmpty ? null : preface,
        afterword: afterword.isEmpty ? null : afterword,
        characterCount: characterCount,
        downloadedAt: DateTime.now(),
      );
    } catch (e) {
      print('Error fetching episode $episodeNumber: $e');
      return null;
    }
  }

  // ── Kakuyomu (カクヨム) ─────────────────────────────

  /// Fetch novel info from Kakuyomu
  static Future<Novel?> fetchKakuyomuNovelInfo(String workId) async {
    final url = 'https://kakuyomu.jp/works/$workId';
    try {
      final response = await http.get(Uri.parse(url), headers: _headers);
      if (response.statusCode != 200) return null;

      final doc = html_parser.parse(utf8.decode(response.bodyBytes));

      final title = doc.querySelector('#workTitle a, .NewBox_workTitle__bqBSb')?.text.trim() ?? 'Unknown';
      final author = doc.querySelector('#workAuthor-activityName a, .partialGiftWidgetActivityName')?.text.trim() ?? 'Unknown';
      final synopsis = doc.querySelector('#introduction, .NewBox_synopsis__abJMy')?.text.trim() ?? '';

      final episodeLinks = doc.querySelectorAll('.widget-toc-episode a, .NewBox_episodeList__KAMi5 a');

      return Novel(
        ncode: 'ky_$workId',
        title: title,
        author: author,
        synopsis: synopsis,
        source: 'kakuyomu',
        sourceUrl: url,
        totalEpisodes: episodeLinks.length,
      );
    } catch (e) {
      print('Error fetching kakuyomu info: $e');
      return null;
    }
  }

  /// Fetch episode list from Kakuyomu
  static Future<List<Map<String, String>>> fetchKakuyomuEpisodeList(
      String workId) async {
    final url = 'https://kakuyomu.jp/works/$workId';
    try {
      final response = await http.get(Uri.parse(url), headers: _headers);
      if (response.statusCode != 200) return [];

      final doc = html_parser.parse(utf8.decode(response.bodyBytes));
      final episodes = <Map<String, String>>[];

      final links = doc.querySelectorAll(
          '.widget-toc-episode a, .NewBox_episodeList__KAMi5 a');

      for (int i = 0; i < links.length; i++) {
        final href = links[i].attributes['href'] ?? '';
        episodes.add({
          'number': '${i + 1}',
          'title': links[i].text.trim(),
          'url': 'https://kakuyomu.jp$href',
        });
      }
      return episodes;
    } catch (e) {
      print('Error fetching kakuyomu episode list: $e');
      return [];
    }
  }

  /// Fetch a single episode content from Kakuyomu
  static Future<Episode?> fetchKakuyomuEpisode(
      int novelId, String url, int episodeNumber) async {
    try {
      final response = await http.get(Uri.parse(url), headers: _headers);
      if (response.statusCode != 200) return null;

      final doc = html_parser.parse(utf8.decode(response.bodyBytes));

      final title = doc
              .querySelector('.widget-episodeTitle, .EpisodeHeader_title__yIDt4')
              ?.text
              .trim() ??
          'Episode $episodeNumber';
      final bodyEl = doc.querySelector(
          '.widget-episodeBody, .EpisodeBody_episodeBody__tA251');
      final body = _cleanHtml(bodyEl);

      return Episode(
        novelId: novelId,
        episodeNumber: episodeNumber,
        title: title,
        body: body,
        preface: null,
        afterword: null,
        characterCount: body.length,
        downloadedAt: DateTime.now(),
      );
    } catch (e) {
      print('Error fetching kakuyomu episode $episodeNumber: $e');
      return null;
    }
  }

  // ── Hameln (ハーメルン) ──────────────────────────────

  /// Fetch novel info from Hameln
  static Future<Novel?> fetchHamelnNovelInfo(String novelId) async {
    final url = 'https://syosetu.org/novel/$novelId/';
    try {
      final response = await http.get(Uri.parse(url), headers: _headers);
      if (response.statusCode != 200) return null;

      final doc = html_parser.parse(utf8.decode(response.bodyBytes));

      final title = doc.querySelector('span.ss a')?.text.trim() ?? 'Unknown';
      final author = doc.querySelector('span.ss + span a')?.text.trim() ?? 'Unknown';

      final episodeLinks = doc.querySelectorAll('table.index_box a');

      return Novel(
        ncode: 'hm_$novelId',
        title: title,
        author: author,
        synopsis: '',
        source: 'hameln',
        sourceUrl: url,
        totalEpisodes: episodeLinks.length,
      );
    } catch (e) {
      print('Error fetching hameln info: $e');
      return null;
    }
  }

  /// Fetch episode list from Hameln (handles pagination)
  static Future<List<Map<String, String>>> fetchHamelnEpisodeList(
      String novelId) async {
    String url = 'https://syosetu.org/novel/$novelId/';
    final episodes = <Map<String, String>>[];
    final visitedUrls = <String>{};

    try {
      while (true) {
        if (visitedUrls.contains(url)) break;
        visitedUrls.add(url);

        final response = await http.get(Uri.parse(url), headers: _headers);
        if (response.statusCode != 200) break;

        final doc = html_parser.parse(utf8.decode(response.bodyBytes));
        
        // Hameln uses table rows
        final rows = doc.querySelectorAll('table.index_box tr');
        
        for (var row in rows) {
          final link = row.querySelector('a');
          if (link != null) {
            final href = link.attributes['href'] ?? '';
             // Check if it's an episode link (ends with .html)
             if (href.endsWith('.html')) {
                episodes.add({
                  'number': '${episodes.length + 1}',
                  'title': link.text.trim(),
                  'url': 'https://syosetu.org$href', 
                });
             }
          }
        }

        // Check for next page (Hameln pager is usually bottom)
        // Selectors like: span.pager > a:last-child (if text is Next) or checking text
        // Hameln often has [1] [2] ... [Next]
        // Look for <a> tag containing "次へ" or similar inside .pager or pure text search in links
        final nextLink = doc.querySelectorAll('span.pager a, div.pager a').where((a) {
           return a.text.contains('次へ') || a.text.contains('>');
        }).firstOrNull;

        if (nextLink != null) {
          final nextHref = nextLink.attributes['href'];
          if (nextHref != null) {
            url = 'https://syosetu.org$nextHref'; // Usually relative
            await Future.delayed(const Duration(milliseconds: 500));
            continue;
          }
        }
        break; 
      }
      return episodes;
    } catch (e) {
      print('Error fetching hameln episode list: $e');
      return episodes;
    }
  }

  /// Fetch a single episode content from Hameln
  static Future<Episode?> fetchHamelnEpisode(
      int novelId, String url, int episodeNumber) async {
    try {
      // Hameln sometimes checks cookies/referrers strictly
      final response = await http.get(Uri.parse(url), headers: {
        ..._headers,
        'Cookie': 'over18=off;',
      });
      if (response.statusCode != 200) return null;

      final doc = html_parser.parse(utf8.decode(response.bodyBytes));

      final title = doc.querySelector('span.ss')?.text.trim() ?? 'Episode $episodeNumber';
      final bodyEl = doc.querySelector('#text');
      final body = _cleanHtml(bodyEl);

      final prefaceEl = doc.querySelector('#maegaki');
      final preface = _cleanHtml(prefaceEl);

      final afterwordEl = doc.querySelector('#atogaki');
      final afterword = _cleanHtml(afterwordEl);

      return Episode(
        novelId: novelId,
        episodeNumber: episodeNumber,
        title: title,
        body: body,
        preface: preface.isEmpty ? null : preface,
        afterword: afterword.isEmpty ? null : afterword,
        characterCount: body.length,
        downloadedAt: DateTime.now(),
      );
    } catch (e) {
      print('Error fetching hameln episode $episodeNumber: $e');
      return null;
    }
  }

  // ── Universal fetch ──────────────────────────────────

  /// Fetch novel info from any supported URL
  static Future<Novel?> fetchNovelFromUrl(String url) async {
    final source = detectSource(url);
    switch (source) {
      case 'narou':
        final ncode = extractNcode(url);
        if (ncode == null) return null;
        return fetchNarouNovelInfo(ncode);
      case 'kakuyomu':
        final match = RegExp(r'works/(\d+)').firstMatch(url);
        if (match == null) return null;
        return fetchKakuyomuNovelInfo(match.group(1)!);
      case 'hameln':
        final match = RegExp(r'novel/(\d+)').firstMatch(url);
        if (match == null) return null;
        return fetchHamelnNovelInfo(match.group(1)!);
      default:
        return null;
    }
  }

  /// Search Narou using API
  static Future<List<Novel>> searchNarou(String query) async {
    // API endpoint: https://api.syosetu.com/novelapi/api/
    // Parameters: out=json, lim=20, word={query}, order=hyoka (rating order)
    final url =
        'https://api.syosetu.com/novelapi/api/?out=json&lim=20&word=${Uri.encodeComponent(query)}&order=hyoka';

    try {
      final response = await http.get(Uri.parse(url), headers: _headers);

      if (response.statusCode == 200) {
        final List<dynamic> json = jsonDecode(utf8.decode(response.bodyBytes));
        // The first element is metadata (allcount), skip it
        if (json.isNotEmpty && json.length > 1) {
          final results = <Novel>[];
          for (int i = 1; i < json.length; i++) {
            final item = json[i];
            results.add(Novel(
              title: item['title'] ?? '無題',
              author: item['writer'] ?? '不明',
              ncode: (item['ncode'] as String).toLowerCase(),
              source: 'narou',
              sourceUrl: 'https://ncode.syosetu.com/${(item['ncode'] as String).toLowerCase()}/',
              synopsis: item['story'] ?? '',
              totalEpisodes: item['general_all_no'] ?? 0,
              totalCharacters: item['length'] ?? 0,
            ));
          }
          return results;
        }
      }
    } catch (e) {
      print('Search error: $e');
    }
    return [];
  }

  // ── Helpers ──────────────────────────────────────────

  /// Clean HTML content, removing ads, social buttons, etc.
  static String _cleanHtml(Element? element) {
    if (element == null) return '';

    // Remove unwanted elements
    element.querySelectorAll(
      'script, style, iframe, .ad, .ads, .social, .share, '
      '.twitter-share, .facebook-share, .bookmark, .novel_bn, '
      '[class*="ad-"], [id*="ad-"], .koukoku, ins.adsbygoogle'
    ).forEach((el) => el.remove());

    // Convert <br> to newlines, <p> to double newlines
    String text = element.innerHtml;
    text = text.replaceAll(RegExp(r'<br\s*/?>'), '\n');
    text = text.replaceAll(RegExp(r'</p>\s*<p[^>]*>'), '\n\n');
    text = text.replaceAll(RegExp(r'<ruby>([^<]*)<rb>([^<]*)</rb><rp>[^<]*</rp><rt>([^<]*)</rt><rp>[^<]*</rp></ruby>'), '【\\2|\\3】');

    // Strip remaining HTML tags but preserve ruby annotations
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');
    text = text.replaceAll('&nbsp;', ' ');
    text = text.replaceAll('&lt;', '<');
    text = text.replaceAll('&gt;', '>');
    text = text.replaceAll('&amp;', '&');
    text = text.replaceAll('&quot;', '"');

    // Clean up excessive whitespace
    text = text.split('\n').map((line) => line.trim()).join('\n');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }
}
