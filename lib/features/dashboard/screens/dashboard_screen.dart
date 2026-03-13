import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/app_usage_info.dart';
import '../providers/dashboard_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usageState = ref.watch(appUsageProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D1312),
              Color(0xFF111B19),
              Color(0xFF0A100F),
            ],
            stops: [0, 0.45, 1],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DashboardHeader(
                  onRefresh: ref.read(appUsageProvider.notifier).loadUsage,
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: usageState.when(
                    loading: _DashboardLoadingState.new,
                    error: (error, _) => _DashboardErrorState(
                      onRetry: ref.read(appUsageProvider.notifier).loadUsage,
                    ),
                    data: (apps) {
                      if (apps.isEmpty) {
                        return _DashboardEmptyState(
                          onRetry: ref.read(appUsageProvider.notifier).loadUsage,
                        );
                      }

                      final topApps = _topFiveApps(apps);
                      return _DashboardBody(apps: topApps);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Your Detox Dashboard',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFE2F2EB),
                  letterSpacing: 0.2,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'A calm snapshot of your top screen-time habits',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFFA0B5AE),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded),
          color: const Color(0xFF89C8AA),
          tooltip: 'Refresh usage',
        ),
      ],
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.apps});

  final List<AppUsageInfo> apps;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: _UsageChartCard(apps: apps)),
        const SizedBox(height: 14),
        Expanded(child: _UsageListCard(apps: apps)),
      ],
    );
  }
}

class _UsageChartCard extends StatelessWidget {
  const _UsageChartCard({required this.apps});

  final List<AppUsageInfo> apps;

  @override
  Widget build(BuildContext context) {
    final maxY = _maxChartY(apps);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF141E1C),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x3328A67B)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top 5 Most Used Apps',
              style: TextStyle(
                color: Color(0xFFDFF4EA),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Minutes spent today',
              style: TextStyle(
                color: Color(0xFF9DB1AB),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: BarChart(
                BarChartData(
                  minY: 0,
                  maxY: maxY,
                  alignment: BarChartAlignment.spaceAround,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 20,
                    getDrawingHorizontalLine: (_) => const FlLine(
                      color: Color(0x1F87AA9A),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: 20,
                        getTitlesWidget: (value, meta) {
                          return SideTitleWidget(
                            meta: meta,
                            space: 8,
                            child: Text(
                              '${value.toInt()}m',
                              style: const TextStyle(
                                color: Color(0xFF7E9B91),
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= apps.length) {
                            return const SizedBox.shrink();
                          }

                          return SideTitleWidget(
                            meta: meta,
                            space: 8,
                            child: Text(
                              _compactName(apps[index].appName),
                              style: const TextStyle(
                                color: Color(0xFFB5CBC3),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: apps
                      .asMap()
                      .entries
                      .map(
                        (entry) => BarChartGroupData(
                          x: entry.key,
                          barRods: [
                            BarChartRodData(
                              toY: entry.value.durationMinutes.toDouble(),
                              width: 18,
                              borderRadius: BorderRadius.circular(8),
                              gradient: const LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Color(0xFF3D8768),
                                  Color(0xFF89D4AF),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UsageListCard extends StatelessWidget {
  const _UsageListCard({required this.apps});

  final List<AppUsageInfo> apps;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF141E1C),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x3328A67B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(
              'App Usage Breakdown',
              style: TextStyle(
                color: Color(0xFFDFF4EA),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              itemCount: apps.length,
              itemBuilder: (context, index) {
                final app = apps[index];
                return Container(
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2623),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0x1F89D4AF)),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF26453A),
                      child: Icon(
                        _iconForApp(app.appName),
                        color: const Color(0xFF8ED4B0),
                      ),
                    ),
                    title: Text(
                      app.appName,
                      style: const TextStyle(
                        color: Color(0xFFE3F2EC),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: Text(
                      _formatMinutes(app.durationMinutes),
                      style: const TextStyle(
                        color: Color(0xFF9DDCB9),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardLoadingState extends StatelessWidget {
  const _DashboardLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Color(0xFF88CDAA),
            ),
          ),
          SizedBox(height: 14),
          Text(
            'Loading your usage insights...',
            style: TextStyle(
              color: Color(0xFFAFC3BC),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardEmptyState extends StatelessWidget {
  const _DashboardEmptyState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.spa_outlined,
            color: Color(0xFF86C9A7),
            size: 44,
          ),
          const SizedBox(height: 12),
          const Text(
            'No usage data yet',
            style: TextStyle(
              color: Color(0xFFD9ECE4),
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Once apps are tracked, your chart will appear here.',
            style: TextStyle(
              color: Color(0xFF9BB0A8),
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Refresh'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF305847),
              foregroundColor: const Color(0xFFE2F5EB),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardErrorState extends StatelessWidget {
  const _DashboardErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.wifi_tethering_error_rounded,
            color: Color(0xFFCF9A97),
            size: 42,
          ),
          const SizedBox(height: 10),
          const Text(
            'Unable to load usage',
            style: TextStyle(
              color: Color(0xFFE5CCC9),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFBFE8D3),
              side: const BorderSide(color: Color(0x664EA47D)),
            ),
          ),
        ],
      ),
    );
  }
}

List<AppUsageInfo> _topFiveApps(List<AppUsageInfo> apps) {
  final sortedApps = List<AppUsageInfo>.from(apps)
    ..sort((a, b) => b.durationMinutes.compareTo(a.durationMinutes));

  return sortedApps.take(5).toList();
}

double _maxChartY(List<AppUsageInfo> apps) {
  final peakMinutes = apps.fold<int>(
    0,
    (currentMax, item) => math.max(currentMax, item.durationMinutes),
  );
  final rounded = (peakMinutes / 10).ceil() * 10;
  return math.max(rounded + 10, 40).toDouble();
}

String _compactName(String appName) {
  if (appName.length <= 7) {
    return appName;
  }

  return '${appName.substring(0, 7)}.';
}

String _formatMinutes(int minutes) {
  final hours = minutes ~/ 60;
  final remainderMinutes = minutes % 60;

  if (hours == 0) {
    return '${remainderMinutes}m';
  }

  if (remainderMinutes == 0) {
    return '${hours}h';
  }

  return '${hours}h ${remainderMinutes}m';
}

IconData _iconForApp(String appName) {
  switch (appName.toLowerCase()) {
    case 'youtube':
      return Icons.play_circle_fill_rounded;
    case 'instagram':
      return Icons.camera_alt_rounded;
    case 'whatsapp':
      return Icons.forum_rounded;
    case 'chrome':
      return Icons.public_rounded;
    case 'spotify':
      return Icons.multitrack_audio_rounded;
    case 'x':
      return Icons.alternate_email_rounded;
    case 'reddit':
      return Icons.reddit_rounded;
    default:
      return Icons.apps_rounded;
  }
}
