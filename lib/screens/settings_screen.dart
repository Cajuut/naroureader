import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/reader_settings_provider.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ReaderSettingsProvider>(
      builder: (context, settings, _) {
        return CustomScrollView(
          slivers: [
            const SliverAppBar(
              floating: true,
              title: Text('⚙️ 設定'),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Reading settings
                  _buildSectionHeader('📖 読書設定'),
                  const SizedBox(height: 8),
                  _buildSettingCard([
                    _buildSlider(
                      '文字サイズ',
                      '${settings.fontSize.toInt()}px',
                      settings.fontSize,
                      8,
                      48,
                      settings.setFontSize,
                    ),
                    const Divider(color: AppTheme.borderColor, height: 1),
                    _buildSlider(
                      '行間',
                      '×${settings.lineHeight.toStringAsFixed(1)}',
                      settings.lineHeight,
                      1.0,
                      3.5,
                      settings.setLineHeight,
                    ),
                    const Divider(color: AppTheme.borderColor, height: 1),
                    _buildSlider(
                      '字間',
                      '${settings.letterSpacing.toStringAsFixed(1)}px',
                      settings.letterSpacing,
                      -2.0,
                      10.0,
                      settings.setLetterSpacing,
                    ),
                    const Divider(color: AppTheme.borderColor, height: 1),
                    _buildSlider(
                      '段落間隔',
                      '${settings.paragraphSpacing.toInt()}px',
                      settings.paragraphSpacing,
                      0,
                      60,
                      settings.setParagraphSpacing,
                    ),
                    const Divider(color: AppTheme.borderColor, height: 1),
                    _buildSlider(
                      '左右余白',
                      '${settings.horizontalPadding.toInt()}px',
                      settings.horizontalPadding,
                      0,
                      80,
                      settings.setHorizontalPadding,
                    ),
                    const Divider(color: AppTheme.borderColor, height: 1),
                    _buildSlider(
                      '上下余白',
                      '${settings.verticalPadding.toInt()}px',
                      settings.verticalPadding,
                      0,
                      80,
                      settings.setVerticalPadding,
                    ),
                  ]),

                  const SizedBox(height: 20),
                  _buildSectionHeader('🎨 テーマ'),
                  const SizedBox(height: 8),
                  _buildSettingCard([
                    _buildColorPresets(settings),
                  ]),

                  const SizedBox(height: 20),
                  _buildSectionHeader('⏩ 自動スクロール'),
                  const SizedBox(height: 8),
                  _buildSettingCard([
                    _buildSlider(
                      'スクロール速度',
                      '${settings.autoScrollSpeed.toInt()} px/s',
                      settings.autoScrollSpeed,
                      5,
                      200,
                      settings.setAutoScrollSpeed,
                    ),
                    const Divider(color: AppTheme.borderColor, height: 1),
                    _buildToggle(
                      '密度ベース速度調整',
                      'セリフの多さに応じて速度を自動調整',
                      settings.densityBasedSpeed,
                      settings.setDensityBasedSpeed,
                    ),
                  ]),

                  const SizedBox(height: 20),
                  _buildSectionHeader('👁 表示'),
                  const SizedBox(height: 8),
                  _buildSettingCard([
                    _buildToggle('前書き表示', '各話の前書きを表示',
                        settings.showPreface, settings.setShowPreface),
                    const Divider(color: AppTheme.borderColor, height: 1),
                    _buildToggle('後書き表示', '各話の後書きを表示',
                        settings.showAfterword, settings.setShowAfterword),
                    const Divider(color: AppTheme.borderColor, height: 1),
                    _buildToggle('ルビ表示', 'ふりがなを表示',
                        settings.showRuby, settings.setShowRuby),
                  ]),

                  const SizedBox(height: 20),
                  _buildSectionHeader('💾 データ'),
                  const SizedBox(height: 8),
                  _buildSettingCard([
                    _buildActionTile(
                      Icons.upload_file,
                      '設定をエクスポート',
                      '配色・フォント設定をJSONファイルに保存',
                      () => _exportSettings(context),
                    ),
                    const Divider(color: AppTheme.borderColor, height: 1),
                    _buildActionTile(
                      Icons.download,
                      '設定をインポート',
                      'JSONファイルから設定を読み込む',
                      () => _importSettings(context),
                    ),
                    const Divider(color: AppTheme.borderColor, height: 1),
                    _buildActionTile(
                      Icons.backup,
                      'ライブラリバックアップ',
                      '全データをJSONにエクスポート',
                      () => _backupLibrary(context),
                    ),
                  ]),

                  const SizedBox(height: 20),
                  _buildSectionHeader('ℹ️ アプリ情報'),
                  const SizedBox(height: 8),
                  _buildSettingCard([
                    _buildInfoTile('バージョン', 'v1.0.0'),
                    const Divider(color: AppTheme.borderColor, height: 1),
                    _buildInfoTile('ビルド', 'Flutter Desktop'),
                    const Divider(color: AppTheme.borderColor, height: 1),
                    _buildInfoTile('対応サイト', '小説家になろう'),
                  ]),

                  const SizedBox(height: 20),

                  // Keyboard shortcuts help
                  _buildSectionHeader('⌨️ キーボードショートカット'),
                  const SizedBox(height: 8),
                  _buildSettingCard([
                    _buildInfoTile('Space', '自動スクロール ON/OFF'),
                    const Divider(color: AppTheme.borderColor, height: 1),
                    _buildInfoTile('↑ / ↓', 'スクロール'),
                    const Divider(color: AppTheme.borderColor, height: 1),
                    _buildInfoTile('← / →', '前話 / 次話'),
                    const Divider(color: AppTheme.borderColor, height: 1),
                    _buildInfoTile('[ / ]', 'スクロール減速 / 加速'),
                    const Divider(color: AppTheme.borderColor, height: 1),
                    _buildInfoTile('Esc', '読書画面を閉じる'),
                  ]),

                  const SizedBox(height: 100),
                ]),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }

  Widget _buildSettingCard(List<Widget> children) {
    return Container(
      decoration: AppTheme.glassDecoration,
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  Widget _buildSlider(String label, String value, double current, double min,
      double max, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          SizedBox(
            width: 85,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
            ),
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
            width: 60,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.accentPrimary,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildToggle(
      String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                Text(subtitle, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildActionTile(
      IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accentPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: AppTheme.accentPrimary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    Text(subtitle, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 18, color: AppTheme.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildColorPresets(ReaderSettingsProvider settings) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: ReaderSettingsProvider.colorPresets.entries.map((e) {
          final presetLabels = {
            'midnight': '深夜',
            'sepia': 'セピア',
            'paper': '紙',
            'amoled': '漆黒',
            'forest': '森林',
            'ocean': '深海',
          };
          final isSelected = settings.backgroundColor == e.value['bg'];
          return GestureDetector(
            onTap: () => settings.applyPreset(e.key),
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: e.value['bg'],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppTheme.accentPrimary : AppTheme.borderColor,
                  width: isSelected ? 2.5 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppTheme.accentPrimary.withValues(alpha: 0.3),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'あいう',
                    style: TextStyle(
                      color: e.value['text'],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    presetLabels[e.key] ?? e.key,
                    style: TextStyle(
                      color: e.value['text']!.withValues(alpha: 0.6),
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _exportSettings(BuildContext context) async {
    final settings = context.read<ReaderSettingsProvider>();
    try {
      final path = await settings.exportToFile();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('設定をエクスポートしました\n$path')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エクスポート失敗: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _importSettings(BuildContext context) async {
    // For now, show a dialog to enter path
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('設定ファイルのパス'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'settings_export.json のパスを入力',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () async {
              final settings = context.read<ReaderSettingsProvider>();
              final success =
                  await settings.importFromFile(controller.text.trim());
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text(success ? '設定をインポートしました' : 'インポート失敗: ファイルが見つかりません'),
                    backgroundColor: success ? null : AppTheme.errorColor,
                  ),
                );
              }
            },
            child: const Text('インポート'),
          ),
        ],
      ),
    );
  }

  Future<void> _backupLibrary(BuildContext context) async {
    try {
      final db = DatabaseService();
      final data = await db.exportData();
      final dir = await getApplicationDocumentsDirectory();
      final file = File(
          '${dir.path}/narou_reader/backup_${DateTime.now().millisecondsSinceEpoch}.json');
      await file.parent.create(recursive: true);
      await file
          .writeAsString(const JsonEncoder.withIndent('  ').convert(data));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('バックアップ完了\n${file.path}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('バックアップ失敗: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }
}
