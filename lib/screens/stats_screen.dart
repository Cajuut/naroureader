import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/reading_stats_provider.dart';
import '../theme/app_theme.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ReadingStatsProvider>(
      builder: (context, stats, _) {
        return CustomScrollView(
          slivers: [
            const SliverAppBar(
              floating: true,
              title: Text('📊 読書統計'),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Hero stats
                  _buildHeroStats(stats),
                  const SizedBox(height: 20),

                  // Daily chart
                  _buildSectionTitle('過去30日の読書量'),
                  const SizedBox(height: 12),
                  _buildDailyChart(stats),
                  const SizedBox(height: 24),

                  // Top authors
                  _buildSectionTitle('よく読む作者'),
                  const SizedBox(height: 12),
                  _buildTopAuthors(stats),
                  const SizedBox(height: 100),
                ]),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeroStats(ReadingStatsProvider stats) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accentPrimary.withValues(alpha: 0.15),
            AppTheme.accentSecondary.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.accentPrimary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          const Text(
            '生涯読了文字数',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          ShaderMask(
            shaderCallback: (bounds) =>
                AppTheme.accentGradient.createShader(bounds),
            child: Text(
              stats.formattedTotalCharacters,
              style: const TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -1,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildMiniStat(Icons.timer_outlined, '読書時間',
                  stats.formattedTotalTime),
              const SizedBox(width: 32),
              _buildMiniStat(
                Icons.menu_book_outlined,
                '平均速度',
                stats.totalReadingTimeSeconds > 0
                    ? '${(stats.totalCharacters / (stats.totalReadingTimeSeconds / 60)).toInt()}字/分'
                    : '- 字/分',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, size: 18, color: AppTheme.textMuted),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppTheme.textPrimary,
      ),
    );
  }

  Widget _buildDailyChart(ReadingStatsProvider stats) {
    if (stats.dailyStats.isEmpty) {
      return Container(
        height: 200,
        decoration: AppTheme.glassDecoration,
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.show_chart, size: 48, color: AppTheme.textMuted),
            SizedBox(height: 8),
            Text(
              'まだ読書データがありません',
              style: TextStyle(color: AppTheme.textMuted),
            ),
          ],
        ),
      );
    }

    final maxChars = stats.dailyStats
        .map((d) => (d['characters'] as int?) ?? 0)
        .reduce((a, b) => a > b ? a : b);

    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassDecoration,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxChars.toDouble() * 1.2,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final chars = rod.toY.toInt();
                return BarTooltipItem(
                  chars >= 10000
                      ? '${(chars / 10000).toStringAsFixed(1)}万字'
                      : '$chars字',
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx >= 0 && idx < stats.dailyStats.length) {
                    final date = stats.dailyStats[idx]['date'] as String;
                    final day = date.substring(8, 10);
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        day,
                        style: const TextStyle(
                          fontSize: 9,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: stats.dailyStats.asMap().entries.map((entry) {
            final chars = (entry.value['characters'] as int?) ?? 0;
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: chars.toDouble(),
                  gradient: AppTheme.accentGradient,
                  width: 8,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTopAuthors(ReadingStatsProvider stats) {
    if (stats.topAuthors.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: AppTheme.glassDecoration,
        alignment: Alignment.center,
        child: const Text(
          'まだ読書データがありません',
          style: TextStyle(color: AppTheme.textMuted),
        ),
      );
    }

    final maxChars = stats.topAuthors.isNotEmpty
        ? (stats.topAuthors.first['total_characters'] as int?) ?? 1
        : 1;

    return Column(
      children: stats.topAuthors.asMap().entries.map((entry) {
        final author = entry.value;
        final totalChars = (author['total_characters'] as int?) ?? 0;
        final ratio = totalChars / maxChars;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: AppTheme.glassDecoration,
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: entry.key < 3
                      ? [
                          AppTheme.warningColor,
                          AppTheme.textSecondary,
                          AppTheme.accentTertiary,
                        ][entry.key]
                          .withValues(alpha: 0.2)
                      : AppTheme.bgSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${entry.key + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: entry.key < 3
                        ? [
                            AppTheme.warningColor,
                            AppTheme.textSecondary,
                            AppTheme.accentTertiary,
                          ][entry.key]
                        : AppTheme.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      author['author'] as String? ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 4,
                        backgroundColor: AppTheme.borderColor,
                        valueColor: AlwaysStoppedAnimation(
                          Color.lerp(AppTheme.accentSecondary,
                              AppTheme.accentPrimary, ratio)!,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                totalChars >= 10000
                    ? '${(totalChars / 10000).toStringAsFixed(1)}万字'
                    : '$totalChars字',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
