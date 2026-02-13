/// Reading statistics record
class ReadingRecord {
  final int? id;
  final int novelId;
  final int episodeNumber;
  final int charactersRead;
  final int readingTimeSeconds;
  final DateTime readAt;

  ReadingRecord({
    this.id,
    required this.novelId,
    required this.episodeNumber,
    required this.charactersRead,
    required this.readingTimeSeconds,
    DateTime? readAt,
  }) : readAt = readAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'novel_id': novelId,
      'episode_number': episodeNumber,
      'characters_read': charactersRead,
      'reading_time_seconds': readingTimeSeconds,
      'read_at': readAt.toIso8601String(),
    };
  }

  factory ReadingRecord.fromMap(Map<String, dynamic> map) {
    return ReadingRecord(
      id: map['id'] as int?,
      novelId: map['novel_id'] as int,
      episodeNumber: map['episode_number'] as int,
      charactersRead: map['characters_read'] as int,
      readingTimeSeconds: map['reading_time_seconds'] as int,
      readAt: DateTime.tryParse(map['read_at'] as String) ?? DateTime.now(),
    );
  }
}
