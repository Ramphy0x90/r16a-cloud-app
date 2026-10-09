import 'package:flutter/material.dart';

import '../../../../core/media/widgets/file_type_icon.dart';
import '../../../../core/model/file_item.dart';

/// Actions offered on a long-pressed file.
enum FileAction { open, download, select, rename, move, share, delete }

/// Per-file actions — the native stand-in for the web's hover rename /
/// delete buttons and the single-selection toolbar. Write actions are
/// hidden when [readOnly] (Shared tab). Resolves to `null` when dismissed.
Future<FileAction?> showFileContextSheet({
  required BuildContext context,
  required FileItem file,
  required bool readOnly,
}) async {
  final actions = [
    if (!file.isDirectory) FileAction.open,
    FileAction.download,
    FileAction.select,
    if (!readOnly) ...[
      FileAction.rename,
      FileAction.move,
      FileAction.share,
      FileAction.delete,
    ],
  ];

  return showModalBottomSheet<FileAction>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;

      Widget tile(FileAction action) {
        final (icon, label) = switch (action) {
          FileAction.open => (Icons.open_in_new_rounded, 'Open'),
          FileAction.download => (Icons.download_rounded, 'Download'),
          FileAction.select => (Icons.check_circle_outline_rounded, 'Select'),
          FileAction.rename => (Icons.edit_outlined, 'Rename'),
          FileAction.move => (Icons.drive_file_move_outline, 'Move'),
          FileAction.share => (Icons.share_outlined, 'Share'),
          FileAction.delete => (Icons.delete_outline_rounded, 'Delete'),
        };
        final color = action == FileAction.delete ? scheme.error : null;
        return ListTile(
          leading: Icon(icon, color: color),
          title: Text(label, style: TextStyle(color: color)),
          onTap: () => Navigator.of(context).pop(action),
        );
      }

      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: FileTypeIcon(file: file, size: 24),
                title: Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const Divider(),
              for (final action in actions) tile(action),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}
