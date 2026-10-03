import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../model/file_item.dart';
import '../../util/file_icons.dart';

/// Folder icon in the web's `--colour-folder`, otherwise the
/// `IconFromExtensionPipe` port.
class FileTypeIcon extends StatelessWidget {
  const FileTypeIcon({super.key, required this.file, required this.size});

  final FileItem file;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (file.isDirectory) {
      return Icon(Icons.folder_rounded, size: size, color: AppColors.folder);
    }
    return Icon(
      iconForFileName(file.name),
      size: size,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }
}
