import 'package:flutter/material.dart';
import '../models/novel.dart';
import '../models/episode.dart';
import '../services/database_service.dart';
import '../services/novel_scraper.dart';

class LibraryProvider extends ChangeNotifier {
  final DatabaseService _db;
  List<Novel> _novels = [];
  List<Novel> _filteredNovels = [];
  List<String> _folders = ['default'];
  String _currentFolder = 'all';
  String _searchQuery = '';
  String _sortBy = 'last_read'; // last_read, title, author, updated
  bool _isLoading = false;
  String? _error;
  double _downloadProgress = 0.0;
  String _downloadStatus = '';

  LibraryProvider(this._db) {
    loadNovels();
  }

  // Getters
  List<Novel> get novels => _filteredNovels;
  List<Novel> get allNovels => _novels;
  List<String> get folders => _folders;
  String get currentFolder => _currentFolder;
  bool get isLoading => _isLoading;
  String? get error => _error;
  double get downloadProgress => _downloadProgress;
  String get downloadStatus => _downloadStatus;
  int get totalNovels => _novels.length;

  Future<void> loadNovels() async {
    _isLoading = true;
    notifyListeners();

    try {
      _novels = await _db.getAllNovels();
      _folders = await _db.getAllFolders();
      if (!_folders.contains('default')) _folders.insert(0, 'default');
      _applyFilters();
      _error = null;
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  void setFolder(String folder) {
    _currentFolder = folder;
    _applyFilters();
    notifyListeners();
  }

  void setSearch(String query) {
    _searchQuery = query;
    _applyFilters();
    notifyListeners();
  }

  void setSortBy(String sortBy) {
    _sortBy = sortBy;
    _applyFilters();
    notifyListeners();
  }

  void _applyFilters() {
    var result = List<Novel>.from(_novels);

    // Filter by folder
    if (_currentFolder != 'all') {
      if (_currentFolder == 'favorites') {
        result = result.where((n) => n.isFavorite).toList();
      } else {
        result = result.where((n) => n.folder == _currentFolder).toList();
      }
    }

    // Filter by search
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result
          .where((n) =>
              n.title.toLowerCase().contains(q) ||
              n.author.toLowerCase().contains(q) ||
              n.tags.toLowerCase().contains(q))
          .toList();
    }

    // Sort
    switch (_sortBy) {
      case 'title':
        result.sort((a, b) => a.title.compareTo(b.title));
        break;
      case 'author':
        result.sort((a, b) => a.author.compareTo(b.author));
        break;
      case 'updated':
        result.sort((a, b) =>
            (b.lastUpdated ?? DateTime(2000))
                .compareTo(a.lastUpdated ?? DateTime(2000)));
        break;
      case 'last_read':
      default:
        result.sort((a, b) =>
            (b.lastReadAt ?? b.createdAt)
                .compareTo(a.lastReadAt ?? a.createdAt));
        break;
    }

    _filteredNovels = result;
  }

  /// Add a novel from URL
  Future<Novel?> addNovelFromUrl(String url) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final novel = await NovelScraper.fetchNovelFromUrl(url);
      if (novel == null) {
        _error = 'URLからの取得に失敗しました';
        _isLoading = false;
        notifyListeners();
        return null;
      }

      // Check if already exists
      final existing = await _db.getNovelByNcode(novel.ncode, novel.source);
      if (existing != null) {
        _error = 'この作品は既にライブラリに追加されています';
        _isLoading = false;
        notifyListeners();
        return existing;
      }

      final id = await _db.insertNovel(novel);
      await loadNovels();
      return novel.copyWith(id: id);
    } catch (e) {
      _error = 'エラー: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Download episodes of a novel (optionally within a range)
  Future<void> downloadEpisodes(Novel novel, {int start = 1, int? end}) async {
    if (novel.id == null) return;

    _downloadProgress = 0.0;
    _downloadStatus = 'エピソード一覧取得中...';
    notifyListeners();

    try {
      List<Map<String, String>> episodeList = [];
      
      // 1. Fetch episode list based on source
      if (novel.source == 'narou') {
        episodeList = await NovelScraper.fetchNarouEpisodeList(novel.ncode);
      } else if (novel.source == 'kakuyomu') {
        final workId = novel.ncode.replaceFirst('ky_', '');
        episodeList = await NovelScraper.fetchKakuyomuEpisodeList(workId);
      } else if (novel.source == 'hameln') {
        final novelId = novel.ncode.replaceFirst('hm_', '');
        episodeList = await NovelScraper.fetchHamelnEpisodeList(novelId);
      } else {
         _downloadStatus = '未対応のサイトです';
         notifyListeners();
         return;
      }

      if (episodeList.isEmpty) {
        _downloadStatus = 'エピソードが見つかりませんでした';
        notifyListeners();
        return;
      }

      final total = episodeList.length;
      final targetEnd = end ?? total;
      final targetCount = targetEnd - start + 1; // Range size
      int processed = 0;
      int downloadedVal = novel.downloadedEpisodes; // Track total downloaded

      // 2. Download each episode in range
      for (int i = 0; i < total; i++) {
        final epNum = i + 1;
        
        // Skip correctly
        if (epNum < start) continue;
        if (epNum > targetEnd) break;

        // Check availability
        final existing = await _db.getEpisode(novel.id!, epNum);
        if (existing != null) {
          processed++;
           _downloadProgress = processed / targetCount;
          _downloadStatus = '$epNum 話 (済) / $targetEnd';
          notifyListeners();
          continue;
        }

        Episode? episode;
        if (novel.source == 'narou') {
          episode = await NovelScraper.fetchNarouEpisode(novel.id!, novel.ncode, epNum);
        } else if (novel.source == 'kakuyomu') {
          episode = await NovelScraper.fetchKakuyomuEpisode(novel.id!, episodeList[i]['url']!, epNum);
        } else if (novel.source == 'hameln') {
          episode = await NovelScraper.fetchHamelnEpisode(novel.id!, episodeList[i]['url']!, epNum);
        }

        if (episode != null) {
          await _db.insertEpisode(episode);
          processed++;
          downloadedVal++; // Increment total count (approximate)
        }

        _downloadProgress = processed / targetCount;
        _downloadStatus = '$epNum / $targetEnd ダウンロード中...';
        notifyListeners();

        // Delay based on site to be polite
        final delay = novel.source == 'narou' ? 500 : 1000; 
        await Future.delayed(Duration(milliseconds: delay));
      }

      // 3. Update novel info (Recount actual downloaded for accuracy)
      // Getting strict count might be heavy, so we update basics
      // Or we can rely on a count query if DBService has one.
      // For now, let's just assume we added some.
      // Ideally, we should count actual records in DB.
      
      await _db.updateNovel(novel.copyWith(
        // downloadedEpisodes: downloadedVal, // Maybe inaccurate if we skipped? Let's leave it or implement DB count
        totalEpisodes: total,
        lastChecked: DateTime.now(),
      ));
      
      // Update real count from DB to be safe
      final realCount = (await _db.getEpisodes(novel.id!)).length;
       await _db.updateNovel(novel.copyWith(
        downloadedEpisodes: realCount,
        totalEpisodes: total,
        lastChecked: DateTime.now(),
      ));

      _downloadStatus = '指定範囲 ($start-$targetEnd) のダウンロード完了！';
      await loadNovels();
    } catch (e) {
      _downloadStatus = 'ダウンロードエラー: $e';
    }
    notifyListeners();
  }
  
  // Forward for backward compatibility if needed, or just use default params
  Future<void> downloadAllEpisodes(Novel novel) async {
    await downloadEpisodes(novel);
  }

  /// Delete all downloaded episodes for a novel
  Future<void> deleteNovelEpisodes(Novel novel) async {
    if (novel.id == null) return;
    await _db.deleteEpisodesByNovelId(novel.id!);
    await _db.updateNovel(novel.copyWith(downloadedEpisodes: 0));
    _downloadStatus = 'キャッシュを削除しました';
    notifyListeners();
    await loadNovels();
  }

  /// Add novel using URL (Alias)
  Future<Novel?> addNovel(String url) async {
    return await addNovelFromUrl(url);
  }
  
  /// Get novel by ID
  Future<Novel?> getNovel(int id) async {
    return await _db.getNovelById(id);
  }

  /// Get novel by Ncode and source
  Future<Novel?> getNovelByNcode(String ncode, String source) async {
    return await _db.getNovelByNcode(ncode, source);
  }

  /// Refresh novel metadata (title, totalEpisodes, etc.)
  Future<void> refreshNovelInfo(Novel novel) async {
    if (novel.id == null) return;
    
    try {
      final latest = await NovelScraper.fetchNovelFromUrl(novel.sourceUrl);
      if (latest != null) {
        // Merge latest info but keep local status
        final updated = novel.copyWith(
          title: latest.title,
          author: latest.author,
          synopsis: latest.synopsis,
          totalEpisodes: latest.totalEpisodes,
          totalCharacters: latest.totalCharacters,
          lastUpdated: latest.lastUpdated,
          lastChecked: DateTime.now(),
        );
        await _db.updateNovel(updated);
        notifyListeners();
      }
    } catch (e) {
      print('Refresh error: $e');
    }
  }

  // Cache for episode lists to avoid re-fetching index for every episode in non-sequential sources
  final Map<int, List<Map<String, String>>> _episodeListCache = {};

  /// Get episodes for a novel
  Future<List<Episode>> getEpisodes(int novelId) async {
    return await _db.getEpisodes(novelId);
  }

  /// Get a single episode (fetch from web if missing)
  Future<Episode?> getOrFetchEpisode(Novel novel, int episodeNumber, {bool saveToDb = false}) async {
    if (novel.id == null) return null;

    // 1. Try DB first
    final cached = await _db.getEpisode(novel.id!, episodeNumber);
    if (cached != null) return cached;

    // 2. Fetch from Web
    try {
      Episode? episode;
      if (novel.source == 'narou') {
        // Narou URL is predictable
        episode = await NovelScraper.fetchNarouEpisode(
            novel.id!, novel.ncode, episodeNumber);
      } else {
        // Others need episode list to find URL
        if (!_episodeListCache.containsKey(novel.id)) {
           List<Map<String, String>> list = [];
           if (novel.source == 'kakuyomu') {
             final workId = novel.ncode.replaceFirst('ky_', '');
             list = await NovelScraper.fetchKakuyomuEpisodeList(workId);
           } else if (novel.source == 'hameln') {
             final novelId = novel.ncode.replaceFirst('hm_', '');
             list = await NovelScraper.fetchHamelnEpisodeList(novelId);
           }
           if (list.isNotEmpty) {
             _episodeListCache[novel.id!] = list;
           }
        }
        
        final list = _episodeListCache[novel.id];
        if (list != null && episodeNumber <= list.length) {
          final url = list[episodeNumber - 1]['url'];
          if (url != null) {
             if (novel.source == 'kakuyomu') {
               episode = await NovelScraper.fetchKakuyomuEpisode(novel.id!, url, episodeNumber);
             } else if (novel.source == 'hameln') {
               episode = await NovelScraper.fetchHamelnEpisode(novel.id!, url, episodeNumber);
             }
          }
        }
      }

      // 3. Return episode (save only if requested)
      if (episode != null) {
        if (saveToDb) {
          await _db.insertEpisode(episode);
          
          // Update novel info silently (increment downloaded count)
          final current = await _db.getNovelById(novel.id!);
          if (current != null) {
             final realCount = (await _db.getEpisodes(novel.id!)).length;
             await _db.updateNovel(current.copyWith(
               downloadedEpisodes: realCount,
               lastChecked: DateTime.now(),
             ));
             
             if (episodeNumber > current.totalEpisodes) {
                await _db.updateNovel(current.copyWith(totalEpisodes: episodeNumber));
             }
          }
          notifyListeners();
        }
        return episode;
      }
    } catch (e) {
      print('Online fetch error: $e');
    }
    return null;
  }

  /// Get a specific episode
  Future<Episode?> getEpisode(int novelId, int episodeNumber) async {
    return await _db.getEpisode(novelId, episodeNumber);
  }

  /// Toggle favorite
  Future<void> toggleFavorite(Novel novel) async {
    final updated = novel.copyWith(isFavorite: !novel.isFavorite);
    await _db.updateNovel(updated);
    await loadNovels();
  }

  /// Update reading status
  Future<void> updateStatus(Novel novel, String status) async {
    await _db.updateNovel(novel.copyWith(status: status));
    await loadNovels();
  }

  /// Move to folder
  Future<void> moveToFolder(Novel novel, String folder) async {
    await _db.updateNovel(novel.copyWith(folder: folder));
    await loadNovels();
  }

  /// Delete a novel and its episodes
  Future<void> deleteNovel(int id) async {
    await _db.deleteNovel(id);
    await loadNovels();
  }

  /// Update bookmark position
  Future<void> updateBookmark(
      int novelId, int episodeNumber, double position) async {
    await _db.updateBookmark(novelId, episodeNumber, position);
    // Refresh novel data
    final idx = _novels.indexWhere((n) => n.id == novelId);
    if (idx >= 0) {
      _novels[idx] = _novels[idx].copyWith(
        lastReadEpisode: episodeNumber,
        lastReadPosition: position,
        lastReadAt: DateTime.now(),
      );
      _applyFilters();
      notifyListeners();
    }
  }
}
