import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/novel.dart';
import '../providers/library_provider.dart';
import '../services/novel_scraper.dart';
import '../theme/app_theme.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Novel> _searchResults = [];
  bool _isSearching = false;
  String? _errorMessage;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch({String? query}) async {
    final q = query ?? _searchController.text.trim();
    if (q.isEmpty) return;
    
    // Unfocus keyboard
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _isSearching = true;
      _errorMessage = null;
      _searchResults = [];
    });

    try {
      final results = await NovelScraper.searchNarou(q);
      if (mounted) {
        setState(() {
          _searchResults = results;
          if (results.isEmpty) {
            _errorMessage = '見つかりませんでした';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '検索エラー: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _addToLibrary(Novel novel) async {
    try {
      final lib = context.read<LibraryProvider>();
      
      // Check if already exists
      final exists = await lib.getNovelByNcode(novel.ncode, novel.source);
      if (exists != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('すでにライブラリに存在します: ${exists.title}')),
        );
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final url = 'https://ncode.syosetu.com/${novel.ncode}/';
      final added = await lib.addNovel(url);
      
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        if (added != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${added.title} を追加しました'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        } else {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('追加に失敗しました。'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラー: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'なろう小説を検索...',
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: (val) => _performSearch(query: val),
          autofocus: true,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _performSearch(),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            Text(_errorMessage!, style: const TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 48, color: AppTheme.textMuted),
            SizedBox(height: 16),
            Text('キーワードを入力して検索してください',
                style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final novel = _searchResults[index];
        return _buildNovelCard(novel);
      },
    );
  }

  Widget _buildNovelCard(Novel novel) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppTheme.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.borderColor.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _addToLibrary(novel),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                novel.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '作者: ${novel.author}',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 8),
              if (novel.synopsis.isNotEmpty) ...[
                Text(
                  novel.synopsis,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  const Icon(Icons.menu_book, size: 14, color: AppTheme.textMuted),
                  const SizedBox(width: 4),
                  Text('${novel.totalEpisodes}話',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.accentPrimary),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, size: 14, color: AppTheme.accentPrimary),
                        SizedBox(width: 4),
                        Text('追加',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.accentPrimary)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
