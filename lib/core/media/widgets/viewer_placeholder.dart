import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';

import '../../../app/theme/app_colors.dart';
import '../../model/file_item.dart';

/// What `FileViewerScreen` shows while a page loads — the web modal's
/// `loading` state: the cached thumbnail if any, else the blurhash, with a
/// spinner on top.
class ViewerPlaceholder extends StatelessWidget {
  const ViewerPlaceholder({
    super.key,
    required this.file,
    required this.thumbnail,
    required this.heroTag,
  });

  final FileItem file;
  final ImageProvider thumbnail;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final hash = file.blurHash;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (hash != null) BlurHash(hash: hash, imageFit: BoxFit.contain),
        _hero(
          Image(
            image: thumbnail,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) =>
                const SizedBox.shrink(),
          ),
        ),
        const Center(
          child: CircularProgressIndicator(color: AppColors.darkForeground),
        ),
      ],
    );
  }

  Widget _hero(Widget child) {
    final tag = heroTag;
    return tag == null ? child : Hero(tag: tag, child: child);
  }
}
