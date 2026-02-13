/// Represents a novel/work from narou or other sites
class Novel {
  final int? id;
  final String ncode; // Unique novel code (e.g., n1234ab)
  final String title;
  final String author;
  final String synopsis;
  final String source; // 'narou', 'kakuyomu', 'hameln'
  final String sourceUrl;
  final int totalEpisodes;
  final int downloadedEpisodes;
  final int lastReadEpisode;
  final double lastReadPosition; // Pixel-level scroll position
  final String? coverImageUrl;
  final String? coverImagePath; // Local cached path
  final String tags; // Comma-separated
  final String folder; // User folder classification
  final String status; // 'reading', 'completed', 'on_hold', 'dropped', 'plan_to_read'
  final bool isFavorite;
  final int totalCharacters; // Total character count
  final int readCharacters; // Characters read
  final DateTime? lastUpdated; // Last server update
  final DateTime? lastChecked; // Last update check time
  final DateTime? lastReadAt;
  final DateTime createdAt;

  Novel({
    this.id,
    required this.ncode,
    required this.title,
    required this.author,
    this.synopsis = '',
    required this.source,
    required this.sourceUrl,
    this.totalEpisodes = 0,
    this.downloadedEpisodes = 0,
    this.lastReadEpisode = 0,
    this.lastReadPosition = 0.0,
    this.coverImageUrl,
    this.coverImagePath,
    this.tags = '',
    this.folder = 'default',
    this.status = 'plan_to_read',
    this.isFavorite = false,
    this.totalCharacters = 0,
    this.readCharacters = 0,
    this.lastUpdated,
    this.lastChecked,
    this.lastReadAt,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Novel copyWith({
    int? id,
    String? ncode,
    String? title,
    String? author,
    String? synopsis,
    String? source,
    String? sourceUrl,
    int? totalEpisodes,
    int? downloadedEpisodes,
    int? lastReadEpisode,
    double? lastReadPosition,
    String? coverImageUrl,
    String? coverImagePath,
    String? tags,
    String? folder,
    String? status,
    bool? isFavorite,
    int? totalCharacters,
    int? readCharacters,
    DateTime? lastUpdated,
    DateTime? lastChecked,
    DateTime? lastReadAt,
    DateTime? createdAt,
  }) {
    return Novel(
      id: id ?? this.id,
      ncode: ncode ?? this.ncode,
      title: title ?? this.title,
      author: author ?? this.author,
      synopsis: synopsis ?? this.synopsis,
      source: source ?? this.source,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      totalEpisodes: totalEpisodes ?? this.totalEpisodes,
      downloadedEpisodes: downloadedEpisodes ?? this.downloadedEpisodes,
      lastReadEpisode: lastReadEpisode ?? this.lastReadEpisode,
      lastReadPosition: lastReadPosition ?? this.lastReadPosition,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      coverImagePath: coverImagePath ?? this.coverImagePath,
      tags: tags ?? this.tags,
      folder: folder ?? this.folder,
      status: status ?? this.status,
      isFavorite: isFavorite ?? this.isFavorite,
      totalCharacters: totalCharacters ?? this.totalCharacters,
      readCharacters: readCharacters ?? this.readCharacters,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      lastChecked: lastChecked ?? this.lastChecked,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'ncode': ncode,
      'title': title,
      'author': author,
      'synopsis': synopsis,
      'source': source,
      'source_url': sourceUrl,
      'total_episodes': totalEpisodes,
      'downloaded_episodes': downloadedEpisodes,
      'last_read_episode': lastReadEpisode,
      'last_read_position': lastReadPosition,
      'cover_image_url': coverImageUrl,
      'cover_image_path': coverImagePath,
      'tags': tags,
      'folder': folder,
      'status': status,
      'is_favorite': isFavorite ? 1 : 0,
      'total_characters': totalCharacters,
      'read_characters': readCharacters,
      'last_updated': lastUpdated?.toIso8601String(),
      'last_checked': lastChecked?.toIso8601String(),
      'last_read_at': lastReadAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Novel.fromMap(Map<String, dynamic> map) {
    return Novel(
      id: map['id'] as int?,
      ncode: map['ncode'] as String,
      title: map['title'] as String,
      author: map['author'] as String,
      synopsis: map['synopsis'] as String? ?? '',
      source: map['source'] as String,
      sourceUrl: map['source_url'] as String,
      totalEpisodes: map['total_episodes'] as int? ?? 0,
      downloadedEpisodes: map['downloaded_episodes'] as int? ?? 0,
      lastReadEpisode: map['last_read_episode'] as int? ?? 0,
      lastReadPosition: (map['last_read_position'] as num?)?.toDouble() ?? 0.0,
      coverImageUrl: map['cover_image_url'] as String?,
      coverImagePath: map['cover_image_path'] as String?,
      tags: map['tags'] as String? ?? '',
      folder: map['folder'] as String? ?? 'default',
      status: map['status'] as String? ?? 'plan_to_read',
      isFavorite: (map['is_favorite'] as int?) == 1,
      totalCharacters: map['total_characters'] as int? ?? 0,
      readCharacters: map['read_characters'] as int? ?? 0,
      lastUpdated: map['last_updated'] != null
          ? DateTime.tryParse(map['last_updated'] as String)
          : null,
      lastChecked: map['last_checked'] != null
          ? DateTime.tryParse(map['last_checked'] as String)
          : null,
      lastReadAt: map['last_read_at'] != null
          ? DateTime.tryParse(map['last_read_at'] as String)
          : null,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  int get unreadEpisodes => totalEpisodes - lastReadEpisode;
  bool get hasUpdate =>
      lastUpdated != null &&
      (lastChecked == null || lastUpdated!.isAfter(lastChecked!));

  List<String> get tagList =>
      tags.isEmpty ? [] : tags.split(',').map((t) => t.trim()).toList();
}
