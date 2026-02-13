/// Represents a single episode/chapter of a novel
class Episode {
  final int? id;
  final int novelId;
  final int episodeNumber;
  final String title;
  final String body; // Main content
  final String? preface; // 前書き
  final String? afterword; // 後書き
  final int characterCount;
  final DateTime? publishedAt;
  final DateTime? updatedAt;
  final DateTime? downloadedAt;

  Episode({
    this.id,
    required this.novelId,
    required this.episodeNumber,
    required this.title,
    required this.body,
    this.preface,
    this.afterword,
    this.characterCount = 0,
    this.publishedAt,
    this.updatedAt,
    this.downloadedAt,
  });

  Episode copyWith({
    int? id,
    int? novelId,
    int? episodeNumber,
    String? title,
    String? body,
    String? preface,
    String? afterword,
    int? characterCount,
    DateTime? publishedAt,
    DateTime? updatedAt,
    DateTime? downloadedAt,
  }) {
    return Episode(
      id: id ?? this.id,
      novelId: novelId ?? this.novelId,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      title: title ?? this.title,
      body: body ?? this.body,
      preface: preface ?? this.preface,
      afterword: afterword ?? this.afterword,
      characterCount: characterCount ?? this.characterCount,
      publishedAt: publishedAt ?? this.publishedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      downloadedAt: downloadedAt ?? this.downloadedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'novel_id': novelId,
      'episode_number': episodeNumber,
      'title': title,
      'body': body,
      'preface': preface,
      'afterword': afterword,
      'character_count': characterCount,
      'published_at': publishedAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'downloaded_at': downloadedAt?.toIso8601String(),
    };
  }

  factory Episode.fromMap(Map<String, dynamic> map) {
    return Episode(
      id: map['id'] as int?,
      novelId: map['novel_id'] as int,
      episodeNumber: map['episode_number'] as int,
      title: map['title'] as String,
      body: map['body'] as String,
      preface: map['preface'] as String?,
      afterword: map['afterword'] as String?,
      characterCount: map['character_count'] as int? ?? 0,
      publishedAt: map['published_at'] != null
          ? DateTime.tryParse(map['published_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String)
          : null,
      downloadedAt: map['downloaded_at'] != null
          ? DateTime.tryParse(map['downloaded_at'] as String)
          : null,
    );
  }
}
