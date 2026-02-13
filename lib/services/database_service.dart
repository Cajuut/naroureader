import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/novel.dart';
import '../models/episode.dart';
import '../models/reading_record.dart';

class DatabaseService {
  static Database? _database;

  Future<void> initialize() async {
    if (_database != null) return;
    
    // Use FFI for Desktop (Windows/Linux)
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    
    // For mobile (iOS/Android), uses standard sqflite automatically
    final dir = await getApplicationDocumentsDirectory();
    // On iOS/Android, getDatabasesPath() is usually preferred, but getApplicationDocumentsDirectory works too.
    // However, for consistency with path_provider, let's stick to the current logic but maybe use getDatabasesPath() for mobile if preferred.
    // Actually, relying on getApplicationDocumentsDirectory is fine and keeps logic shared.
    
    final dbPath = p.join(dir.path, 'narou_reader', 'library.db');
    
    // Ensure directory exists
    final dbDir = Directory(p.dirname(dbPath));
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }

    _database = await openDatabase(
      dbPath,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Database get db {
    if (_database == null) throw Exception('Database not initialized');
    return _database!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE novels (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ncode TEXT NOT NULL,
        title TEXT NOT NULL,
        author TEXT NOT NULL,
        synopsis TEXT DEFAULT '',
        source TEXT NOT NULL,
        source_url TEXT NOT NULL,
        total_episodes INTEGER DEFAULT 0,
        downloaded_episodes INTEGER DEFAULT 0,
        last_read_episode INTEGER DEFAULT 0,
        last_read_position REAL DEFAULT 0.0,
        cover_image_url TEXT,
        cover_image_path TEXT,
        tags TEXT DEFAULT '',
        folder TEXT DEFAULT 'default',
        status TEXT DEFAULT 'plan_to_read',
        is_favorite INTEGER DEFAULT 0,
        total_characters INTEGER DEFAULT 0,
        read_characters INTEGER DEFAULT 0,
        last_updated TEXT,
        last_checked TEXT,
        last_read_at TEXT,
        created_at TEXT NOT NULL,
        UNIQUE(ncode, source)
      )
    ''');

    await db.execute('''
      CREATE TABLE episodes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        novel_id INTEGER NOT NULL,
        episode_number INTEGER NOT NULL,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        preface TEXT,
        afterword TEXT,
        character_count INTEGER DEFAULT 0,
        published_at TEXT,
        updated_at TEXT,
        downloaded_at TEXT,
        FOREIGN KEY (novel_id) REFERENCES novels(id) ON DELETE CASCADE,
        UNIQUE(novel_id, episode_number)
      )
    ''');

    await db.execute('''
      CREATE TABLE reading_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        novel_id INTEGER NOT NULL,
        episode_number INTEGER NOT NULL,
        characters_read INTEGER DEFAULT 0,
        reading_time_seconds INTEGER DEFAULT 0,
        read_at TEXT NOT NULL,
        FOREIGN KEY (novel_id) REFERENCES novels(id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
        'CREATE INDEX idx_episodes_novel ON episodes(novel_id, episode_number)');
    await db.execute(
        'CREATE INDEX idx_records_novel ON reading_records(novel_id)');
    await db.execute(
        'CREATE INDEX idx_records_date ON reading_records(read_at)');
  }

  // ── Novel CRUD ──────────────────────────────────────

  Future<int> insertNovel(Novel novel) async {
    return await db.insert('novels', novel.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateNovel(Novel novel) async {
    await db
        .update('novels', novel.toMap(), where: 'id = ?', whereArgs: [novel.id]);
  }

  Future<void> deleteNovel(int id) async {
    await db.delete('novels', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Novel>> getAllNovels() async {
    final maps = await db.query('novels', orderBy: 'last_read_at DESC');
    return maps.map((m) => Novel.fromMap(m)).toList();
  }

  Future<List<Novel>> getNovelsByFolder(String folder) async {
    final maps = await db
        .query('novels', where: 'folder = ?', whereArgs: [folder], orderBy: 'last_read_at DESC');
    return maps.map((m) => Novel.fromMap(m)).toList();
  }

  Future<List<Novel>> getFavorites() async {
    final maps = await db.query('novels',
        where: 'is_favorite = 1', orderBy: 'last_read_at DESC');
    return maps.map((m) => Novel.fromMap(m)).toList();
  }

  Future<Novel?> getNovelByNcode(String ncode, String source) async {
    final maps = await db.query('novels',
        where: 'ncode = ? AND source = ?', whereArgs: [ncode, source]);
    if (maps.isEmpty) return null;
    return Novel.fromMap(maps.first);
  }

  Future<Novel?> getNovelById(int id) async {
    final maps = await db.query('novels', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Novel.fromMap(maps.first);
  }

  Future<List<String>> getAllFolders() async {
    final maps = await db.rawQuery('SELECT DISTINCT folder FROM novels ORDER BY folder');
    return maps.map((m) => m['folder'] as String).toList();
  }

  // ── Episode CRUD ────────────────────────────────────

  Future<int> insertEpisode(Episode episode) async {
    return await db.insert('episodes', episode.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertEpisodes(List<Episode> episodes) async {
    final batch = db.batch();
    for (final ep in episodes) {
      batch.insert('episodes', ep.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> deleteEpisodesByNovelId(int novelId) async {
    await db.delete('episodes', where: 'novel_id = ?', whereArgs: [novelId]);
  }

  Future<List<Episode>> getEpisodes(int novelId) async {
    final maps = await db.query('episodes',
        where: 'novel_id = ?',
        whereArgs: [novelId],
        orderBy: 'episode_number ASC');
    return maps.map((m) => Episode.fromMap(m)).toList();
  }

  Future<Episode?> getEpisode(int novelId, int episodeNumber) async {
    final maps = await db.query('episodes',
        where: 'novel_id = ? AND episode_number = ?',
        whereArgs: [novelId, episodeNumber]);
    if (maps.isEmpty) return null;
    return Episode.fromMap(maps.first);
  }

  Future<int> getDownloadedEpisodeCount(int novelId) async {
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM episodes WHERE novel_id = ?',
      [novelId],
    );
    return result.first['cnt'] as int;
  }

  // ── Reading Records ─────────────────────────────────

  Future<void> insertReadingRecord(ReadingRecord record) async {
    await db.insert('reading_records', record.toMap());
  }

  Future<int> getTotalCharactersRead() async {
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(characters_read), 0) as total FROM reading_records',
    );
    return result.first['total'] as int;
  }

  Future<int> getTotalReadingTimeSeconds() async {
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(reading_time_seconds), 0) as total FROM reading_records',
    );
    return result.first['total'] as int;
  }

  Future<List<Map<String, dynamic>>> getDailyStats(int days) async {
    final since =
        DateTime.now().subtract(Duration(days: days)).toIso8601String();
    return await db.rawQuery('''
      SELECT 
        DATE(read_at) as date,
        SUM(characters_read) as characters,
        SUM(reading_time_seconds) as seconds
      FROM reading_records
      WHERE read_at >= ?
      GROUP BY DATE(read_at)
      ORDER BY date ASC
    ''', [since]);
  }

  Future<List<Map<String, dynamic>>> getTopAuthors({int limit = 10}) async {
    return await db.rawQuery('''
      SELECT 
        n.author,
        SUM(r.characters_read) as total_characters,
        COUNT(DISTINCT n.id) as novel_count
      FROM reading_records r
      JOIN novels n ON n.id = r.novel_id
      GROUP BY n.author
      ORDER BY total_characters DESC
      LIMIT ?
    ''', [limit]);
  }

  // ── Bookmark (update reading position) ──────────────

  Future<void> updateBookmark(
      int novelId, int episodeNumber, double position) async {
    await db.update(
      'novels',
      {
        'last_read_episode': episodeNumber,
        'last_read_position': position,
        'last_read_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [novelId],
    );
  }

  // ── Search ──────────────────────────────────────────

  Future<List<Novel>> searchNovels(String query) async {
    final maps = await db.query('novels',
        where: 'title LIKE ? OR author LIKE ? OR tags LIKE ?',
        whereArgs: ['%$query%', '%$query%', '%$query%'],
        orderBy: 'last_read_at DESC');
    return maps.map((m) => Novel.fromMap(m)).toList();
  }

  // ── Export / Import ─────────────────────────────────

  Future<Map<String, dynamic>> exportData() async {
    final novels = await db.query('novels');
    final episodes = await db.query('episodes');
    final records = await db.query('reading_records');
    return {
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'novels': novels,
      'episodes': episodes,
      'reading_records': records,
    };
  }
}
