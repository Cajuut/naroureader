import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/library_provider.dart';
import '../providers/reading_stats_provider.dart';
import '../theme/app_theme.dart';
import '../models/novel.dart';
import 'novel_detail_screen.dart';
import 'reader_screen.dart';
import 'stats_screen.dart';
import 'settings_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _urlController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildLibraryTab(),
          const StatsScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: AppTheme.borderColor.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.library_books_outlined),
              activeIcon: Icon(Icons.library_books),
              label: 'ライブラリ',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              activeIcon: Icon(Icons.bar_chart),
              label: '統計',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: '設定',
            ),
          ],
        ),
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: _showAddNovelDialog,
              icon: const Icon(Icons.add),
              label: const Text('作品を追加'),
            )
          : null,
    );
  }

  Widget _buildLibraryTab() {
    return Consumer<LibraryProvider>(
      builder: (context, library, _) {
        return CustomScrollView(
          slivers: [
            // App Bar
            SliverAppBar(
              floating: true,
              snap: true,
              expandedHeight: _isSearching ? 130 : 100, // 少し高さを確保
              flexibleSpace: FlexibleSpaceBar(
                background: SafeArea(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), // Paddingを整理
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center, // 中央寄せ
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              '📚 なろうリーダー',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: Icon(_isSearching ? Icons.close : Icons.search),
                              onPressed: () {
                                setState(() {
                                  _isSearching = !_isSearching;
                                  if (!_isSearching) {
                                    _searchController.clear();
                                    library.setSearch('');
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                        if (_isSearching)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: SizedBox(
                              height: 44,
                              child: TextField(
                                controller: _searchController,
                                autofocus: true,
                                decoration: const InputDecoration(
                                  hintText: 'タイトル・作者・タグで検索...',
                                  prefixIcon: Icon(Icons.search, size: 20),
                                  isDense: true,
                                ),
                                onChanged: (q) => library.setSearch(q),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Quick Stats Bar
            SliverToBoxAdapter(
              child: _buildQuickStats(),
            ),

            // Filter chips
            SliverToBoxAdapter(
              child: _buildFilterChips(library),
            ),

            // Novel list
            if (library.isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (library.novels.isEmpty)
              SliverFillRemaining(
                child: _buildEmptyState(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildNovelCard(library.novels[index]),
                    childCount: library.novels.length,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildQuickStats() {
    return Consumer<ReadingStatsProvider>(
      builder: (context, stats, _) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.glassDecoration,
          child: Row(
            children: [
              _buildStatItem(
                icon: Icons.auto_stories,
                label: '総読了',
                value: stats.formattedTotalCharacters,
                gradient: AppTheme.accentGradient,
              ),
              Container(
                width: 1,
                height: 40,
                color: AppTheme.borderColor,
              ),
              _buildStatItem(
                icon: Icons.timer_outlined,
                label: '読書時間',
                value: stats.formattedTotalTime,
                gradient: AppTheme.warmGradient,
              ),
              Container(
                width: 1,
                height: 40,
                color: AppTheme.borderColor,
              ),
              Consumer<LibraryProvider>(
                builder: (context, lib, _) => _buildStatItem(
                  icon: Icons.library_books_outlined,
                  label: '作品数',
                  value: '${lib.totalNovels}',
                  gradient: const LinearGradient(
                    colors: [AppTheme.successColor, Color(0xFF00B4D8)],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required LinearGradient gradient,
  }) {
    return Expanded(
      child: Column(
        children: [
          ShaderMask(
            shaderCallback: (bounds) => gradient.createShader(bounds),
            child: Icon(icon, size: 22, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(LibraryProvider library) {
    final filters = ['all', 'favorites', ...library.folders];
    final labels = {
      'all': '📖 すべて',
      'favorites': '⭐ お気に入り',
      'default': '📁 デフォルト',
    };

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = library.currentFolder == filter;
          return ChoiceChip(
            label: Text(labels[filter] ?? '📁 $filter'),
            selected: isSelected,
            onSelected: (_) => library.setFolder(filter),
            selectedColor: AppTheme.accentPrimary.withValues(alpha: 0.25),
            labelStyle: TextStyle(
              color: isSelected ? AppTheme.accentPrimary : AppTheme.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              fontSize: 12,
            ),
          );
        },
      ),
    );
  }

  Widget _buildNovelCard(Novel novel) {
    final statusColors = {
      'reading': AppTheme.accentPrimary,
      'completed': AppTheme.successColor,
      'on_hold': AppTheme.warningColor,
      'dropped': AppTheme.errorColor,
      'plan_to_read': AppTheme.textMuted,
    };
    final statusLabels = {
      'reading': '読書中',
      'completed': '読了',
      'on_hold': '中断',
      'dropped': '中止',
      'plan_to_read': '積読',
    };

    final sourceIcons = {
      'narou': '📗',
      'kakuyomu': '📘',
      'hameln': '📙',
    };

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NovelDetailScreen(novel: novel),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.glassDecorationWithRadius(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Source icon & Progress
            Column(
              children: [
                Text(
                  sourceIcons[novel.source] ?? '📕',
                  style: const TextStyle(fontSize: 32),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 40,
                  height: 40,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: novel.totalEpisodes > 0
                            ? novel.lastReadEpisode / novel.totalEpisodes
                            : 0,
                        strokeWidth: 3,
                        backgroundColor: AppTheme.borderColor,
                        valueColor: AlwaysStoppedAnimation(
                          statusColors[novel.status] ?? AppTheme.textMuted,
                        ),
                      ),
                      Text(
                        novel.totalEpisodes > 0
                            ? '${(novel.lastReadEpisode / novel.totalEpisodes * 100).toInt()}%'
                            : '0%',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          novel.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (novel.isFavorite)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.star, size: 16, color: AppTheme.warningColor),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    novel.author,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildChip(
                        statusLabels[novel.status] ?? novel.status,
                        statusColors[novel.status] ?? AppTheme.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${novel.lastReadEpisode}/${novel.totalEpisodes}話',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      if (novel.unreadEpisodes > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.accentTertiary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '+${novel.unreadEpisodes}話',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.accentTertiary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Quick read button
            Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: AppTheme.accentGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        if (novel.id != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ReaderScreen(
                                novel: novel,
                                startEpisode: novel.lastReadEpisode > 0
                                    ? novel.lastReadEpisode
                                    : 1,
                              ),
                            ),
                          );
                        }
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(Icons.play_arrow, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.accentPrimary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.menu_book_outlined,
              size: 64,
              color: AppTheme.accentPrimary,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'ライブラリが空です',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '小説のURLを追加して\n読書を始めましょう',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddNovelDialog,
            icon: const Icon(Icons.add),
            label: const Text('作品を追加'),
          ),
        ],
      ),
    );
  }

  void _showAddNovelDialog() {
    _urlController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.add_circle_outline, color: AppTheme.accentPrimary),
            SizedBox(width: 8),
            Text('作品を追加'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '小説家になろう・カクヨム・ハーメルンの\nURLを入力してください',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                hintText: 'https://ncode.syosetu.com/n1234ab/',
                prefixIcon: Icon(Icons.link, size: 20),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SearchScreen()),
                );
              },
              icon: const Icon(Icons.search),
              label: const Text('Web検索で探す (なろうAPI)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.accentPrimary,
                side: const BorderSide(color: AppTheme.accentPrimary),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () async {
              final url = _urlController.text.trim();
              if (url.isEmpty) return;
              
              Navigator.pop(ctx); // Close immediately for UX
              
              final lib = context.read<LibraryProvider>();
              try {
                // Show global loading if possible, or snackbar later
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('追加中...')),
                );
                
                final novel = await lib.addNovel(url);
                if (mounted) {
                   ScaffoldMessenger.of(context).hideCurrentSnackBar();
                   if (novel != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('「${novel.title}」を追加しました'),
                          backgroundColor: AppTheme.successColor,
                        ),
                      );
                   } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                         SnackBar(
                           content: Text('追加に失敗しました: ${lib.error ?? "不明なエラー"}'),
                           backgroundColor: AppTheme.errorColor,
                         ),
                      );
                   }
                }
              } catch (e) {
                 if (mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                       SnackBar(content: Text('エラー: $e'), backgroundColor: AppTheme.errorColor),
                    );
                 }
              }
            },
            child: const Text('追加'),
          ),
        ],
      ),
    );
  }

  Widget _buildSiteChip(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Chip(
        label: Text(label, style: const TextStyle(fontSize: 11)),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
