import 'package:flutter/material.dart';

import '../../domain/dashboard_metrics.dart';

/// One entry in the metrics grid — icon, accent colour, title and a
/// value derived from [DashboardMetrics]. Mirrors `MetricData` /
/// `dashboard.ts`'s `metrics` array on the web client.
class MetricCardSpec {
  const MetricCardSpec({
    required this.icon,
    required this.accent,
    required this.title,
    required this.valueBuilder,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String Function(DashboardMetrics metrics) valueBuilder;
}

class MetricCard extends StatelessWidget {
  const MetricCard({super.key, required this.spec, required this.metrics});

  final MetricCardSpec spec;
  final DashboardMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: spec.accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(spec.icon, color: spec.accent, size: 18),
          ),
          const SizedBox(height: 12),
          Text(
            spec.valueBuilder(metrics),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            spec.title,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
