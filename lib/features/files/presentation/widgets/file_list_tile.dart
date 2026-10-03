import 'package:flutter/material.dart';

import '../../../../core/util/date_format.dart';
import '../../domain/file_item.dart';
import 'file_thumbnail.dart';

/// One row of the list view — mirrors `.list-row` in `list-view.html`:
/// icon, name, then "From" (shared tab) or "Modified", and the shared badge.
class FileListTile extends StatelessWidget {
  const FileListTile({
    super.key,
    required this.file,
    required this.showSharedFrom,
    required this.onTap,
  });

  final FileItem file;
  final bool showSharedFrom;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: FileThumbnail(
                file: file,
                iconSize: 20,
                includeVideo: false,
              ),
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
                  Text(
                    showSharedFrom
                        ? file.ownerDisplayName
                        : formatDateTime(file.updatedAt),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (!showSharedFrom && file.isShared) ...[
              const SizedBox(width: 8),
              Icon(Icons.people_rounded, size: 16, color: scheme.primary),
            ],
          ],
        ),
      ),
    );
  }
}
