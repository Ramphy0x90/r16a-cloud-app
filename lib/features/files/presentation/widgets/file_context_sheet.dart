import 'package:flutter/material.dart';

import '../../domain/file_item.dart';
import 'file_type_icon.dart';

/// Actions offered on a long-pressed file.
enum FileAction { open, select, rename, share, delete }

/// Per-file actions — the native stand-in for the web's hover rename /
/// delete buttons and the single-selection toolbar. Write actions are
/// hidden when [readOnly] (Shared tab). Resolves to `null` when dismissed,
/// and returns immediately when nothing applies.
Future<FileAction?> showFileContextSheet({
  required BuildContext context,
  required FileItem file,
  required bool readOnly,
}) async {
  final actions = [
    if (file.isImage) FileAction.open,
    if (!readOnly) ...[
      FileAction.select,
      FileAction.rename,
      FileAction.share,
      FileAction.delete,
    ],
  ];
  if (actions.isEmpty) return null;

  return showModalBottomSheet<FileAction>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;

      Widget tile(FileAction action) {
        final (icon, label) = switch (action) {
          FileAction.open => (Icons.open_in_full_rounded, 'Open'),
          FileAction.select => (Icons.check_circle_outline_rounded, 'Select'),
          FileAction.rename => (Icons.edit_outlined, 'Rename'),
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
