import 'package:flutter/material.dart';
import '../services/database_service.dart';

class ReadingStatsProvider extends ChangeNotifier {
  final DatabaseService _db;
  int _totalCharacters = 0;
  int _totalReadingTimeSeconds = 0;
  List<Map<String, dynamic>> _dailyStats = [];
  List<Map<String, dynamic>> _topAuthors = [];
  bool _isLoading = false;

  ReadingStatsProvider(this._db) {
    loadStats();
  }

  int get totalCharacters => _totalCharacters;
  int get totalReadingTimeSeconds => _totalReadingTimeSeconds;
  List<Map<String, dynamic>> get dailyStats => _dailyStats;
  List<Map<String, dynamic>> get topAuthors => _topAuthors;
  bool get isLoading => _isLoading;

  String get formattedTotalCharacters {
    if (_totalCharacters >= 10000000) {
      return '${(_totalCharacters / 10000000).toStringAsFixed(1)}千万字';
    } else if (_totalCharacters >= 10000) {
      return '${(_totalCharacters / 10000).toStringAsFixed(1)}万字';
    }
    return '$_totalCharacters字';
  }

  String get formattedTotalTime {
    final hours = _totalReadingTimeSeconds ~/ 3600;
    final minutes = (_totalReadingTimeSeconds % 3600) ~/ 60;
    if (hours > 0) {
      return '$hours時間$minutes分';
    }
    return '$minutes分';
  }

  Future<void> loadStats() async {
    _isLoading = true;
    notifyListeners();

    try {
      _totalCharacters = await _db.getTotalCharactersRead();
      _totalReadingTimeSeconds = await _db.getTotalReadingTimeSeconds();
      _dailyStats = await _db.getDailyStats(30);
      _topAuthors = await _db.getTopAuthors(limit: 10);
    } catch (e) {
      // Silently handle errors
    }

    _isLoading = false;
    notifyListeners();
  }
}
