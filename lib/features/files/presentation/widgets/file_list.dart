import 'package:flutter/material.dart';

import '../../../../core/model/file_item.dart';
import 'file_list_tile.dart';

/// List view sliver — mirrors `list-view` (`pages/files/list-view`),
/// virtualized like its `cdk-virtual-scroll-viewport`.
class FileList extends StatelessWidget {
  const FileList({
    super.key,
    required this.files,
    required this.showSharedFrom,
    required this.selectionMode,
    required this.selectedIds,
    required this.onTap,
    required this.onLongPress,
  });

  final List<FileItem> files;
  final bool showSharedFrom;
  final bool selectionMode;
  final Set<String> selectedIds;
  final ValueChanged<FileItem> onTap;
  final ValueChanged<FileItem> onLongPress;

  @override
  Widget build(BuildContext context) {
    return SliverList.builder(
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        return FileListTile(
          key: ValueKey(file.id),
          file: file,
          showSharedFrom: showSharedFrom,
          selectionMode: selectionMode,
          selected: selectedIds.contains(file.id),
          onTap: () => onTap(file),
          onLongPress: () => onLongPress(file),
        );
      },
    );
  }
}
