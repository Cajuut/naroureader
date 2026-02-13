import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/novel.dart';
import '../models/episode.dart';
import '../providers/library_provider.dart';
import '../providers/reader_settings_provider.dart';
import '../theme/app_theme.dart';
import 'reader_screen.dart';

class NovelDetailScreen extends StatefulWidget {
  final Novel novel;

  const NovelDetailScreen({super.key, required this.novel});

  @override
  State<NovelDetailScreen> createState() => _NovelDetailScreenState();
}

class _NovelDetailScreenState extends State<NovelDetailScreen> {
  List<Episode> _episodes = [];
  bool _isLoadingEpisodes = false;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _loadEpisodes();
  }

  Future<void> _loadEpisodes() async {
    if (widget.novel.id == null) return;
    setState(() => _isLoadingEpisodes = true);
    final lib = context.read<LibraryProvider>();
    
    // Get downloaded episodes
    final dbEpisodes = await lib.getEpisodes(widget.novel.id!);
    final dbMap = {for (var e in dbEpisodes) e.episodeNumber: e};
    
    final fullList = <Episode>[];
    // Create list from 1 to totalEpisodes
    // Use the larger of totalEpisodes or the last downloaded episode (in case total is outdated)
    final maxEp = dbEpisodes.isNotEmpty 
        ? (dbEpisodes.last.episodeNumber > widget.novel.totalEpisodes 
            ? dbEpisodes.last.episodeNumber 
            : widget.novel.totalEpisodes)
        : widget.novel.totalEpisodes;
        
    for (int i = 1; i <= maxEp; i++) {
      if (dbMap.containsKey(i)) {
        fullList.add(dbMap[i]!);
      } else {
        // Placeholder for undownloaded episode
        fullList.add(Episode(
          id: -1, 
          novelId: widget.novel.id!,
          episodeNumber: i,
          title: '第$i話', // Using generic title until fetched
          body: '',
          characterCount: 0,
        ));
      }
    }
    
    _episodes = fullList;
    setState(() => _isLoadingEpisodes = false);

    // Background refresh if totalEpisodes seems wrong or old
    if (widget.novel.totalEpisodes == 0 || 
        (widget.novel.lastChecked != null && 
         DateTime.now().difference(widget.novel.lastChecked!).inHours > 1)) {
       // Fire and forget, but update UI when done if mounted
       lib.refreshNovelInfo(widget.novel).then((_) {
         if (mounted) {
           // Reload novel object from provider to get updated totalEpisodes
           // Actually the provider notifies listeners, so if we listen to it properly...
           // But here we are using widget.novel which might be stale.
           // Ideally we should use Consumer or Selector.
           // For now, let's just create a quick reload logic.
           lib.getNovel(widget.novel.id!).then((updated) {
             if (updated != null && mounted && updated.totalEpisodes != widget.novel.totalEpisodes) {
               // Navigation replacement hack or just force reload
               // Since widget.novel is final, we can't update it easily without robust state management.
               // But we can trigger a rebuild if we use a local novel state variable.
               // For this quick fix, we just re-run _loadEpisodes with the updated novel info via a trick or rely on parent rebuild.
               // Actually, let's just re-fetch episodes using the new count from DB (which refreshNovelInfo updated)
               _loadEpisodesFromDb(lib); 
             }
           });
         }
       });
    }
  }

  Future<void> _loadEpisodesFromDb(LibraryProvider lib) async {
    final updatedNovel = await lib.getNovel(widget.novel.id!);
    if (updatedNovel == null) return;
    
    final dbEpisodes = await lib.getEpisodes(widget.novel.id!);
    final dbMap = {for (var e in dbEpisodes) e.episodeNumber: e};
    
    final fullList = <Episode>[];
    final maxEp = dbEpisodes.isNotEmpty 
        ? (dbEpisodes.last.episodeNumber > updatedNovel.totalEpisodes 
            ? dbEpisodes.last.episodeNumber 
            : updatedNovel.totalEpisodes)
        : updatedNovel.totalEpisodes;
        
    for (int i = 1; i <= maxEp; i++) {
      if (dbMap.containsKey(i)) {
        fullList.add(dbMap[i]!);
      } else {
        fullList.add(Episode(
          id: -1, 
          novelId: widget.novel.id!,
          episodeNumber: i,
          title: '第$i話',
          body: '',
          characterCount: 0,
        ));
      }
    }
    
    if (mounted) {
      setState(() {
        _episodes = fullList;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // リアルタイム反映のためにProviderから最新のNovelを取得
    final novel = context.select<LibraryProvider, Novel>((provider) {
      try {
        return provider.allNovels.firstWhere((n) => n.id == widget.novel.id);
      } catch (_) {
        return widget.novel;
      }
    });

    final settings = context.watch<ReaderSettingsProvider>();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context, novel),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatsRow(novel),
                  const SizedBox(height: 24),
                  _buildActionButtons(context, novel),
                  const SizedBox(height: 24),
                  if (novel.synopsis.isNotEmpty) _buildSynopsis(novel, settings),
                  if (novel.synopsis.isNotEmpty) const SizedBox(height: 24),
                  const Divider(height: 1),
                  const SizedBox(height: 24),
                  _buildEpisodeListHeader(novel),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          _buildEpisodeList(novel, settings),
        ],
      ),
      floatingActionButton: _episodes.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () {
                final startEp =
                    novel.lastReadEpisode > 0 ? novel.lastReadEpisode : 1;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ReaderScreen(novel: novel, startEpisode: startEp),
                  ),
                ).then((_) => _loadEpisodes());
              },
              icon: const Icon(Icons.play_arrow),
              label: Text(
                novel.lastReadEpisode > 0
                    ? '続きから読む (${novel.lastReadEpisode}話)'
                    : '読み始める',
              ),
            )
          : null,
    );
  }

  Widget _buildSliverAppBar(BuildContext context, Novel novel) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.accentPrimary.withValues(alpha: 0.3),
                AppTheme.bgDark,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    novel.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.person_outline,
                          size: 14, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        novel.author,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      _sourceChip(novel.source),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(
            novel.isFavorite ? Icons.star : Icons.star_border,
            color: novel.isFavorite ? AppTheme.warningColor : AppTheme.textMuted,
          ),
          onPressed: () =>
              context.read<LibraryProvider>().toggleFavorite(novel),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) => _handleMenuAction(value, novel),
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'status', child: Text('ステータス変更')),
            const PopupMenuItem(value: 'folder', child: Text('フォルダ移動')),
            const PopupMenuItem(
              value: 'delete',
              child: Text('削除', style: TextStyle(color: AppTheme.errorColor)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSourceChip(String source) {
    return _sourceChip(source);
  }

  Widget _buildStatsRow(Novel novel) {
    return Row(
      children: [
        _buildStatBox('総話数', '${novel.totalEpisodes}', Icons.format_list_numbered),
        const SizedBox(width: 12),
        _buildStatBox('既読', '${novel.lastReadEpisode}話', Icons.check_circle_outline),
        const SizedBox(width: 12),
        _buildStatBox('文字数', _formatCharCount(novel.totalCharacters), Icons.text_fields),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, Novel novel) {
    return Consumer<LibraryProvider>(
      builder: (context, lib, _) {
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isDownloading
                        ? null
                        : () async {
                            setState(() => _isDownloading = true);
                            await lib.downloadAllEpisodes(novel);
                            await _loadEpisodes();
                            setState(() => _isDownloading = false);
                          },
                    icon: _isDownloading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.download),
                    label: Text(_isDownloading ? lib.downloadStatus : '全話ダウンロード'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.horizontal(left: Radius.circular(8)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 1), // Separator
                Container(
                  height: 48,
                  decoration: const BoxDecoration(
                    color: AppTheme.accentSecondary,
                    borderRadius: BorderRadius.horizontal(right: Radius.circular(8)),
                  ),
                  child: PopupMenuButton<String>(
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                    onSelected: (value) {
                       if (value == 'range') {
                         _showDownloadRangeDialog(context, lib, novel);
                       } else if (value == 'delete') {
                         showDialog(
                           context: context,
                           builder: (ctx) => AlertDialog(
                             title: const Text('キャッシュの削除'),
                             content: const Text('ダウンロードしたエピソードデータをすべて削除しますか？\n(既読情報などは保持されます)'),
                             actions: [
                               TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
                               TextButton(
                                 onPressed: () async {
                                   Navigator.pop(ctx);
                                   await lib.deleteNovelEpisodes(novel);
                                   await _loadEpisodes();
                                   if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('キャッシュを削除しました')),
                                      );
                                   }
                                 },
                                 child: const Text('削除', style: TextStyle(color: AppTheme.errorColor)),
                               ),
                             ],
                           ),
                         );
                       }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                         value: 'range',
                         child: Row(
                           children: [
                             Icon(Icons.tune, size: 18, color: AppTheme.textPrimary),
                             SizedBox(width: 8),
                             Text('範囲指定ダウンロード'),
                           ],
                         ),
                      ),
                      const PopupMenuItem(
                         value: 'delete',
                         child: Row(
                           children: [
                             Icon(Icons.delete_outline, size: 18, color: AppTheme.errorColor),
                             SizedBox(width: 8),
                             Text('キャッシュを削除', style: TextStyle(color: AppTheme.errorColor)),
                           ],
                         ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_isDownloading && lib.downloadProgress > 0)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: lib.downloadProgress,
                    minHeight: 6,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showDownloadRangeDialog(BuildContext context, LibraryProvider lib, Novel novel) {
    final startController = TextEditingController(text: '1');
    final endController = TextEditingController(text: '${novel.totalEpisodes}');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('範囲指定ダウンロード'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             const Text('ダウンロードするエピソードの範囲を指定してください。'),
             const SizedBox(height: 16),
             Row(
               children: [
                 Expanded(
                   child: TextField(
                     controller: startController,
                     keyboardType: TextInputType.number,
                     decoration: const InputDecoration(labelText: '開始話数'),
                   ),
                 ),
                 const Padding(
                   padding: EdgeInsets.symmetric(horizontal: 16),
                   child: Text('〜'),
                 ),
                 Expanded(
                   child: TextField(
                     controller: endController,
                     keyboardType: TextInputType.number,
                     decoration: const InputDecoration(labelText: '終了話数'),
                   ),
                 ),
               ],
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
              final start = int.tryParse(startController.text) ?? 1;
              final end = int.tryParse(endController.text);
              
              Navigator.pop(ctx);
              
              if (start > 0) {
                 setState(() => _isDownloading = true);
                 await lib.downloadEpisodes(novel, start: start, end: end);
                 await _loadEpisodes();
                 setState(() => _isDownloading = false);
              }
            },
            child: const Text('ダウンロード開始'),
          ),
        ],
      ),
    );
  }

  Widget _buildSynopsis(Novel novel, ReaderSettingsProvider settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('あらすじ',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: AppTheme.glassDecoration,
          child: Text(
            novel.synopsis,
            style: const TextStyle(
              fontSize: 13,
              height: 1.6,
              color: AppTheme.textSecondary,
            ),
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildEpisodeListHeader(Novel novel) {
    return Row(
      children: [
        const Text(
          'エピソード一覧',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const Spacer(),
        Text(
          '${_episodes.length}/${novel.totalEpisodes}話',
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildEpisodeList(Novel novel, ReaderSettingsProvider settings) {
    if (_isLoadingEpisodes) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    } else if (_episodes.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(32),
          decoration: AppTheme.glassDecoration,
          child: const Column(
            children: [
              Icon(Icons.download_outlined,
                  size: 48, color: AppTheme.textMuted),
              SizedBox(height: 12),
              Text(
                'エピソードがダウンロードされていません',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              Text(
                '「全話ダウンロード」で取得してください',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
      );
    } else {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _buildEpisodeItem(_episodes[index], novel),
            childCount: _episodes.length,
          ),
        ),
      );
    }
  }

  Widget _buildEpisodeItem(Episode episode, Novel novel) {
    final isDownloaded = episode.id != -1;
    final isRead = isDownloaded && episode.episodeNumber <= novel.lastReadEpisode;
    final isCurrent = isDownloaded && episode.episodeNumber == novel.lastReadEpisode;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: isCurrent
            ? AppTheme.accentPrimary.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ReaderScreen(
                  novel: novel,
                  startEpisode: episode.episodeNumber,
                ),
              ),
            ).then((_) => _loadEpisodes());
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isDownloaded
                        ? (isRead
                            ? AppTheme.accentPrimary.withValues(alpha: 0.2)
                            : AppTheme.bgSurface)
                        : Colors.transparent,
                    border: isDownloaded ? null : Border.all(color: AppTheme.borderColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: isDownloaded
                      ? (isRead
                          ? const Icon(Icons.check,
                              size: 16, color: AppTheme.accentPrimary)
                          : Text(
                              '${episode.episodeNumber}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textMuted,
                              ),
                            ))
                      : const Icon(Icons.cloud_download_outlined,
                          size: 16, color: AppTheme.textMuted),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        episode.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isCurrent ? FontWeight.w600 : FontWeight.w400,
                          color: isDownloaded
                              ? (isRead
                                  ? AppTheme.textSecondary
                                  : AppTheme.textPrimary)
                              : AppTheme.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isDownloaded)
                        Text(
                          '${_formatCharCount(episode.characterCount)}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.textMuted,
                          ),
                        )
                      else
                        const Text(
                          'タップして読み込み',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.textMuted,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
                if (isCurrent)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: AppTheme.accentGradient,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '続き',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sourceChip(String source) {
    final labels = {'narou': 'なろう', 'kakuyomu': 'カクヨム', 'hameln': 'ハーメルン'};
    final colors = {
      'narou': AppTheme.successColor,
      'kakuyomu': AppTheme.accentPrimary,
      'hameln': AppTheme.warningColor,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (colors[source] ?? AppTheme.textMuted).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        labels[source] ?? source,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: colors[source] ?? AppTheme.textMuted,
        ),
      ),
    );
  }

  Widget _buildStatBox(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: AppTheme.glassDecoration,
        child: Column(
          children: [
            Icon(icon, size: 20, color: AppTheme.accentSecondary),
            const SizedBox(height: 6),
            Text(value,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text(label,
                style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }

  String _formatCharCount(int count) {
    if (count >= 10000) return '${(count / 10000).toStringAsFixed(1)}万字';
    return '$count字';
  }

  void _handleMenuAction(String action, Novel novel) {
    final lib = context.read<LibraryProvider>();
    switch (action) {
      case 'status':
        _showStatusDialog(novel);
        break;
      case 'folder':
        _showFolderDialog(novel);
        break;
      case 'delete':
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('作品を削除'),
            content:
                Text('「${novel.title}」を削除しますか？\nダウンロードしたエピソードも削除されます。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('キャンセル'),
              ),
              ElevatedButton(
                onPressed: () {
                  lib.deleteNovel(novel.id!);
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.errorColor),
                child: const Text('削除'),
              ),
            ],
          ),
        );
        break;
    }
  }

  void _showStatusDialog(Novel novel) {
    final statuses = {
      'reading': '📖 読書中',
      'completed': '✅ 読了',
      'on_hold': '⏸ 中断',
      'dropped': '❌ 中止',
      'plan_to_read': '📚 積読',
    };

    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('ステータス変更'),
        children: statuses.entries.map((e) {
          return SimpleDialogOption(
            onPressed: () {
              context.read<LibraryProvider>().updateStatus(novel, e.key);
              Navigator.pop(ctx);
            },
            child: Text(e.value),
          );
        }).toList(),
      ),
    );
  }

  void _showFolderDialog(Novel novel) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('フォルダに移動'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'フォルダ名'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              final folder = controller.text.trim();
              if (folder.isNotEmpty) {
                context
                    .read<LibraryProvider>()
                    .moveToFolder(novel, folder);
                Navigator.pop(ctx);
              }
            },
            child: const Text('移動'),
          ),
        ],
      ),
    );
  }
}
