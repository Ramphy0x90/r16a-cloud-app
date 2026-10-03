import 'package:flutter/material.dart';

import '../../domain/file_item.dart';
import 'file_grid_tile.dart';

/// Grid view sliver — mirrors `grid-view` (`pages/files/grid-view`).
class FileGrid extends StatelessWidget {
  const FileGrid({
    super.key,
    required this.files,
    required this.showSharedFrom,
    required this.selectionMode,
    required this.selectedIds,
    required this.onTap,
    required this.onLongPress,
  });

  final List<FileItem> files;

  /// Shared-with-me tab: hides the shared badge, like the web's
  /// `showSharedFrom` input.
  final bool showSharedFrom;
  final bool selectionMode;
  final Set<String> selectedIds;
  final ValueChanged<FileItem> onTap;
  final ValueChanged<FileItem> onLongPress;

  @override
  Widget build(BuildContext context) {
    return SliverGrid.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 140,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        return FileGridTile(
          key: ValueKey(file.id),
          file: file,
          showSharedBadge: !showSharedFrom,
          selectionMode: selectionMode,
          selected: selectedIds.contains(file.id),
          onTap: () => onTap(file),
          onLongPress: () => onLongPress(file),
        );
      },
    );
  }
}
