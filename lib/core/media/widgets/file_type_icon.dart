import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
      return SvgPicture.asset(
        'assets/icons/folder.svg',
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(AppColors.folder, BlendMode.srcIn),
      );
    }

    return SvgPicture.asset(
      iconForFileName(file.name),
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(
        Theme.of(context).colorScheme.onSurfaceVariant,
        BlendMode.srcIn,
      ),
    );
  }
}
