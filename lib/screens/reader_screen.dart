import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/novel.dart';
import '../models/episode.dart';
import '../models/reading_record.dart';
import '../providers/library_provider.dart';
import '../providers/reader_settings_provider.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import 'dart:io';
import '../utils/paginator.dart';
import '../widgets/vertical_text_viewer.dart';

class ReaderScreen extends StatefulWidget {
  final Novel novel;
  final int startEpisode;

  const ReaderScreen({
    super.key,
    required this.novel,
    required this.startEpisode,
  });

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> with TickerProviderStateMixin {
  Episode? _currentEpisode;
  int _currentEpisodeNumber = 1;
  bool _isLoading = true;
  bool _showUI = true;
  bool _showSettings = false;

  // Auto-scroll
  Timer? _autoScrollTimer;
  bool _isAutoScrolling = false;
  double _currentScrollSpeed = 30.0;

  // Scroll & bookmark
  final ScrollController _scrollController = ScrollController();
  Timer? _bookmarkTimer;
  DateTime _readingStartTime = DateTime.now();
  
  // Pagination
  final PageController _pageController = PageController();
  List<String> _textPages = [];
  int _currentPageIndex = 0;
  bool _isPaginating = false;
  
  // Cache for pagination
  String? _lastPaginateText;
  Size? _lastPaginateSize;
  TextStyle? _lastPaginateStyle;

  // Animation
  late AnimationController _uiAnimController;
  late Animation<double> _uiAnimation;

  // Focus for keyboard events
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _currentEpisodeNumber = widget.startEpisode;

    _uiAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _uiAnimation = CurvedAnimation(
      parent: _uiAnimController,
      curve: Curves.easeOutCubic,
    );
    _uiAnimController.value = 1.0;

    _loadEpisode();

    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _bookmarkTimer?.cancel();
    _scrollController.dispose();
    _pageController.dispose();
    _uiAnimController.dispose();
    _focusNode.dispose();
    _saveBookmark();
    _saveReadingRecord();
    super.dispose();
  }

  Future<void> _loadEpisode() async {
    setState(() => _isLoading = true);
    final lib = context.read<LibraryProvider>();
    // Try to fetch online if not in DB
    final episode =
        await lib.getOrFetchEpisode(widget.novel, _currentEpisodeNumber);
    setState(() {
      _currentEpisode = episode;
      _isLoading = false;
    });

    // Restore scroll position if this is the bookmarked episode
    if (_currentEpisodeNumber == widget.novel.lastReadEpisode &&
        widget.novel.lastReadPosition > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(widget.novel.lastReadPosition.clamp(
            0.0,
            _scrollController.position.maxScrollExtent,
          ));
        }
      });
    }

    _readingStartTime = DateTime.now();
  }

  void _onScroll() {
    // Debounced bookmark save
    _bookmarkTimer?.cancel();
    _bookmarkTimer = Timer(const Duration(seconds: 2), () {
      _saveBookmark();
    });
  }

  Future<void> _saveBookmark() async {
    if (!mounted || !_scrollController.hasClients) return;
    final lib = context.read<LibraryProvider>();
    await lib.updateBookmark(
      widget.novel.id!,
      _currentEpisodeNumber,
      _scrollController.offset,
    );
  }

  Future<void> _saveReadingRecord() async {
    if (_currentEpisode == null || !mounted) return;
    final elapsed = DateTime.now().difference(_readingStartTime).inSeconds;
    if (elapsed < 5) return; // Don't save very short sessions

    final db = DatabaseService();
    await db.insertReadingRecord(ReadingRecord(
      novelId: widget.novel.id!,
      episodeNumber: _currentEpisodeNumber,
      charactersRead: _currentEpisode!.characterCount,
      readingTimeSeconds: elapsed,
    ));
  }

  void _toggleUI() {
    setState(() {
      _showUI = !_showUI;
      if (_showUI) {
        _uiAnimController.forward();
      } else {
        _uiAnimController.reverse();
        _showSettings = false;
      }
    });
  }

  void _toggleAutoScroll() {
    setState(() => _isAutoScrolling = !_isAutoScrolling);
    if (_isAutoScrolling) {
      _startAutoScroll();
    } else {
      _autoScrollTimer?.cancel();
    }
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    final settings = context.read<ReaderSettingsProvider>();

    // Calculate speed based on text density if enabled
    _currentScrollSpeed = _currentEpisode != null
        ? settings.calculateDensitySpeed(_currentEpisode!.body)
        : settings.autoScrollSpeed;

    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!_scrollController.hasClients) return;

      final newOffset =
          _scrollController.offset + (_currentScrollSpeed / 60.0);
      if (newOffset >= _scrollController.position.maxScrollExtent) {
        // Reached end — auto-advance to next episode
        _autoScrollTimer?.cancel();
        _nextEpisode();
        return;
      }
      _scrollController.jumpTo(newOffset);
    });
  }

  void _nextEpisode() async {
    await _saveReadingRecord();
    if (_currentEpisodeNumber < widget.novel.totalEpisodes) {
      setState(() => _currentEpisodeNumber++);
      await _loadEpisode();
      if (_isAutoScrolling) _startAutoScroll();
    }
  }

  void _prevEpisode() async {
    await _saveReadingRecord();
    if (_currentEpisodeNumber > 1) {
      setState(() => _currentEpisodeNumber--);
      await _loadEpisode();
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;

    final settings = context.read<ReaderSettingsProvider>();

    switch (event.logicalKey) {
      // Volume keys / Arrow keys for scrolling
      case LogicalKeyboardKey.arrowDown:
      case LogicalKeyboardKey.audioVolumeDown:
        _scrollController.animateTo(
          _scrollController.offset + 300,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
        break;
      case LogicalKeyboardKey.arrowUp:
      case LogicalKeyboardKey.audioVolumeUp:
        _scrollController.animateTo(
          (_scrollController.offset - 300).clamp(0.0, double.infinity),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
        break;
      case LogicalKeyboardKey.arrowRight:
      case LogicalKeyboardKey.pageDown:
        _nextEpisode();
        break;
      case LogicalKeyboardKey.arrowLeft:
      case LogicalKeyboardKey.pageUp:
        _prevEpisode();
        break;
      case LogicalKeyboardKey.space:
        _toggleAutoScroll();
        break;
      case LogicalKeyboardKey.escape:
        Navigator.pop(context);
        break;
      case LogicalKeyboardKey.bracketRight:
        settings.incrementSpeed();
        if (_isAutoScrolling) _startAutoScroll();
        break;
      case LogicalKeyboardKey.bracketLeft:
        settings.decrementSpeed();
        if (_isAutoScrolling) _startAutoScroll();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<ReaderSettingsProvider>();

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: settings.backgroundColor,
        body: Stack(
          children: [
            // Background Image Support
            if (settings.useBgImage && settings.bgImagePath != null)
               Positioned.fill(
                 child: Image.file(
                   File(settings.bgImagePath!),
                   fit: BoxFit.cover,
                   color: Colors.black.withOpacity(0.7), // overlay
                   colorBlendMode: BlendMode.darken,
                 ),
               ),

            // Main Content
            SafeArea(
              child: settings.viewMode == 'page'
                  ? _buildPageView(settings)
                  : _buildScrollView(settings),
            ),

            // Top bar
            if (_showUI)
              FadeTransition(
                opacity: _uiAnimation,
                child: _buildTopBar(),
              ),

            // Bottom bar
            if (_showUI)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: FadeTransition(
                  opacity: _uiAnimation,
                  child: _buildBottomBar(settings),
                ),
              ),

            // Auto-scroll indicator
            if (_isAutoScrolling)
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                right: 8,
                child: _buildScrollSpeedIndicator(settings),
              ),

            // Settings panel background overlay
            if (_showSettings)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => _showSettings = false),
                  child: Container(color: Colors.black38),
                ),
              ),
            // Settings panel
            if (_showSettings)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildSettingsPanel(settings),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageView(ReaderSettingsProvider settings) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Check if we need to paginate
    if (!_isPaginating) {
       // We can't paginate during build, so schedule it.
       // But we need context and size.
       // Use LayoutBuilder to get exact size available for text
       return LayoutBuilder(
         builder: (context, constraints) {
           // We need to paginate if content changed or size changed
           final size = Size(constraints.maxWidth, constraints.maxHeight);
           final style = _getTextStyle(settings);
           final fullText = _combineText(settings);

           if (fullText != _lastPaginateText || size != _lastPaginateSize || style != _lastPaginateStyle) {
             // Schedule pagination
             WidgetsBinding.instance.addPostFrameCallback((_) {
               _runPagination(fullText, style, size, settings);
             });
             return const Center(child: CircularProgressIndicator());
           }

           if (_textPages.isEmpty) {
              return const Center(child: Text("ページを作成中..."));
           }

           return Stack(
             children: [
               // PageView — handles swipe gestures directly
               PageView.builder(
                 controller: _pageController,
                 itemCount: _textPages.length,
                 reverse: settings.isVerticalWriting,
                 onPageChanged: (idx) {
                   setState(() => _currentPageIndex = idx);
                 },
                 itemBuilder: (context, index) {
                   final contentWidth = size.width - settings.horizontalPadding * 2;
                   final contentHeight = size.height - settings.verticalPadding * 2;

                   if (settings.isVerticalWriting) {
                     return Center(
                       child: VerticalTextViewer(
                         text: _textPages[index],
                         style: style,
                         width: contentWidth > 0 ? contentWidth : 0,
                         height: contentHeight > 0 ? contentHeight : 0,
                       ),
                     );
                   }
                   return Container(
                     width: double.infinity,
                     height: double.infinity,
                     padding: EdgeInsets.symmetric(
                       horizontal: settings.horizontalPadding,
                       vertical: settings.verticalPadding,
                     ),
                     child: Text(
                       _textPages[index],
                       style: style,
                     ),
                   );
                 },
               ),

               // Tap zones overlay (doesn't block swipes)
               Positioned.fill(
                 child: Row(
                   children: [
                     // Left zone — previous page
                     Expanded(
                       flex: 1,
                       child: GestureDetector(
                         behavior: HitTestBehavior.translucent,
                         onTap: () {
                           if (_pageController.hasClients && _currentPageIndex > 0) {
                             _pageController.previousPage(
                               duration: const Duration(milliseconds: 300),
                               curve: Curves.easeInOut,
                             );
                           }
                         },
                         child: const SizedBox.expand(),
                       ),
                     ),
                     // Center zone — toggle UI
                     Expanded(
                       flex: 2,
                       child: GestureDetector(
                         behavior: HitTestBehavior.translucent,
                         onTap: () {
                           setState(() {
                             _showUI = !_showUI;
                             if (_showUI) {
                               _uiAnimController.forward();
                             } else {
                               _uiAnimController.reverse();
                             }
                           });
                         },
                         child: const SizedBox.expand(),
                       ),
                     ),
                     // Right zone — next page
                     Expanded(
                       flex: 1,
                       child: GestureDetector(
                         behavior: HitTestBehavior.translucent,
                         onTap: () {
                           if (_pageController.hasClients &&
                               _currentPageIndex < _textPages.length - 1) {
                             _pageController.nextPage(
                               duration: const Duration(milliseconds: 300),
                               curve: Curves.easeInOut,
                             );
                           }
                         },
                         child: const SizedBox.expand(),
                       ),
                     ),
                   ],
                 ),
               ),

               // Page indicator
               Positioned(
                 bottom: 8,
                 left: 0,
                 right: 0,
                 child: Center(
                   child: Container(
                     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                     decoration: BoxDecoration(
                       color: Colors.black54,
                       borderRadius: BorderRadius.circular(12),
                     ),
                     child: Text(
                       '${_currentPageIndex + 1} / ${_textPages.length}',
                       style: const TextStyle(color: Colors.white70, fontSize: 12),
                     ),
                   ),
                 ),
               ),
             ],
           );
         }
       );
    }

    return const Center(child: CircularProgressIndicator());
  }

  void _runPagination(String text, TextStyle style, Size size, ReaderSettingsProvider settings) async {
    if (_isPaginating) return;
    setState(() => _isPaginating = true);

    // Run in microtask or isolate ideally, but sync is fine for now
    await Future.delayed(Duration.zero); // Unblock UI

    final padding = EdgeInsets.symmetric(
      horizontal: settings.horizontalPadding,
      vertical: settings.verticalPadding,
    );

    // Just ensure size is positive
    if (size.width <= padding.horizontal || size.height <= padding.vertical) {
       setState(() {
         _textPages = [text];
         _isPaginating = false;
         _lastPaginateText = text;
         _lastPaginateSize = size;
         _lastPaginateStyle = style;
       });
       return;
    }

    final pages = Paginator.paginate(
      text: text,
      style: style,
      boxSize: size,
      padding: padding,
      isVertical: settings.isVerticalWriting,
    );

    if (mounted) {
      setState(() {
        _textPages = pages;
        _isPaginating = false;
        _lastPaginateText = text;
        _lastPaginateSize = size;
        _lastPaginateStyle = style;
        _currentPageIndex = 0;
        if (_pageController.hasClients) {
          _pageController.jumpToPage(0);
        }
      });
    }
  }

  String _combineText(ReaderSettingsProvider settings) {
    if (_currentEpisode == null) return '';
    final sb = StringBuffer();
    if (settings.showPreface && _currentEpisode!.preface != null && _currentEpisode!.preface!.isNotEmpty) {
      sb.writeln(_currentEpisode!.preface);
      sb.writeln('\n\n');
    }
    sb.writeln(_currentEpisode!.body); // Assuming 'body' is the main content
    if (settings.showAfterword && _currentEpisode!.afterword != null && _currentEpisode!.afterword!.isNotEmpty) {
       sb.writeln('\n\n');
       sb.writeln(_currentEpisode!.afterword);
    }
    return sb.toString();
  }

  TextStyle _getTextStyle(ReaderSettingsProvider settings) {
    return TextStyle(
      fontSize: settings.fontSize,
      height: settings.lineHeight,
      letterSpacing: settings.letterSpacing,
      color: settings.textColor,
      fontFamily: settings.fontFamily == 'Default' ? null : settings.fontFamily,
    );
  }

  Widget _buildScrollView(ReaderSettingsProvider settings) {
    return GestureDetector(
      onTap: _toggleUI,
      onDoubleTap: _toggleAutoScroll,
      // Edge tap for speed control
      onTapUp: (details) {
        if (!_isAutoScrolling) return;
        final width = MediaQuery.of(context).size.width;
        if (details.localPosition.dx < width * 0.15) {
          settings.decrementSpeed();
          _startAutoScroll();
        } else if (details.localPosition.dx > width * 0.85) {
          settings.incrementSpeed();
          _startAutoScroll();
        }
      },
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildReaderContent(settings),
    );
  }

  Widget _buildReaderContent(ReaderSettingsProvider settings) {
    if (_currentEpisode == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            Text(
              'エピソード${_currentEpisodeNumber}が見つかりません',
              style: TextStyle(color: settings.textColor),
            ),
            const SizedBox(height: 8),
            const Text(
              'ダウンロードしてください',
              style: TextStyle(color: AppTheme.textMuted),
            ),
          ],
        ),
      );
    }

    final ep = _currentEpisode!;

    return SingleChildScrollView(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(
        horizontal: settings.horizontalPadding,
        vertical: settings.verticalPadding + MediaQuery.of(context).padding.top + 50,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Episode title
          Text(
            '第${ep.episodeNumber}話',
            style: TextStyle(
              fontSize: 12,
              color: settings.textColor.withValues(alpha: 0.5),
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            ep.title,
            style: TextStyle(
              fontSize: settings.fontSize + 4,
              fontWeight: FontWeight.w700,
              color: settings.textColor,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),

          // Preface
          if (settings.showPreface && ep.preface != null && ep.preface!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: settings.textColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border(
                  left: BorderSide(
                    color: settings.textColor.withValues(alpha: 0.2),
                    width: 3,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '前書き',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: settings.textColor.withValues(alpha: 0.5),
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ep.preface!,
                    style: TextStyle(
                      fontSize: settings.fontSize - 1,
                      color: settings.textColor.withValues(alpha: 0.7),
                      height: settings.lineHeight,
                      letterSpacing: settings.letterSpacing,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: settings.paragraphSpacing),
          ],

          // Main body
          _buildBodyText(ep.body, settings),

          // Afterword
          if (settings.showAfterword && ep.afterword != null && ep.afterword!.isNotEmpty) ...[
            SizedBox(height: settings.paragraphSpacing),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: settings.textColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border(
                  left: BorderSide(
                    color: settings.textColor.withValues(alpha: 0.2),
                    width: 3,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '後書き',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: settings.textColor.withValues(alpha: 0.5),
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ep.afterword!,
                    style: TextStyle(
                      fontSize: settings.fontSize - 1,
                      color: settings.textColor.withValues(alpha: 0.7),
                      height: settings.lineHeight,
                      letterSpacing: settings.letterSpacing,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // End-of-episode navigation
          const SizedBox(height: 40),
          _buildEpisodeNav(),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 80),
        ],
      ),
    );
  }

  Widget _buildBodyText(String body, ReaderSettingsProvider settings) {
    final paragraphs = body.split('\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paragraphs.map((paragraph) {
        if (paragraph.trim().isEmpty) {
          return SizedBox(height: settings.paragraphSpacing * 0.5);
        }
        return Padding(
          padding: EdgeInsets.only(bottom: settings.paragraphSpacing * 0.3),
          child: Text(
            paragraph,
            style: TextStyle(
              fontSize: settings.fontSize,
              color: settings.textColor,
              height: settings.lineHeight,
              letterSpacing: settings.letterSpacing,
              fontFamily: settings.fontFamily == 'Default'
                  ? null
                  : settings.fontFamily,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEpisodeNav() {
    return Row(
      children: [
        if (_currentEpisodeNumber > 1)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _prevEpisode,
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('前の話'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
                side: const BorderSide(color: AppTheme.borderColor),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          )
        else
          const Spacer(),
        const SizedBox(width: 12),
        if (_currentEpisodeNumber < widget.novel.totalEpisodes)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _nextEpisode,
              icon: const Text('次の話'),
              label: const Icon(Icons.arrow_forward, size: 16),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          )
        else
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: AppTheme.warmGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '🎉 最新話です',
                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          8, MediaQuery.of(context).padding.top + 4, 8, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black.withValues(alpha: 0.8),
            Colors.black.withValues(alpha: 0.0),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.novel.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '第${_currentEpisodeNumber}話 / ${widget.novel.totalEpisodes}話',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.format_size, color: Colors.white),
            onPressed: () => setState(() => _showSettings = !_showSettings),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(ReaderSettingsProvider settings) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black.withValues(alpha: 0.0),
            Colors.black.withValues(alpha: 0.85),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildBarButton(Icons.skip_previous, '前話', _prevEpisode),
          _buildBarButton(
            _isAutoScrolling ? Icons.pause : Icons.play_arrow,
            _isAutoScrolling ? '停止' : '自動',
            _toggleAutoScroll,
            highlight: _isAutoScrolling,
          ),
          _buildBarButton(Icons.skip_next, '次話', _nextEpisode),
          _buildBarButton(Icons.tune, '設定', () {
            setState(() => _showSettings = !_showSettings);
          }),
        ],
      ),
    );
  }

  Widget _buildBarButton(IconData icon, String label, VoidCallback onTap,
      {bool highlight = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: highlight
                ? BoxDecoration(
                    gradient: AppTheme.accentGradient,
                    borderRadius: BorderRadius.circular(12),
                  )
                : null,
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollSpeedIndicator(ReaderSettingsProvider settings) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.accentPrimary.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.speed, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            '${settings.autoScrollSpeed.toInt()} px/s',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsPanel(ReaderSettingsProvider settings) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 400),
      decoration: BoxDecoration(
        color: AppTheme.bgCard.withValues(alpha: 0.97),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, MediaQuery.of(context).padding.bottom + 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar + Close
            GestureDetector(
              onTap: () => setState(() => _showSettings = false),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.textMuted,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('設定', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => setState(() => _showSettings = false),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Color presets
            const Text('テーマ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: ReaderSettingsProvider.colorPresets.entries.map((e) {
                  final isSelected = settings.backgroundColor == e.value['bg'];
                  return GestureDetector(
                    onTap: () => settings.applyPreset(e.key),
                    child: Container(
                      width: 50,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: e.value['bg'],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.accentPrimary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'あ',
                        style: TextStyle(color: e.value['text'], fontSize: 18),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // View Mode
            const Text('閲覧モード', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<String>(
                    segments: const [
                       ButtonSegment(value: 'scroll', label: Text('スクロール')),
                       ButtonSegment(value: 'page', label: Text('ページ')),
                    ],
                    selected: {settings.viewMode},
                    onSelectionChanged: (Set<String> newSelection) {
                      settings.setViewMode(newSelection.first);
                    },
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: WidgetStateProperty.resolveWith<Color>(
                        (Set<WidgetState> states) {
                          if (states.contains(WidgetState.selected)) {
                            return AppTheme.accentPrimary.withValues(alpha: 0.2);
                          }
                          return Colors.transparent;
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Font size
            _buildSliderRow('文字サイズ', '${settings.fontSize.toInt()}px',
                settings.fontSize, 8, 48, settings.setFontSize),

            // Line height
            _buildSliderRow('行間', '${settings.lineHeight.toStringAsFixed(1)}',
                settings.lineHeight, 1.0, 3.5, settings.setLineHeight),

            // Letter spacing
            _buildSliderRow('字間', '${settings.letterSpacing.toStringAsFixed(1)}px',
                settings.letterSpacing, -2.0, 10.0, settings.setLetterSpacing),

            // Padding
            _buildSliderRow('余白', '${settings.horizontalPadding.toInt()}px',
                settings.horizontalPadding, 0, 80, settings.setHorizontalPadding),

            const SizedBox(height: 8),
            const Divider(color: AppTheme.borderColor),
            const SizedBox(height: 8),

            // Auto-scroll speed
            _buildSliderRow(
              '自動スクロール速度',
              '${settings.autoScrollSpeed.toInt()} px/s',
              settings.autoScrollSpeed,
              5,
              200,
              (v) {
                settings.setAutoScrollSpeed(v);
                if (_isAutoScrolling) _startAutoScroll();
              },
            ),

            // Toggles
            _buildToggleRow('密度ベース速度調整', settings.densityBasedSpeed,
                settings.setDensityBasedSpeed),
            _buildToggleRow('前書き表示', settings.showPreface, settings.setShowPreface),
            _buildToggleRow('後書き表示', settings.showAfterword, settings.setShowAfterword),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderRow(String label, String value, double current,
      double min, double max, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ),
          Expanded(
            child: Slider(
              value: current.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 55,
            child: Text(
              value,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow(
      String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
