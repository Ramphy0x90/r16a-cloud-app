import 'package:flutter/material.dart';

import '../../../../core/util/date_format.dart';
import '../../../../core/util/file_icons.dart';
import '../../../../core/util/file_size.dart';
import '../../domain/dashboard_metrics.dart';

/// A single row in the "Recent files" list. Mirrors `.recent-row` on the
/// web dashboard: icon, name + visibility chip, size + date.
class RecentFileTile extends StatelessWidget {
  const RecentFileTile({super.key, required this.file});

  final RecentFileItem file;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(iconForFileName(file.name), size: 18, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 3),
                _VisibilityChip(visibility: file.visibility),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatFileSize(file.sizeBytes),
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 3),
              Text(
                formatShortDateTime(file.updatedAt),
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VisibilityChip extends StatelessWidget {
  const _VisibilityChip({required this.visibility});

  final String visibility;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        visibility.toLowerCase(),
        style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
      ),
    );
  }
}
