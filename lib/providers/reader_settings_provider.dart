import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

class ReaderSettingsProvider extends ChangeNotifier {
  // Text settings
  double _fontSize = 18.0;
  double _lineHeight = 1.8;
  double _letterSpacing = 0.5;
  double _paragraphSpacing = 16.0;
  double _horizontalPadding = 24.0;
  double _verticalPadding = 16.0;
  String _fontFamily = 'Default';
  String? _customFontPath;
  bool _isVerticalWriting = false;

  // Color settings
  Color _textColor = const Color(0xFFE8E6E3);
  Color _backgroundColor = const Color(0xFF0F1318);
  bool _useBgImage = false;
  String? _bgImagePath;

  // Feature toggles
  bool _showPreface = true;
  bool _showAfterword = true;
  bool _showRuby = true;
  bool _immersiveMode = false;

  // View Settings
  String _viewMode = 'scroll'; // 'scroll', 'page'

  // Getters

  String get viewMode => _viewMode;

  // Setters
  // ...
  void setViewMode(String v) { _viewMode = v; _save(); notifyListeners(); }

  // ...




  bool _autoScrollEnabled = false;
  double _autoScrollSpeed = 30.0; // pixels per second
  bool _densityBasedSpeed = true;
  double _minScrollSpeed = 15.0;
  double _maxScrollSpeed = 80.0;
  
  // Preset themes
  static const Map<String, Map<String, Color>> colorPresets = {
    'midnight': {
      'bg': Color(0xFF0F1318),
      'text': Color(0xFFE8E6E3),
    },
    'sepia': {
      'bg': Color(0xFFF4EADB),
      'text': Color(0xFF433422),
    },
    'paper': {
      'bg': Color(0xFFFFFFF0),
      'text': Color(0xFF2A2A2A),
    },
    'amoled': {
      'bg': Color(0xFF000000),
      'text': Color(0xFFCCCCCC),
    },
    'forest': {
      'bg': Color(0xFF0D1F0D),
      'text': Color(0xFFC8E6C8),
    },
    'ocean': {
      'bg': Color(0xFF0A1628),
      'text': Color(0xFFB0C4DE),
    },
  };

  ReaderSettingsProvider() {
    _loadSettings();
  }

  // Getters
  double get fontSize => _fontSize;
  double get lineHeight => _lineHeight;
  double get letterSpacing => _letterSpacing;
  double get paragraphSpacing => _paragraphSpacing;
  double get horizontalPadding => _horizontalPadding;
  double get verticalPadding => _verticalPadding;
  String get fontFamily => _fontFamily;
  String? get customFontPath => _customFontPath;
  bool get isVerticalWriting => _isVerticalWriting;
  Color get textColor => _textColor;
  Color get backgroundColor => _backgroundColor;
  bool get useBgImage => _useBgImage;
  String? get bgImagePath => _bgImagePath;
  bool get showPreface => _showPreface;
  bool get showAfterword => _showAfterword;
  bool get showRuby => _showRuby;
  bool get immersiveMode => _immersiveMode;
  bool get autoScrollEnabled => _autoScrollEnabled;
  double get autoScrollSpeed => _autoScrollSpeed;
  bool get densityBasedSpeed => _densityBasedSpeed;
  double get minScrollSpeed => _minScrollSpeed;
  double get maxScrollSpeed => _maxScrollSpeed;

  // Setters with persistence
  void setFontSize(double v) { _fontSize = v.clamp(8.0, 48.0); _save(); notifyListeners(); }
  void setLineHeight(double v) { _lineHeight = v.clamp(1.0, 3.5); _save(); notifyListeners(); }
  void setLetterSpacing(double v) { _letterSpacing = v.clamp(-2.0, 10.0); _save(); notifyListeners(); }
  void setParagraphSpacing(double v) { _paragraphSpacing = v.clamp(0.0, 60.0); _save(); notifyListeners(); }
  void setHorizontalPadding(double v) { _horizontalPadding = v.clamp(0.0, 80.0); _save(); notifyListeners(); }
  void setVerticalPadding(double v) { _verticalPadding = v.clamp(0.0, 80.0); _save(); notifyListeners(); }
  void setFontFamily(String v) { _fontFamily = v; _save(); notifyListeners(); }
  void setCustomFontPath(String? v) { _customFontPath = v; _save(); notifyListeners(); }
  void setVerticalWriting(bool v) { _isVerticalWriting = v; _save(); notifyListeners(); }
  void setTextColor(Color v) { _textColor = v; _save(); notifyListeners(); }
  void setBackgroundColor(Color v) { _backgroundColor = v; _save(); notifyListeners(); }
  void setUseBgImage(bool v) { _useBgImage = v; _save(); notifyListeners(); }
  void setBgImagePath(String? v) { _bgImagePath = v; _save(); notifyListeners(); }
  void setShowPreface(bool v) { _showPreface = v; _save(); notifyListeners(); }
  void setShowAfterword(bool v) { _showAfterword = v; _save(); notifyListeners(); }
  void setShowRuby(bool v) { _showRuby = v; _save(); notifyListeners(); }
  void setImmersiveMode(bool v) { _immersiveMode = v; _save(); notifyListeners(); }
  void setAutoScrollEnabled(bool v) { _autoScrollEnabled = v; notifyListeners(); }
  void setAutoScrollSpeed(double v) { _autoScrollSpeed = v.clamp(5.0, 200.0); _save(); notifyListeners(); }
  void setDensityBasedSpeed(bool v) { _densityBasedSpeed = v; _save(); notifyListeners(); }

  /// Apply a color preset
  void applyPreset(String presetName) {
    final preset = colorPresets[presetName];
    if (preset != null) {
      _backgroundColor = preset['bg']!;
      _textColor = preset['text']!;
      _save();
      notifyListeners();
    }
  }

  /// Adjust auto-scroll speed based on text density
  double calculateDensitySpeed(String text) {
    if (!_densityBasedSpeed) return _autoScrollSpeed;

    // Calculate dialogue ratio (lines starting with 「)
    final lines = text.split('\n');
    final dialogueLines = lines.where((l) => l.trimLeft().startsWith('「') || l.trimLeft().startsWith('『')).length;
    final dialogueRatio = lines.isEmpty ? 0.0 : dialogueLines / lines.length;

    // More dialogue = faster speed (easier to read)
    final speedMultiplier = 1.0 + (dialogueRatio * 0.5);
    return (_autoScrollSpeed * speedMultiplier).clamp(_minScrollSpeed, _maxScrollSpeed);
  }

  /// Increment scroll speed by a small step
  void incrementSpeed() {
    _autoScrollSpeed = (_autoScrollSpeed + 2.0).clamp(5.0, 200.0);
    notifyListeners();
  }

  /// Decrement scroll speed by a small step
  void decrementSpeed() {
    _autoScrollSpeed = (_autoScrollSpeed - 2.0).clamp(5.0, 200.0);
    notifyListeners();
  }

  // ── Export / Import settings as JSON ────────────────

  Map<String, dynamic> toJson() {
    return {
      'version': 1,
      'fontSize': _fontSize,
      'lineHeight': _lineHeight,
      'letterSpacing': _letterSpacing,
      'paragraphSpacing': _paragraphSpacing,
      'horizontalPadding': _horizontalPadding,
      'verticalPadding': _verticalPadding,
      'fontFamily': _fontFamily,
      'isVerticalWriting': _isVerticalWriting,
      'textColor': _textColor.value,
      'backgroundColor': _backgroundColor.value,
      'showPreface': _showPreface,
      'showAfterword': _showAfterword,
      'showRuby': _showRuby,
      'autoScrollSpeed': _autoScrollSpeed,
      'autoScrollSpeed': _autoScrollSpeed,
      'densityBasedSpeed': _densityBasedSpeed,
      'viewMode': _viewMode,
    };
  }

  void loadFromJson(Map<String, dynamic> json) {
    _fontSize = (json['fontSize'] as num?)?.toDouble() ?? _fontSize;
    _lineHeight = (json['lineHeight'] as num?)?.toDouble() ?? _lineHeight;
    _letterSpacing = (json['letterSpacing'] as num?)?.toDouble() ?? _letterSpacing;
    _paragraphSpacing = (json['paragraphSpacing'] as num?)?.toDouble() ?? _paragraphSpacing;
    _horizontalPadding = (json['horizontalPadding'] as num?)?.toDouble() ?? _horizontalPadding;
    _verticalPadding = (json['verticalPadding'] as num?)?.toDouble() ?? _verticalPadding;
    _fontFamily = json['fontFamily'] as String? ?? _fontFamily;
    _isVerticalWriting = json['isVerticalWriting'] as bool? ?? _isVerticalWriting;
    if (json['textColor'] != null) _textColor = Color(json['textColor'] as int);
    if (json['backgroundColor'] != null) _backgroundColor = Color(json['backgroundColor'] as int);
    _showPreface = json['showPreface'] as bool? ?? _showPreface;
    _showAfterword = json['showAfterword'] as bool? ?? _showAfterword;
    _showRuby = json['showRuby'] as bool? ?? _showRuby;
    _autoScrollSpeed = (json['autoScrollSpeed'] as num?)?.toDouble() ?? _autoScrollSpeed;
    _densityBasedSpeed = json['densityBasedSpeed'] as bool? ?? _densityBasedSpeed;
    _viewMode = json['viewMode'] as String? ?? _viewMode;
    _save();
    notifyListeners();
  }

  Future<String> exportToFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/narou_reader/settings_export.json');
    await file.parent.create(recursive: true);
    final jsonStr = const JsonEncoder.withIndent('  ').convert(toJson());
    await file.writeAsString(jsonStr);
    return file.path;
  }

  Future<bool> importFromFile(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return false;
      final jsonStr = await file.readAsString();
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      loadFromJson(json);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ── Persistence via SharedPreferences ───────────────

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _fontSize = prefs.getDouble('fontSize') ?? _fontSize;
    _lineHeight = prefs.getDouble('lineHeight') ?? _lineHeight;
    _letterSpacing = prefs.getDouble('letterSpacing') ?? _letterSpacing;
    _paragraphSpacing = prefs.getDouble('paragraphSpacing') ?? _paragraphSpacing;
    _horizontalPadding = prefs.getDouble('horizontalPadding') ?? _horizontalPadding;
    _verticalPadding = prefs.getDouble('verticalPadding') ?? _verticalPadding;
    _fontFamily = prefs.getString('fontFamily') ?? _fontFamily;
    _customFontPath = prefs.getString('customFontPath');
    _isVerticalWriting = prefs.getBool('isVerticalWriting') ?? _isVerticalWriting;
    final textColorVal = prefs.getInt('textColor');
    if (textColorVal != null) _textColor = Color(textColorVal);
    final bgColorVal = prefs.getInt('backgroundColor');
    if (bgColorVal != null) _backgroundColor = Color(bgColorVal);
    _showPreface = prefs.getBool('showPreface') ?? _showPreface;
    _showAfterword = prefs.getBool('showAfterword') ?? _showAfterword;
    _showRuby = prefs.getBool('showRuby') ?? _showRuby;
    _autoScrollSpeed = prefs.getDouble('autoScrollSpeed') ?? _autoScrollSpeed;
    _densityBasedSpeed = prefs.getBool('densityBasedSpeed') ?? _densityBasedSpeed;
    _viewMode = prefs.getString('viewMode') ?? 'scroll';
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('fontSize', _fontSize);
    await prefs.setDouble('lineHeight', _lineHeight);
    await prefs.setDouble('letterSpacing', _letterSpacing);
    await prefs.setDouble('paragraphSpacing', _paragraphSpacing);
    await prefs.setDouble('horizontalPadding', _horizontalPadding);
    await prefs.setDouble('verticalPadding', _verticalPadding);
    await prefs.setString('fontFamily', _fontFamily);
    if (_customFontPath != null) await prefs.setString('customFontPath', _customFontPath!);
    await prefs.setBool('isVerticalWriting', _isVerticalWriting);
    await prefs.setInt('textColor', _textColor.value);
    await prefs.setInt('backgroundColor', _backgroundColor.value);
    await prefs.setBool('showPreface', _showPreface);
    await prefs.setBool('showAfterword', _showAfterword);
    await prefs.setBool('showRuby', _showRuby);
    await prefs.setDouble('autoScrollSpeed', _autoScrollSpeed);
    await prefs.setBool('densityBasedSpeed', _densityBasedSpeed);
    await prefs.setString('viewMode', _viewMode);
  }
}
