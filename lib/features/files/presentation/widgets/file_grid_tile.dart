import 'package:flutter/material.dart';

import '../../domain/file_item.dart';
import 'file_type_icon.dart';

/// One card of the grid view — mirrors `.file-card` in `grid-view.html`:
/// media area (icon for now; thumbnails land with the preview step) and a
/// name footer with the shared badge.
class FileGridTile extends StatelessWidget {
  const FileGridTile({
    super.key,
    required this.file,
    required this.showSharedBadge,
    required this.onTap,
  });

  final FileItem file;
  final bool showSharedBadge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Expanded(
              child: Center(child: FileTypeIcon(file: file, size: 44)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      file.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (showSharedBadge && file.isShared) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.people_rounded, size: 14, color: scheme.primary),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
