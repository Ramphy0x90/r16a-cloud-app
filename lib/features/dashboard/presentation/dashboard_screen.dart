import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/media/media_actions.dart';
import '../../../core/navigation/home_tab.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/status_message.dart';
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
          error: (error, stackTrace) => StatusMessage(
            icon: Icons.error_outline_rounded,
            iconSize: 40,
            isError: true,
            message: 'Could not load dashboard data right now.',
            onRetry: () => ref.invalidate(dashboardProvider),
          ),
          data: (data) => _DashboardContent(data: data),
        ),
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

  /// Fetches the full file, then opens it like Files does: images in the
  /// viewer, anything else through "open with".
  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    RecentFileItem recent,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final file = await ref.read(dashboardApiProvider).getFile(recent.id);
      if (!context.mounted) return;
      await openMediaFile(context, ref, file, gallery: [file]);
    } catch (e, stack) {
      final gone = e is ApiException && e.statusCode == 404;
      if (gone) {
        ref.invalidate(dashboardProvider);
      } else {
        AppLogger.error(e, stack, 'Opening recent file failed');
      }
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              gone ? 'This file no longer exists.' : 'Could not open the file.',
            ),
          ),
        );
    }
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
        Row(
          children: [
            Expanded(
              child: Text(
                'Recent files',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            // Mirrors `.view-all-link` (`routerLink="/files"`).
            TextButton.icon(
              onPressed: () =>
                  ref.read(homeTabProvider.notifier).select(HomeTab.files),
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              iconAlignment: IconAlignment.end,
              label: const Text('View all', textAlign: TextAlign.end),
              style: TextButton.styleFrom(
                foregroundColor: scheme.onSurfaceVariant,
                textStyle: const TextStyle(fontSize: 13),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
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
                          RecentFileTile(
                            file: file,
                            onTap: () => _open(context, ref, file),
                          ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
