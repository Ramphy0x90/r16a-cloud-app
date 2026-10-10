import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
        final (iconPath, label) = switch (action) {
          FileAction.open => ('assets/icons/eye.svg', 'Open'),
          FileAction.download => (
            'assets/icons/cloud-download.svg',
            'Download',
          ),
          FileAction.select => ('assets/icons/circle-check.svg', 'Select'),
          FileAction.rename => ('assets/icons/edit.svg', 'Rename'),
          FileAction.move => ('assets/icons/folder-symlink.svg', 'Move'),
          FileAction.share => ('assets/icons/share-2.svg', 'Share'),
          FileAction.delete => ('assets/icons/trash.svg', 'Delete'),
        };

        final color = action == FileAction.delete
            ? scheme.error
            : scheme.onSurfaceVariant;

        return ListTile(
          leading: SvgPicture.asset(
            iconPath,
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          ),
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
