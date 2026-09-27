import 'package:flutter/material.dart';

import '../domain/dashboard_metrics.dart';
import 'dashboard_metric_specs.dart';
import 'widgets/metric_card.dart';
import 'widgets/recent_file_tile.dart';

/// Overview screen, ported from the web client's `pages/dashboard`: storage
/// metrics and a recent-files list.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  static final _placeholderData = DashboardResponse(
    metrics: const DashboardMetrics(
      uploadedFiles: 128,
      usedStorageBytes: 4300000000,
      sharedFiles: 6,
      uploadedPhotos: 342,
    ),
    recentFiles: [
      RecentFileItem(
        id: '1',
        name: 'Q3-roadmap.pdf',
        visibility: 'PRIVATE',
        sizeBytes: 842000,
        updatedAt: DateTime(2026, 9, 24, 14, 32),
      ),
      RecentFileItem(
        id: '2',
        name: 'team-offsite.jpg',
        visibility: 'SHARED',
        sizeBytes: 3200000,
        updatedAt: DateTime(2026, 9, 23, 9, 5),
      ),
      RecentFileItem(
        id: '3',
        name: 'expenses.xlsx',
        visibility: 'PRIVATE',
        sizeBytes: 51200,
        updatedAt: DateTime(2026, 9, 21, 18, 47),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final data = _placeholderData;

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.35,
            children: [
              for (final spec in dashboardMetricSpecs)
                MetricCard(spec: spec, metrics: data.metrics),
            ],
          ),
          const SizedBox(height: 24),
          Text('Recent files', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                for (final file in data.recentFiles) RecentFileTile(file: file),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
