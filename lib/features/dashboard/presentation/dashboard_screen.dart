import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/dashboard_metrics.dart';
import 'dashboard_metric_specs.dart';
import 'dashboard_providers.dart';
import 'widgets/metric_card.dart';
import 'widgets/recent_file_tile.dart';

/// Overview screen, ported from the web client's `pages/dashboard`: storage
/// metrics and a recent-files list.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      // The 120 bottom inset clears the floating dock for the whole
      // column — including the recent-files box below — not just its
      // scrolled content, so the box's rounded background stops above the
      // dock instead of extending behind it.
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        child: dashboardAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) =>
              _ErrorState(onRetry: () => ref.invalidate(dashboardProvider)),
          data: (data) => _DashboardContent(data: data),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, color: scheme.error, size: 40),
          const SizedBox(height: 12),
          Text(
            'Could not load dashboard data right now.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _DashboardContent extends ConsumerWidget {
  const _DashboardContent({required this.data});

  final DashboardResponse data;

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(dashboardProvider);
    await ref.read(dashboardProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var row = 0; row < dashboardMetricSpecs.length; row += 2) ...[
          if (row > 0) const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: MetricCard(
                  spec: dashboardMetricSpecs[row],
                  metrics: data.metrics,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MetricCard(
                  spec: dashboardMetricSpecs[row + 1],
                  metrics: data.metrics,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        Text('Recent files', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
            child: RefreshIndicator(
              onRefresh: () => _refresh(ref),
              child: data.recentFiles.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: 240,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.history_rounded,
                                  color: scheme.onSurfaceVariant,
                                  size: 32,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No files uploaded yet.',
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(0, 8, 0, 20),
                      children: [
                        for (final file in data.recentFiles)
                          RecentFileTile(file: file),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
